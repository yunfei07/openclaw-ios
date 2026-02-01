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
    func events() -> AsyncStream<ChatEvent>
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
    private var streamTask: Task<Void, Never>?
    private var activeRuns: [String: Int] = [:]
    private var lastSeqByRun: [String: Int] = [:]

    public init(chat: ChatServiceType) {
        self.chat = chat
    }

    public func loadHistory() async throws {
        messages = try await chat.history(sessionKey: sessionKey)
    }

    public func startStreaming() {
        guard streamTask == nil else { return }
        let stream = chat.events()
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await event in stream {
                await MainActor.run {
                    self.handle(event: event)
                }
            }
        }
    }

    public func sendMessage() async throws {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        let pendingUser = ChatMessage(role: .user, text: text, state: .sending)
        messages.append(pendingUser)
        let userIndex = messages.indices.last
        do {
            let result = try await chat.send(sessionKey: sessionKey, message: text, thinking: "low", idempotencyKey: UUID().uuidString)
            if let idx = userIndex {
                messages[idx] = ChatMessage(id: messages[idx].id, role: .user, text: text, state: .sent)
            }
            let assistant = ChatMessage(role: .assistant, text: "", state: .sending)
            messages.append(assistant)
            activeRuns[result.runId] = messages.count - 1
        } catch {
            if let idx = userIndex {
                messages[idx] = ChatMessage(id: messages[idx].id, role: .user, text: text, state: .failed)
            }
            throw error
        }
    }

    private func handle(event: ChatEvent) {
        guard event.sessionKey == sessionKey else { return }
        if let seq = event.seq {
            if let last = lastSeqByRun[event.runId], seq < last {
                return
            }
            lastSeqByRun[event.runId] = seq
        }

        switch event.state {
        case .delta:
            if let text = event.message?.text {
                upsertAssistant(runId: event.runId, text: text, state: .sending)
            }
        case .final:
            if let text = event.message?.text {
                upsertAssistant(runId: event.runId, text: text, state: .sent)
            } else if let idx = activeRuns[event.runId] {
                let existing = messages[idx]
                messages[idx] = ChatMessage(id: existing.id, role: .assistant, text: existing.text, state: .sent)
            }
            activeRuns.removeValue(forKey: event.runId)
        case .error:
            if let idx = activeRuns[event.runId] {
                let existing = messages[idx]
                messages[idx] = ChatMessage(id: existing.id, role: .assistant, text: existing.text, state: .failed)
            }
            activeRuns.removeValue(forKey: event.runId)
            errorMessage = event.errorMessage
        case .unknown:
            break
        }
    }

    private func upsertAssistant(runId: String, text: String, state: ChatDeliveryState) {
        if let idx = activeRuns[runId] {
            messages[idx] = ChatMessage(id: messages[idx].id, role: .assistant, text: text, state: state)
        } else {
            let message = ChatMessage(role: .assistant, text: text, state: state)
            messages.append(message)
            activeRuns[runId] = messages.count - 1
        }
    }
}
