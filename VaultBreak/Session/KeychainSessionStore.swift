import Foundation
import Security

/// Reads/writes the session JSON blob shared with `vaultbreak-cli` (go-keyring: service + account).
protocol KeychainSessionDataSource: Sendable {
    func loadSessionData() -> Data?
    @discardableResult
    func saveSessionData(_ data: Data) -> OSStatus
    @discardableResult
    func deleteSessionData() -> OSStatus
}

/// Loads Keychain secrets the same way go-keyring does: via `/usr/bin/security`.
///
/// On recent macOS, `SecItemCopyMatching` can hang indefinitely on items created by
/// the `security` CLI (even with `-A`), while `security find-generic-password -w`
/// returns immediately. Prefer the CLI path so the menu bar never blocks.
struct SystemKeychainSessionDataSource: KeychainSessionDataSource {
    let service: String
    let account: String
    var securityPath: String = "/usr/bin/security"

    func loadSessionData() -> Data? {
        if let data = loadViaSecurityCLI() {
            return data
        }
        // Fallback for environments where security CLI is unavailable.
        return loadViaSecItem()
    }

    func saveSessionData(_ data: Data) -> OSStatus {
        // Replace rather than update so ACL stays open (-A), matching CLI.
        _ = deleteSessionData()
        guard let password = String(data: data, encoding: .utf8) else {
            return errSecParam
        }
        return addGenericPasswordAllowAll(password: password)
    }

    func deleteSessionData() -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        let status = SecItemDelete(query as CFDictionary)
        // Also clear via CLI in case SecItem cannot see the item.
        _ = runSecurity([
            "delete-generic-password",
            "-s", service,
            "-a", account,
        ])
        return status
    }

    private func loadViaSecurityCLI() -> Data? {
        guard let output = runSecurity([
            "find-generic-password",
            "-s", service,
            "-a", account,
            "-w",
        ]) else {
            return nil
        }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Data(trimmed.utf8)
    }

    private func loadViaSecItem() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }

    /// Mirrors CLI `security -i` + `add-generic-password -A -s … -a … -w …`.
    private func addGenericPasswordAllowAll(password: String) -> OSStatus {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: securityPath)
        process.arguments = ["-i"]
        let stdin = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = Pipe()
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return errSecIO
        }
        let line = "add-generic-password -A -s \(Self.shellQuote(service)) -a \(Self.shellQuote(account)) -w \(Self.shellQuote(password))\n"
        guard let commandData = line.data(using: .utf8), commandData.count <= 4096 else {
            process.terminate()
            _ = try? process.waitUntilExit()
            return errSecParam
        }
        stdin.fileHandleForWriting.write(commandData)
        try? stdin.fileHandleForWriting.close()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? errSecSuccess : errSecInternalError
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func runSecurity(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: securityPath)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
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
        guard let raw = dataSource.loadSessionData() else {
            return nil
        }
        let data = Self.decodeGoKeyringPayload(raw)
        do {
            return try Session.decode(from: data)
        } catch {
            return nil
        }
    }

    func save(_ session: Session) throws {
        let json = try session.encode()
        let payload = Self.encodeGoKeyringPayload(json)
        let status = dataSource.saveSessionData(payload)
        guard status == errSecSuccess else {
            throw KeychainSessionError.saveFailed(status)
        }
    }

    func clear() throws {
        let status = dataSource.deleteSessionData()
        // Already absent is success (SecItemDelete / missing item).
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainSessionError.clearFailed(status)
        }
        // Durable logout: refuse to claim success if a blob is still readable.
        if load() != nil {
            throw KeychainSessionError.clearFailed(errSecInternalError)
        }
    }

    /// go-keyring stores secrets with a well-known prefix so multiline/binary
    /// values survive `security`. Strip and decode before JSON parsing.
    static func decodeGoKeyringPayload(_ data: Data) -> Data {
        guard let text = String(data: data, encoding: .utf8) else {
            return data
        }
        let base64Prefix = "go-keyring-base64:"
        if text.hasPrefix(base64Prefix) {
            let encoded = String(text.dropFirst(base64Prefix.count))
            if let decoded = Data(base64Encoded: encoded) {
                return decoded
            }
        }
        let hexPrefix = "go-keyring-encoded:"
        if text.hasPrefix(hexPrefix) {
            let hex = String(text.dropFirst(hexPrefix.count))
            if let decoded = dataFromHexString(hex) {
                return decoded
            }
        }
        return data
    }

    static func encodeGoKeyringPayload(_ json: Data) -> Data {
        let wrapped = "go-keyring-base64:" + json.base64EncodedString()
        return Data(wrapped.utf8)
    }

    private static func dataFromHexString(_ hex: String) -> Data? {
        var remaining = hex[...]
        if remaining.count % 2 != 0 { return nil }
        var data = Data(capacity: remaining.count / 2)
        while !remaining.isEmpty {
            let prefix = remaining.prefix(2)
            remaining = remaining.dropFirst(2)
            guard let byte = UInt8(prefix, radix: 16) else { return nil }
            data.append(byte)
        }
        return data
    }
}
