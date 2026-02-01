import Foundation
import OpenClawSDK
import OpenClawProtocol

public protocol GatewayEventStreaming: Sendable {
    func events() async -> AsyncStream<EventFrame>
}

public struct ChatServiceAdapter: ChatServiceType, Sendable {
    private let service: ChatService
    private let gateway: GatewayEventStreaming

    public init(gateway: GatewayRequesting & GatewayEventStreaming) {
        self.gateway = gateway
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

    public func events() -> AsyncStream<ChatEvent> {
        return AsyncStream { continuation in
            Task {
                let base = await gateway.events()
                for await event in base {
                    if let mapped = ChatEventMapper.from(event: event) {
                        continuation.yield(mapped)
                    }
                }
                continuation.finish()
            }
        }
    }
}
