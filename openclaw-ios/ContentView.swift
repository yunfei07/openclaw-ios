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
    @State private var localMessagesById: [String: ChatMessage] = [:]

    var body: some View {
        NavigationStack {
            ChatView(messages: exyteMessages, chatType: .conversation, didSendMessage: handleDraftMessage, messageBuilder: buildMessage, messageMenuAction: { action, defaultActionClosure, message in
                handleMenuAction(action: action, defaultActionClosure: defaultActionClosure, message: message)
            })
                .showDateHeaders(false)
                .keyboardDismissMode(.interactive)
                .navigationTitle("OpenClaw")
                .navigationBarTitleDisplayMode(.inline)
                .background(ChatTableViewTuner())
                .background(ChatUIStyle.background)
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
        let replyQuote = draft.replyMessage.map {
            ChatMessageQuote(id: $0.id, author: $0.user.name, text: $0.text)
        }
        Task {
            try? await chat.sendMessage(text: trimmed, replyTo: replyQuote, forwardedFrom: nil)
        }
    }

    private func hasUnsupportedAttachments(_ draft: DraftMessage) -> Bool {
        !draft.medias.isEmpty || draft.giphyMedia != nil || draft.recording != nil
    }

    @MainActor
    private func updateMessages(from messages: [ChatMessage]) {
        localMessagesById = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { _, newest in newest })
        exyteMessages = messages.map { mapMessage($0) }
    }

    private func mapMessage(_ message: ChatMessage) -> ExyteChat.Message {
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
                createdAt: message.createdAt
            )
            status = .error(draft)
        }

        let replyMessage = message.replyTo.map {
            ReplyMessage(
                id: $0.id,
                user: ExyteChat.User(id: "reply-\($0.id)", name: $0.author, avatarURL: nil, isCurrentUser: false),
                createdAt: message.createdAt,
                text: $0.text
            )
        }

        return ExyteChat.Message(
            id: message.id,
            user: user,
            status: status,
            createdAt: message.createdAt,
            text: message.text,
            replyMessage: replyMessage
        )
    }

    private func buildMessage(
        _ message: ExyteChat.Message,
        _ positionInGroup: PositionInUserGroup,
        _ positionInSection: PositionInMessagesSection,
        _ _: CommentsPosition?,
        _ showContextMenu: @escaping () -> Void,
        _ _: @escaping (ExyteChat.Message, DefaultMessageMenuAction) -> Void,
        _ _: @escaping (Attachment) -> Void
    ) -> some View {
        TelegramMessageRowView(
            message: message,
            localMessage: localMessagesById[message.id],
            positionInGroup: positionInGroup,
            positionInSection: positionInSection,
            onLongPress: showContextMenu
        )
    }

    private func handleMenuAction(
        action: TelegramMenuAction,
        defaultActionClosure: @escaping (ExyteChat.Message, DefaultMessageMenuAction) -> Void,
        message: ExyteChat.Message
    ) {
        switch action {
        case .copy:
            defaultActionClosure(message, .copy)
        case .reply:
            defaultActionClosure(message, .reply)
        case .forward:
            sendForwarded(message)
        case .edit:
            guard canEditMessage(message) else { return }
            defaultActionClosure(message, .edit { editedText in
                chat.updateMessageText(id: message.id, newText: editedText)
            })
        case .delete:
            chat.markMessageDeleted(id: message.id)
        }
    }

    private func canEditMessage(_ message: ExyteChat.Message) -> Bool {
        guard message.user.isCurrentUser else { return false }
        switch message.status {
        case .sending, .error:
            return true
        default:
            return false
        }
    }

    private func sendForwarded(_ message: ExyteChat.Message) {
        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task {
            try? await chat.sendMessage(text: text, replyTo: nil, forwardedFrom: message.user.name)
        }
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

private enum TelegramMenuAction: MessageMenuAction {
    case copy
    case reply
    case forward
    case edit
    case delete

    func title() -> String {
        switch self {
        case .copy:
            return "复制"
        case .reply:
            return "回复"
        case .forward:
            return "转发"
        case .edit:
            return "编辑"
        case .delete:
            return "删除"
        }
    }

    func icon() -> Image {
        switch self {
        case .copy:
            return Image(systemName: "doc.on.doc")
        case .reply:
            return Image(systemName: "arrowshape.turn.up.left")
        case .forward:
            return Image(systemName: "arrowshape.turn.up.right")
        case .edit:
            if #available(iOS 18.0, macCatalyst 18.0, *) {
                return Image(systemName: "bubble.and.pencil")
            }
            return Image(systemName: "square.and.pencil")
        case .delete:
            return Image(systemName: "trash")
        }
    }

    static func menuItems(for message: ExyteChat.Message) -> [TelegramMenuAction] {
        var items: [TelegramMenuAction] = [.copy, .reply, .forward]
        let canEdit: Bool
        switch message.status {
        case .sending, .error:
            canEdit = true
        default:
            canEdit = false
        }
        if message.user.isCurrentUser && canEdit {
            items.append(.edit)
            items.append(.delete)
        }
        return items
    }
}
