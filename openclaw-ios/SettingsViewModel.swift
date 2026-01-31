import Foundation
import Observation
import OpenClawClientCore

@Observable
final class SettingsViewModel {
    var gatewayUrl: String
    var gatewayToken: String
    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
        self.gatewayUrl = store.loadGatewayUrl() ?? ""
        self.gatewayToken = store.loadGatewayToken() ?? ""
    }

    func save() {
        store.saveGatewayUrl(gatewayUrl)
        if !gatewayToken.isEmpty {
            store.saveGatewayToken(gatewayToken)
        }
    }

    func clearToken() {
        gatewayToken = ""
        store.clearGatewayToken()
    }
}
