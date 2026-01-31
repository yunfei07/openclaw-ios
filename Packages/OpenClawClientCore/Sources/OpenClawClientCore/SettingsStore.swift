import Foundation

public final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let secrets: SecretStoring
    private let urlKey = "gateway.url"
    private let tokenKey = "gateway.token"

    public init(defaults: UserDefaults = .standard, secrets: SecretStoring) {
        self.defaults = defaults
        self.secrets = secrets
    }

    public func loadGatewayUrl() -> String? {
        defaults.string(forKey: urlKey)
    }

    public func saveGatewayUrl(_ value: String) {
        defaults.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: urlKey)
    }

    public func loadGatewayToken() -> String? {
        secrets.load(key: tokenKey)
    }

    public func saveGatewayToken(_ value: String) {
        secrets.save(key: tokenKey, value: value)
    }

    public func clearGatewayToken() {
        secrets.delete(key: tokenKey)
    }
}
