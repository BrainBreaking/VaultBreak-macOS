import Foundation
import Security

/// Reads the session JSON blob written by `vaultbreak-cli` (go-keyring: service + account generic password).
protocol KeychainSessionDataSource: Sendable {
    func loadSessionData() -> Data?
    @discardableResult
    func deleteSessionData() -> OSStatus
}

struct SystemKeychainSessionDataSource: KeychainSessionDataSource {
    let service: String
    let account: String

    func loadSessionData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }

    func deleteSessionData() -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        return SecItemDelete(query as CFDictionary)
    }
}

struct KeychainSessionStore {
    static let service = "com.brainbreaking.vaultbreak"
    static let account = "session"

    private let dataSource: KeychainSessionDataSource

    init(dataSource: KeychainSessionDataSource? = nil) {
        self.dataSource = dataSource
            ?? SystemKeychainSessionDataSource(service: Self.service, account: Self.account)
    }

    func load() -> Session? {
        guard let data = dataSource.loadSessionData() else {
            return nil
        }
        do {
            return try Session.decode(from: data)
        } catch {
            return nil
        }
    }

    func clear() {
        _ = dataSource.deleteSessionData()
    }
}
