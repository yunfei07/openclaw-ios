import Foundation
import Security

public protocol SecretStoring: Sendable {
    func load(key: String) -> String?
    func save(key: String, value: String)
    func delete(key: String)
}

public final class InMemorySecretStore: SecretStoring, @unchecked Sendable {
    private var values: [String: String] = [:]

    public init() {}

    public func load(key: String) -> String? {
        values[key]
    }

    public func save(key: String, value: String) {
        values[key] = value
    }

    public func delete(key: String) {
        values.removeValue(forKey: key)
    }
}

public final class KeychainSecretStore: SecretStoring, @unchecked Sendable {
    private let service: String

    public init(service: String = "openclaw-ios") {
        self.service = service
    }

    public func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func save(key: String, value: String) {
        delete(key: key)
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    public func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
