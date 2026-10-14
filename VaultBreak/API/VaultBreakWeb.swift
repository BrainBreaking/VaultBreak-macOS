import Foundation

/// Single source of truth for VaultBreak web app URLs.
enum VaultBreakWeb {
    static let baseURL = URL(string: "https://vault.brainbreaking.com")!
    static var overviewURL: URL { baseURL.appendingPathComponent("overview") }
    static var handoffsURL: URL { baseURL.appendingPathComponent("handoffs") }
}
