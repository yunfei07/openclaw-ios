import Foundation
import Testing
import OpenClawProtocol
import OpenClawSDK
@testable import OpenClawClientCore

final class MockGateway: GatewayRequesting, @unchecked Sendable {
    var lastMethod: String?
    var lastPayload: Data?

    func request(method: String, payload: Data) async throws -> Data {
        lastMethod = method
        lastPayload = payload
        return try JSONEncoder().encode(ChatHistoryResponse(sessionKey: "main", sessionId: nil, messages: [], thinkingLevel: nil))
    }
}

struct ChatServiceAdapterTests {
    @Test func historyCallsChatHistory() async throws {
        let gateway = MockGateway()
        let adapter = ChatServiceAdapter(gateway: gateway)
        _ = try await adapter.history(sessionKey: "main")
        #expect(gateway.lastMethod == "chat.history")
    }
}
