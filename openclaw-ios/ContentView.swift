//
//  ContentView.swift
//  openclaw-ios
//
//  Created by yangyunfei on 2026/1/30.
//

import Observation
import OpenClawClientCore
import SwiftUI

struct ContentView: View {
    @Bindable var chat: ChatViewModel
    @Bindable var settings: SettingsViewModel
    let connect: (() async -> Void)?
    @State private var showingSettings = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                ChatUIStyle.background
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    statusView
                    messagesView
                    inputView
                }
            }
                .navigationTitle("OpenClaw")
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
                }
        }
    }

    private var statusView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(ChatUIStyle.statusPillText)
                if chat.connectionState == "connecting" {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(ChatUIStyle.statusPillBackground)
            .clipShape(.rect(cornerRadius: 12))
            if let errorMessage = chat.errorMessage {
                Text(errorMessage)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(ChatUIStyle.errorText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if chat.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(chat.messages) { message in
                            ChatMessageRow(message: message)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: chat.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onTapGesture {
                inputFocused = false
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inputView: some View {
        HStack(spacing: 12) {
            TextField("输入消息", text: $chat.inputText, axis: .vertical)
                .lineLimit(1...4)
                .focused($inputFocused)
                .font(.system(.body, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(ChatUIStyle.inputBackground)
                .clipShape(.rect(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(ChatUIStyle.inputBorder, lineWidth: 1)
                )
            Button {
                Task {
                    try? await chat.sendMessage()
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(canSend ? ChatUIStyle.sendButton : ChatUIStyle.sendButtonDisabled)
                    .clipShape(Circle())
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground).opacity(0.9))
    }

    private var statusText: String {
        switch chat.connectionState {
        case "connected":
            return "已连接"
        case "connecting":
            return "连接中…"
        case "failed":
            return "连接失败"
        default:
            return "未连接"
        }
    }

    private var statusColor: Color {
        switch chat.connectionState {
        case "connected":
            return .green
        case "connecting":
            return .orange
        case "failed":
            return .red
        default:
            return .secondary
        }
    }

    private var canSend: Bool {
        !chat.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("开始你的第一条对话")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)
            Text("在设置里配置网关后即可对话")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
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

private struct ChatMessageRow: View {
    let message: ChatMessage

    private var isOutgoing: Bool { message.role == .user }

    var body: some View {
        switch message.role {
        case .system, .unknown:
            Text(message.text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 10))
                .frame(maxWidth: .infinity, alignment: .center)
        default:
            HStack(alignment: .bottom, spacing: 8) {
                if isOutgoing { Spacer(minLength: 32) }
                VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                    ChatBubbleView(text: message.text, isOutgoing: isOutgoing)
                    if message.state == .sending {
                        Text("发送中…")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else if message.state == .failed {
                        Text("发送失败")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(ChatUIStyle.errorText)
                    }
                }
                if !isOutgoing { Spacer(minLength: 32) }
            }
            .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
        }
    }
}
