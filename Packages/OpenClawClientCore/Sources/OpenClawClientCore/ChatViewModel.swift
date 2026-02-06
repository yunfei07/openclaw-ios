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
    public var messages: [ChatMessage] = [] {
        didSet {
            persistMessages()
        }
    }
    public var inputText: String = ""
    public var connectionState: String = "disconnected"
    public var errorMessage: String? = nil

    private let chat: ChatServiceType
    private let sessionKey: String
    private let historyStore: ChatHistoryStoring?
    private var streamTask: Task<Void, Never>?
    private var activeRuns: [String: Int] = [:]
    private var lastSeqByRun: [String: Int] = [:]

    public init(chat: ChatServiceType, sessionKey: String = "main", historyStore: ChatHistoryStoring? = nil) {
        self.chat = chat
        self.sessionKey = sessionKey
        self.historyStore = historyStore
    }

    public func loadCachedHistory() async {
        guard let historyStore else { return }
        let cached = await historyStore.load(sessionKey: sessionKey)
#if DEBUG
        print("[ChatHistory] cached loaded: \(cached.count)")
#endif
        if messages.isEmpty {
            messages = cached
            return
        }
        guard !cached.isEmpty else { return }
        messages = merge(remote: cached, local: messages)
    }

    public func loadHistory() async throws {
        let remote = try await chat.history(sessionKey: sessionKey)
#if DEBUG
        print("[ChatHistory] remote loaded: \(remote.count)")
#endif
        if remote.isEmpty {
            if messages.isEmpty, let historyStore {
                messages = await historyStore.load(sessionKey: sessionKey)
            }
            return
        }

        if messages.isEmpty {
            messages = remote
            if let historyStore {
                await historyStore.save(sessionKey: sessionKey, messages: remote)
            }
            return
        }

        let merged = merge(remote: remote, local: messages)
        messages = merged
        if let historyStore {
            await historyStore.save(sessionKey: sessionKey, messages: merged)
        }
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
        let pendingUser = ChatMessage(role: .user, text: text, state: .sending, createdAt: Date())
        messages.append(pendingUser)
        let userIndex = messages.indices.last
        do {
            let result = try await chat.send(sessionKey: sessionKey, message: text, thinking: "low", idempotencyKey: UUID().uuidString)
            if let idx = userIndex {
                let existing = messages[idx]
                messages[idx] = ChatMessage(
                    id: existing.id,
                    role: .user,
                    text: text,
                    state: .sent,
                    createdAt: existing.createdAt,
                    replyTo: existing.replyTo,
                    forwardedFrom: existing.forwardedFrom,
                    isEdited: existing.isEdited,
                    localDeleted: existing.localDeleted
                )
            }
            let assistant = ChatMessage(role: .assistant, text: "", state: .sending, createdAt: Date())
            messages.append(assistant)
            activeRuns[result.runId] = messages.count - 1
        } catch {
            if let idx = userIndex {
                let existing = messages[idx]
                messages[idx] = ChatMessage(
                    id: existing.id,
                    role: .user,
                    text: text,
                    state: .failed,
                    createdAt: existing.createdAt,
                    replyTo: existing.replyTo,
                    forwardedFrom: existing.forwardedFrom,
                    isEdited: existing.isEdited,
                    localDeleted: existing.localDeleted
                )
            }
            throw error
        }
    }

    public func updateMessageText(id: String, newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        let existing = messages[idx]
        guard existing.state != .sent else { return }
        messages[idx] = ChatMessage(
            id: existing.id,
            role: existing.role,
            text: trimmed,
            state: existing.state,
            createdAt: existing.createdAt,
            replyTo: existing.replyTo,
            forwardedFrom: existing.forwardedFrom,
            isEdited: true,
            localDeleted: existing.localDeleted
        )
    }

    public func markMessageDeleted(id: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        let existing = messages[idx]
        guard existing.state != .sent else { return }
        messages[idx] = ChatMessage(
            id: existing.id,
            role: existing.role,
            text: "",
            state: existing.state,
            createdAt: existing.createdAt,
            replyTo: existing.replyTo,
            forwardedFrom: existing.forwardedFrom,
            isEdited: existing.isEdited,
            localDeleted: true
        )
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
                messages[idx] = ChatMessage(
                    id: existing.id,
                    role: .assistant,
                    text: existing.text,
                    state: .sent,
                    createdAt: existing.createdAt,
                    replyTo: existing.replyTo,
                    forwardedFrom: existing.forwardedFrom,
                    isEdited: existing.isEdited,
                    localDeleted: existing.localDeleted
                )
            }
            activeRuns.removeValue(forKey: event.runId)
        case .error:
            if let idx = activeRuns[event.runId] {
                let existing = messages[idx]
                messages[idx] = ChatMessage(
                    id: existing.id,
                    role: .assistant,
                    text: existing.text,
                    state: .failed,
                    createdAt: existing.createdAt,
                    replyTo: existing.replyTo,
                    forwardedFrom: existing.forwardedFrom,
                    isEdited: existing.isEdited,
                    localDeleted: existing.localDeleted
                )
            }
            activeRuns.removeValue(forKey: event.runId)
            errorMessage = event.errorMessage
        case .unknown:
            break
        }
    }

    private func upsertAssistant(runId: String, text: String, state: ChatDeliveryState) {
        if let idx = activeRuns[runId] {
            let existing = messages[idx]
            messages[idx] = ChatMessage(
                id: existing.id,
                role: .assistant,
                text: text,
                state: state,
                createdAt: existing.createdAt,
                replyTo: existing.replyTo,
                forwardedFrom: existing.forwardedFrom,
                isEdited: existing.isEdited,
                localDeleted: existing.localDeleted
            )
        } else {
            let message = ChatMessage(role: .assistant, text: text, state: state, createdAt: Date())
            messages.append(message)
            activeRuns[runId] = messages.count - 1
        }
    }

    private func merge(remote: [ChatMessage], local: [ChatMessage]) -> [ChatMessage] {
        let maxRemoteDate = remote.map(\.createdAt).max() ?? .distantPast
        var combined = remote
        var indexByFingerprint: [String: Int] = [:]
        for (idx, message) in remote.enumerated() {
            indexByFingerprint[fingerprint(message)] = idx
        }

        for message in local {
            let keep = message.state != .sent || message.hasLocalMetadata || message.createdAt > maxRemoteDate
            guard keep else { continue }
            let key = fingerprint(message)
            if let idx = indexByFingerprint[key] {
                if message.hasLocalMetadata {
                    combined[idx] = message
                }
                if message.state != .sent {
                    combined.append(message)
                }
                continue
            }
            combined.append(message)
            if message.state == .sent || message.hasLocalMetadata {
                indexByFingerprint[key] = combined.count - 1
            }
        }

        return combined.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id < $1.id
        }
    }

    private func fingerprint(_ message: ChatMessage) -> String {
        let ts = Int(message.createdAt.timeIntervalSince1970 * 1000)
        return "\(message.role.rawValue)|\(ts)|\(message.text)"
    }

    private func persistMessages() {
        guard let historyStore else { return }
        let snapshot = messages
        let key = sessionKey
        Task {
            await historyStore.save(sessionKey: key, messages: snapshot)
        }
    }
}
