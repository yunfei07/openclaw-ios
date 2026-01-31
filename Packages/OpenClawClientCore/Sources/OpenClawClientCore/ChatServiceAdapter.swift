import Foundation
import OpenClawSDK
import OpenClawProtocol

public struct ChatServiceAdapter: ChatServiceType, Sendable {
    private let service: ChatService

    public init(gateway: GatewayRequesting) {
        self.service = ChatService(gateway: gateway)
    }

    public func history(sessionKey: String) async throws -> [ChatMessage] {
        let res = try await service.history(sessionKey: sessionKey)
        return ChatMessageMapper.fromHistory(res.messages)
    }

    public func send(sessionKey: String, message: String, thinking: String?, idempotencyKey: String) async throws -> ChatSendResult {
        let res = try await service.send(sessionKey: sessionKey, message: message, thinking: thinking, idempotencyKey: idempotencyKey)
        return ChatSendResult(runId: res.runId, status: res.status)
    }

    public func abort(sessionKey: String, runId: String?) async throws {
        _ = try await service.abort(sessionKey: sessionKey, runId: runId)
    }
}
