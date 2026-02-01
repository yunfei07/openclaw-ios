import Foundation
import OpenClawProtocol
import OpenClawSDK

public protocol WebSocketTasking: AnyObject, Sendable {
    var state: URLSessionTask.State { get }
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func receive(completionHandler: @escaping @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void)
}

extension URLSessionWebSocketTask: WebSocketTasking {}
extension URLSessionWebSocketTask: @unchecked Sendable {}

private final class PendingResponse: @unchecked Sendable {
    private var continuation: CheckedContinuation<ResponseFrame, Error>?
    private var result: Result<ResponseFrame, Error>?

    func wait() async throws -> ResponseFrame {
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resolve(_ response: ResponseFrame) {
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: response)
        } else {
            result = .success(response)
        }
    }

    func reject(_ error: Error) {
        if let continuation {
            self.continuation = nil
            continuation.resume(throwing: error)
        } else {
            result = .failure(error)
        }
    }
}

public actor GatewayConnection: GatewayRequesting, GatewayEventStreaming {
    private let url: URL
    private let tokenStore: TokenStoring
    private let identityStore: DeviceIdentityStore
    private let socket: WebSocketTasking
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var receiveLoopTask: Task<Void, Never>?
    private var eventStream: AsyncStream<EventFrame>?
    private var eventContinuation: AsyncStream<EventFrame>.Continuation?
    private var pendingRequests: [String: PendingResponse] = [:]

    public init(
        url: URL,
        tokenStore: TokenStoring,
        identityStore: DeviceIdentityStore,
        socket: WebSocketTasking? = nil
    ) {
        self.url = url
        self.tokenStore = tokenStore
        self.identityStore = identityStore
        if let socket {
            self.socket = socket
        } else {
            let task = URLSession(configuration: .default).webSocketTask(with: url)
            task.maximumMessageSize = 16 * 1024 * 1024
            self.socket = task
        }
    }

    public func events() async -> AsyncStream<EventFrame> {
        if let eventStream { return eventStream }
        let stream = AsyncStream<EventFrame> { continuation in
            eventContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.clearEventStream() }
            }
        }
        eventStream = stream
        startReceiveLoopIfNeeded()
        return stream
    }

    public func connect(sharedToken: String?, useDeviceIdentity: Bool = true) async throws {
        socket.resume()
        let identity = identityStore.loadOrCreate()
        let challengeNonce = await receiveChallenge()
        let stored = tokenStore.loadToken(deviceId: identity.deviceId, role: "operator")?.token
        let token = useDeviceIdentity ? (stored ?? sharedToken) : sharedToken

        let params = ConnectPayloadBuilder.build(
            clientId: "openclaw-ios",
            clientMode: "ui",
            displayName: "iOS",
            role: "operator",
            scopes: ["operator.read", "operator.write"],
            token: token,
            challengeNonce: challengeNonce,
            identity: identity
        )

        let paramsData = try encoder.encode(params)
        var paramsJson = try JSONSerialization.jsonObject(with: paramsData) as? [String: Any] ?? [:]
        if !useDeviceIdentity {
            paramsJson.removeValue(forKey: "device")
        }

        let promise = PendingResponse()
        pendingRequests["connect"] = promise
        startReceiveLoopIfNeeded()
        let frame = RequestFrame(type: "req", id: "connect", method: "connect", params: AnyCodable(paramsJson))
        do {
            try await socket.send(.data(try encoder.encode(frame)))
        } catch {
            pendingRequests.removeValue(forKey: "connect")
            promise.reject(error)
            throw error
        }

        let resFrame = try await promise.wait()
        guard resFrame.ok, let payload = resFrame.payload else {
            let message = (resFrame.error?["message"]?.value as? String) ?? "connect failed"
            throw NSError(domain: "Gateway", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let okData = try encoder.encode(payload)
        let ok = try decoder.decode(HelloOk.self, from: okData)
        if let auth = ok.auth, let tokenValue = auth["deviceToken"]?.value as? String {
            let role = auth["role"]?.value as? String ?? "operator"
            let scopes = (auth["scopes"]?.value as? [AnyCodable])?.compactMap { $0.value as? String } ?? []
            _ = tokenStore.storeToken(deviceId: identity.deviceId, role: role, token: tokenValue, scopes: scopes)
        }
    }

    public func request(method: String, payload: Data) async throws -> Data {
        let id = UUID().uuidString
        let paramsJson = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any] ?? [:]
        let promise = PendingResponse()
        pendingRequests[id] = promise
        startReceiveLoopIfNeeded()
        let frame = RequestFrame(type: "req", id: id, method: method, params: AnyCodable(paramsJson))
        do {
            try await socket.send(.data(try encoder.encode(frame)))
        } catch {
            pendingRequests.removeValue(forKey: id)
            promise.reject(error)
            throw error
        }
        let res = try await promise.wait()
        guard res.ok, let payload = res.payload else {
            throw NSError(domain: "Gateway", code: 1, userInfo: [NSLocalizedDescriptionKey: "request failed"])
        }
        return try encoder.encode(payload)
    }

    private func startReceiveLoopIfNeeded() {
        guard receiveLoopTask == nil else { return }
        receiveLoopTask = Task {
            await runReceiveLoop()
        }
    }

    private func runReceiveLoop() async {
        while true {
            let msg: URLSessionWebSocketTask.Message
            do {
                msg = try await socket.receive()
            } catch {
                break
            }
            guard let data = decodeMessageData(msg) else { continue }
            guard let frame = try? decoder.decode(GatewayFrame.self, from: data) else { continue }
            switch frame {
            case let .res(res):
                if let pending = pendingRequests.removeValue(forKey: res.id) {
                    pending.resolve(res)
                }
            case let .event(evt):
                eventContinuation?.yield(evt)
            default:
                continue
            }
        }
        let error = NSError(domain: "Gateway", code: 1, userInfo: [NSLocalizedDescriptionKey: "connection closed"])
        for (_, pending) in pendingRequests {
            pending.reject(error)
        }
        pendingRequests.removeAll()
        eventContinuation?.finish()
        receiveLoopTask = nil
    }

    private func clearEventStream() {
        eventContinuation = nil
        eventStream = nil
    }

    private func receiveChallenge() async -> String? {
        do {
            let msg = try await socket.receive()
            guard let data = decodeMessageData(msg) else { return nil }
            guard let frame = try? decoder.decode(GatewayFrame.self, from: data) else { return nil }
            if case let .event(evt) = frame, evt.event == "connect.challenge" {
                if let payload = evt.payload?.value as? [String: AnyCodable],
                   let nonce = payload["nonce"]?.value as? String { return nonce }
            }
        } catch {}
        return nil
    }

    private nonisolated func decodeMessageData(_ msg: URLSessionWebSocketTask.Message) -> Data? {
        switch msg {
        case let .data(data): return data
        case let .string(text): return Data(text.utf8)
        @unknown default: return nil
        }
    }
}
