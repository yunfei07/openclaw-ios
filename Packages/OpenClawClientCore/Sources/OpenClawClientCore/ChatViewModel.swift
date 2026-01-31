import Foundation
import Observation

public struct ChatSendResult: Sendable {
    public let runId: String
    public let status: String

    public init(runId: String, status: String) {
        self.runId = runId
        self.status = status
    }
}

public protocol ChatServiceType: Sendable {
    func history(sessionKey: String) async throws -> [ChatMessage]
    func send(sessionKey: String, message: String, thinking: String?, idempotencyKey: String) async throws -> ChatSendResult
    func abort(sessionKey: String, runId: String?) async throws
}

@MainActor
@Observable
public final class ChatViewModel {
    public var messages: [ChatMessage] = []
    public var inputText: String = ""
    public var connectionState: String = "disconnected"
    public var errorMessage: String? = nil

    private let chat: ChatServiceType
    private let sessionKey = "main"

    public init(chat: ChatServiceType) {
        self.chat = chat
    }

    public func loadHistory() async throws {
        messages = try await chat.history(sessionKey: sessionKey)
    }

    public func sendMessage() async throws {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        let pending = ChatMessage(role: .user, text: text, state: .sending)
        messages.append(pending)
        _ = try await chat.send(sessionKey: sessionKey, message: text, thinking: "low", idempotencyKey: UUID().uuidString)
        if let idx = messages.indices.last {
            messages[idx] = ChatMessage(id: messages[idx].id, role: .user, text: text, state: .sent)
        }
    }
}
