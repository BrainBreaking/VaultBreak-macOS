import Foundation

/// Single source of truth for VaultBreak web app URLs.
enum VaultBreakWeb {
    static let productionBaseURL = URL(string: "https://vault.brainbreaking.com")!

    static var baseURL: URL {
        resolvedBaseURL()
    }

    /// Allows Debug builds to exercise an HTTPS preview or an HTTP loopback
    /// server without making the override available to release builds.
    static func resolvedBaseURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        #if DEBUG
        if let raw = environment["VAULTBREAK_API_BASE_URL"],
           let override = debugOrigin(from: raw) {
            return override
        }
        #endif
        return productionBaseURL
    }

    #if DEBUG
    private static func debugOrigin(from raw: String) -> URL? {
        guard var components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/"
        else { return nil }

        let isHTTPS = scheme == "https"
        let isHTTPLoopback = scheme == "http"
            && (host == "localhost" || host == "127.0.0.1" || host == "::1")
        guard isHTTPS || isHTTPLoopback else { return nil }

        components.scheme = scheme
        components.path = ""
        return components.url
    }
    #endif

    static var overviewURL: URL { baseURL.appendingPathComponent("overview") }
    static var handoffsURL: URL { baseURL.appendingPathComponent("handoffs") }
    static var accountDeletionURL: URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("account/delete"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "return_to", value: "vaultbreak://account-deleted")
        ]
        return components.url!
    }
}
