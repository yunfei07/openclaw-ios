//
//  ContentView.swift
//  openclaw-ios
//
//  Created by yangyunfei on 2026/1/30.
//

import ExyteChat
import Observation
import OpenClawClientCore
import SwiftUI

struct ContentView: View {
    @Bindable var chat: ChatViewModel
    @Bindable var settings: SettingsViewModel
    let connect: (() async -> Void)?
    @State private var showingSettings = false
    @State private var showUnsupportedAlert = false
    @State private var exyteMessages: [ExyteChat.Message] = []
    @State private var createdAtByMessageId: [String: Date] = [:]

    var body: some View {
        NavigationStack {
            ChatView(messages: exyteMessages, chatType: .conversation, didSendMessage: handleDraftMessage)
                .showDateHeaders(false)
                .keyboardDismissMode(.interactive)
                .navigationTitle("OpenClaw")
                .navigationBarTitleDisplayMode(.inline)
                .background(ChatTableViewTuner())
                .toolbar {
                    Button("设置") {
                        showingSettings = true
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(viewModel: settings)
                }
                .task {
                    if let connect {
                        await connect()
                    }
                    await updateMessages(from: chat.messages)
                }
                .onChange(of: chat.messages) { _, newValue in
                    updateMessages(from: newValue)
                }
                .alert("暂不支持", isPresented: $showUnsupportedAlert) {
                    Button("好", role: .cancel) {}
                } message: {
                    Text("附件 / 语音 / 贴纸功能后续开放")
                }
        }
    }

    private func handleDraftMessage(_ draft: DraftMessage) {
        if hasUnsupportedAttachments(draft) {
            showUnsupportedAlert = true
            return
        }
        let trimmed = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chat.inputText = trimmed
        Task {
            try? await chat.sendMessage()
        }
    }

    private func hasUnsupportedAttachments(_ draft: DraftMessage) -> Bool {
        !draft.medias.isEmpty || draft.giphyMedia != nil || draft.recording != nil
    }

    @MainActor
    private func updateMessages(from messages: [ChatMessage]) {
        var updatedCreatedAt = createdAtByMessageId
        let mapped = messages.map { message in
            let createdAt = updatedCreatedAt[message.id] ?? Date()
            updatedCreatedAt[message.id] = createdAt
            return mapMessage(message, createdAt: createdAt)
        }
        createdAtByMessageId = updatedCreatedAt
        exyteMessages = mapped
    }

    private func mapMessage(_ message: ChatMessage, createdAt: Date) -> ExyteChat.Message {
        let user: ExyteChat.User
        switch message.role {
        case .user:
            user = ExyteChat.User(id: "current-user", name: "You", avatarURL: nil, isCurrentUser: true)
        case .assistant:
            user = ExyteChat.User(id: "assistant", name: "Assistant", avatarURL: nil, isCurrentUser: false)
        case .system:
            user = ExyteChat.User(id: "system", name: "System", avatarURL: nil, type: .system)
        case .unknown:
            user = ExyteChat.User(id: "unknown", name: "Unknown", avatarURL: nil, isCurrentUser: false)
        }

        let status: ExyteChat.Message.Status?
        switch message.state {
        case .sending:
            status = .sending
        case .sent:
            status = .sent
        case .failed:
            let draft = DraftMessage(
                text: message.text,
                medias: [],
                giphyMedia: nil,
                recording: nil,
                replyMessage: nil,
                createdAt: createdAt
            )
            status = .error(draft)
        }

        return ExyteChat.Message(
            id: message.id,
            user: user,
            status: status,
            createdAt: createdAt,
            text: message.text
        )
    }
}

#Preview {
    ContentView(chat: PreviewFactory.chat, settings: PreviewFactory.settings, connect: nil)
}

private struct PreviewChatService: ChatServiceType, Sendable {
    func history(sessionKey: String) async throws -> [ChatMessage] { [] }
    func send(sessionKey: String, message: String, thinking: String?, idempotencyKey: String) async throws -> ChatSendResult {
        ChatSendResult(runId: "preview", status: "started")
    }
    func abort(sessionKey: String, runId: String?) async throws {}
    func events() -> AsyncStream<ChatEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

@MainActor
private enum PreviewFactory {
    static let settings = SettingsViewModel(store: SettingsStore(secrets: InMemorySecretStore()))
    static let chat = ChatViewModel(chat: PreviewChatService())
}
