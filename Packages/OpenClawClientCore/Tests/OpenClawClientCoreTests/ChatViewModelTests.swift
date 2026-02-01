import Foundation
import Testing
@testable import OpenClawClientCore

final class MockChatService: ChatServiceType, @unchecked Sendable {
    var historyResult: [ChatMessage] = []
    var sendResult: ChatSendResult = ChatSendResult(runId: "r1", status: "started")
    var historyCalls = 0
    private var eventStream: AsyncStream<ChatEvent>?
    private var eventContinuation: AsyncStream<ChatEvent>.Continuation?

    func history(sessionKey: String) async throws -> [ChatMessage] {
        historyCalls += 1
        return historyResult
    }

    func send(sessionKey: String, message: String, thinking: String?, idempotencyKey: String) async throws -> ChatSendResult {
        sendResult
    }

    func abort(sessionKey: String, runId: String?) async throws {}

    func events() -> AsyncStream<ChatEvent> {
        if let eventStream { return eventStream }
        let stream = AsyncStream<ChatEvent> { continuation in
            eventContinuation = continuation
        }
        eventStream = stream
        return stream
    }

    func emit(_ event: ChatEvent) {
        eventContinuation?.yield(event)
    }
}

@MainActor
struct ChatViewModelTests {
    @Test func sendAppendsUserMessage() async throws {
        let chat = MockChatService()
        let vm = ChatViewModel(chat: chat)
        vm.inputText = "hi"
        try await vm.sendMessage()
        #expect(vm.messages.first?.text == "hi")
    }

    @Test func sendAddsAssistantPlaceholder() async throws {
        let chat = MockChatService()
        let vm = ChatViewModel(chat: chat)
        vm.inputText = "hi"
        try await vm.sendMessage()
        #expect(vm.messages.count == 2)
        #expect(vm.messages.last?.role == .assistant)
        #expect(vm.messages.last?.state == .sending)
    }

    @Test func streamingUpdatesAssistantMessage() async throws {
        let chat = MockChatService()
        let vm = ChatViewModel(chat: chat)
        vm.startStreaming()
        vm.inputText = "hi"
        try await vm.sendMessage()

        chat.emit(ChatEvent(
            runId: "r1",
            sessionKey: "main",
            seq: 1,
            state: .delta,
            message: ChatMessage(role: .assistant, text: "Hel", state: .sending),
            errorMessage: nil
        ))
        chat.emit(ChatEvent(
            runId: "r1",
            sessionKey: "main",
            seq: 2,
            state: .final,
            message: ChatMessage(role: .assistant, text: "Hello", state: .sent),
            errorMessage: nil
        ))
        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(vm.messages.last?.text == "Hello")
        #expect(vm.messages.last?.state == .sent)
    }
}
