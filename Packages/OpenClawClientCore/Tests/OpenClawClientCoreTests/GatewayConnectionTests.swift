import Foundation
import Testing
import OpenClawProtocol
import OpenClawSDK
@testable import OpenClawClientCore

final class MockWebSocket: OpenClawClientCore.WebSocketTasking, @unchecked Sendable {
    var sent: [URLSessionWebSocketTask.Message] = []
    var inbound: [URLSessionWebSocketTask.Message] = []
    var onSend: ((URLSessionWebSocketTask.Message) -> URLSessionWebSocketTask.Message?)?
    var state: URLSessionTask.State = .running

    func resume() {}
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {}

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        sent.append(message)
        if let response = onSend?(message) {
            inbound.append(response)
        }
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        if inbound.isEmpty { throw NSError(domain: "Mock", code: 1) }
        return inbound.removeFirst()
    }

    func receive(completionHandler: @escaping @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        if inbound.isEmpty {
            completionHandler(.failure(NSError(domain: "Mock", code: 1)))
        } else {
            completionHandler(.success(inbound.removeFirst()))
        }
    }
}

final class RecordingTokenStore: TokenStoring, @unchecked Sendable {
    var stored: DeviceAuthEntry?
    func loadToken(deviceId: String, role: String) -> DeviceAuthEntry? { nil }
    func storeToken(deviceId: String, role: String, token: String, scopes: [String]) -> DeviceAuthEntry {
        let entry = DeviceAuthEntry(token: token, role: role, scopes: scopes, updatedAtMs: 1)
        stored = entry
        return entry
    }
    func clearToken(deviceId: String, role: String) {}
}

struct GatewayConnectionTests {
    @Test func requestReturnsResponsePayload() async throws {
        let socket = MockWebSocket()
        let tokenStore = RecordingTokenStore()
        let identityStore = DeviceIdentityStore(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let conn = GatewayConnection(url: URL(string: "ws://127.0.0.1:18789")!, tokenStore: tokenStore, identityStore: identityStore, socket: socket)

        socket.onSend = { message in
            guard case let .data(data) = message else { return nil }
            guard let req = try? JSONDecoder().decode(RequestFrame.self, from: data) else { return nil }
            let payload = ResponseFrame(
                type: "res",
                id: req.id,
                ok: true,
                payload: AnyCodable(["ok": AnyCodable(true)]),
                error: nil
            )
            let frame = GatewayFrame.res(payload)
            guard let resData = try? JSONEncoder().encode(frame) else { return nil }
            return .data(resData)
        }

        let result = try await conn.request(method: "health", payload: Data())
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: result)
        #expect(decoded.value as? [String: AnyCodable] != nil)
    }
}
