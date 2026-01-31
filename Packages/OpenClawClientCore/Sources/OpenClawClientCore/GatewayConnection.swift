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

public actor GatewayConnection: GatewayRequesting {
    private let url: URL
    private let tokenStore: TokenStoring
    private let identityStore: DeviceIdentityStore
    private let socket: WebSocketTasking
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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

    public func connect(sharedToken: String?) async throws {
        socket.resume()
        let identity = identityStore.loadOrCreate()
        let challengeNonce = await receiveChallenge()
        let stored = tokenStore.loadToken(deviceId: identity.deviceId, role: "operator")?.token
        let token = stored ?? sharedToken

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
        let paramsJson = try JSONSerialization.jsonObject(with: paramsData) as? [String: Any] ?? [:]
        let frame = RequestFrame(type: "req", id: "connect", method: "connect", params: AnyCodable(paramsJson))
        try await socket.send(.data(try encoder.encode(frame)))

        let resFrame = try await receiveResponse(id: "connect")
        guard resFrame.ok, let payload = resFrame.payload else {
            throw NSError(domain: "Gateway", code: 1, userInfo: [NSLocalizedDescriptionKey: "connect failed"])
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
        let frame = RequestFrame(type: "req", id: id, method: method, params: AnyCodable(paramsJson))
        try await socket.send(.data(try encoder.encode(frame)))
        let res = try await receiveResponse(id: id)
        guard res.ok, let payload = res.payload else {
            throw NSError(domain: "Gateway", code: 1, userInfo: [NSLocalizedDescriptionKey: "request failed"])
        }
        return try encoder.encode(payload)
    }

    private func receiveResponse(id: String) async throws -> ResponseFrame {
        while true {
            let msg = try await socket.receive()
            guard let data = decodeMessageData(msg) else { continue }
            let frame = try decoder.decode(GatewayFrame.self, from: data)
            if case let .res(res) = frame, res.id == id {
                return res
            }
        }
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
