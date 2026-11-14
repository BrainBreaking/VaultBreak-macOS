import Foundation

enum VaultBreakURLAction: Equatable {
    case open
    case sessionUpdated
    case accountDeleted
}

enum VaultBreakAuthenticationResult: Equatable {
    case approved
    case denied
}

enum VaultBreakURLParser {
    static let callbackScheme = "vaultbreak"

    /// Parses `vaultbreak://` URLs into a known action (host only; path/query ignored).
    static func action(for url: URL) -> VaultBreakURLAction? {
        guard url.scheme?.lowercased() == "vaultbreak" else { return nil }
        switch url.host?.lowercased() {
        case "open":
            return .open
        case "session-updated":
            return .sessionUpdated
        case "account-deleted":
            return .accountDeleted
        default:
            return nil
        }
    }

    static func authenticationResult(for url: URL) -> VaultBreakAuthenticationResult? {
        guard action(for: url) == .sessionUpdated,
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "result" })?
                .value?
                .lowercased()
        else { return nil }
        switch value {
        case "approved": return .approved
        case "denied": return .denied
        default: return nil
        }
    }

    static func isExactAccountDeletedCallback(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == callbackScheme,
              url.host?.lowercased() == "account-deleted"
        else { return false }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return (components?.path ?? "").isEmpty
            && (components?.queryItems?.isEmpty ?? true)
            && components?.fragment == nil
    }
}
