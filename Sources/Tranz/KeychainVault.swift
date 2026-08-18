import Foundation
import Security

/// Stores the API key in the macOS Keychain (never in UserDefaults or plaintext).
final class KeychainVault {
    static let shared = KeychainVault()

    private let service: String
    private let defaultAccount = "api-key"

    private init() {
        self.service = Bundle.main.bundleIdentifier ?? "com.activebook.tranz"
    }

    @discardableResult
    func save(_ value: String, for accountKey: String = "api-key") -> Bool {
        let account = accountKey.isEmpty ? defaultAccount : accountKey
        let data = Data(value.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Remove any existing item first to make the save idempotent.
        SecItemDelete(baseQuery as CFDictionary)

        if value.isEmpty {
            return true
        }

        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func load(for accountKey: String = "api-key") -> String? {
        let account = accountKey.isEmpty ? defaultAccount : accountKey
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func delete(for accountKey: String = "api-key") {
        let account = accountKey.isEmpty ? defaultAccount : accountKey
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
