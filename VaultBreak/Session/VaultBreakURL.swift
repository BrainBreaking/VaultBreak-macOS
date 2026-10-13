import Foundation

enum VaultBreakURLAction: Equatable {
    case open
    case sessionUpdated
}

enum VaultBreakURLParser {
    /// Parses `vaultbreak://` URLs into a known action (host only; path/query ignored).
    static func action(for url: URL) -> VaultBreakURLAction? {
        guard url.scheme?.lowercased() == "vaultbreak" else { return nil }
        switch url.host?.lowercased() {
        case "open":
            return .open
        case "session-updated":
            return .sessionUpdated
        default:
            return nil
        }
    }
}
