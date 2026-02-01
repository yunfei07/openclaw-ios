//
//  openclaw_iosApp.swift
//  openclaw-ios
//
//  Created by yangyunfei on 2026/1/30.
//

import Foundation
import OpenClawClientCore
import OpenClawSDK
import SwiftUI

@main
struct openclaw_iosApp: App {
    @State private var chat: ChatViewModel
    @State private var settings: SettingsViewModel
    private let connectAction: () async -> Void

    init() {
        let secrets = KeychainSecretStore()
        let settingsStore = SettingsStore(secrets: secrets)
        let settingsVM = SettingsViewModel(store: settingsStore)

        let tokenStore = InMemoryTokenStore()
        let identityStore = DeviceIdentityStore()
        let urlString = settingsVM.gatewayUrl.isEmpty ? "ws://127.0.0.1:18789" : settingsVM.gatewayUrl
        let url = URL(string: urlString) ?? URL(string: "ws://127.0.0.1:18789")!
        let connection = GatewayConnection(url: url, tokenStore: tokenStore, identityStore: identityStore)
        let chatService = ChatServiceAdapter(gateway: connection)
        let chatVM = ChatViewModel(chat: chatService)

        _settings = State(initialValue: settingsVM)
        _chat = State(initialValue: chatVM)

        connectAction = {
            let token = await MainActor.run {
                settingsVM.gatewayToken.isEmpty ? nil : settingsVM.gatewayToken
            }
            let useDeviceIdentity = token == nil
            await MainActor.run {
                chatVM.connectionState = "connecting"
                chatVM.errorMessage = nil
            }
            do {
                try await connection.connect(sharedToken: token, useDeviceIdentity: useDeviceIdentity)
                await MainActor.run {
                    chatVM.connectionState = "connected"
                    chatVM.startStreaming()
                }
                try await chatVM.loadHistory()
            } catch {
                await MainActor.run {
                    chatVM.connectionState = "failed"
                    chatVM.errorMessage = error.localizedDescription
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(chat: chat, settings: settings, connect: connectAction)
        }
    }
}
