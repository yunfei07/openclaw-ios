import Foundation
import Testing
@testable import OpenClawClientCore

struct SettingsStoreTests {
    @Test func savesAndLoadsGatewaySettings() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let secrets = InMemorySecretStore()
        let store = SettingsStore(defaults: defaults, secrets: secrets)

        store.saveGatewayUrl("ws://127.0.0.1:18789")
        store.saveGatewayToken("tok")

        #expect(store.loadGatewayUrl() == "ws://127.0.0.1:18789")
        #expect(store.loadGatewayToken() == "tok")
    }

    @Test func clearsGatewayToken() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let secrets = InMemorySecretStore()
        let store = SettingsStore(defaults: defaults, secrets: secrets)

        store.saveGatewayToken("tok")
        store.clearGatewayToken()

        #expect(store.loadGatewayToken() == nil)
    }
}
