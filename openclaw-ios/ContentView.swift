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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusView
                messagesView
                inputView
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
        VStack(alignment: .leading, spacing: 4) {
            Text("状态：\(chat.connectionState)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let errorMessage = chat.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var messagesView: some View {
        Group {
            if chat.messages.isEmpty {
                Text("暂无消息")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                List(chat.messages) { message in
                    HStack(alignment: .top, spacing: 8) {
                        Text(message.role.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(message.text)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inputView: some View {
        HStack(spacing: 12) {
            TextField("输入消息", text: $chat.inputText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("发送") {
                Task {
                    try? await chat.sendMessage()
                }
            }
            .disabled(chat.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
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
