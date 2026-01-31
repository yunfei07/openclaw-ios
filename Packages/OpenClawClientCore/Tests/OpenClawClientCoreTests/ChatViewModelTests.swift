import Foundation
import Testing
@testable import OpenClawClientCore

@MainActor
final class MockChatService: ChatServiceType, @unchecked Sendable {
    var historyResult: [ChatMessage] = []
    var sendResult: ChatSendResult = ChatSendResult(runId: "r1", status: "started")

    func history(sessionKey: String) async throws -> [ChatMessage] { historyResult }
    func send(sessionKey: String, message: String, thinking: String?, idempotencyKey: String) async throws -> ChatSendResult {
        sendResult
    }
    func abort(sessionKey: String, runId: String?) async throws {}
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
}
