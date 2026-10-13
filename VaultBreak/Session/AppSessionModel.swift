import AppKit
import Foundation

@MainActor
final class AppSessionModel: ObservableObject {
    @Published private(set) var session: Session?

    private let store: KeychainSessionStore

    var isSignedIn: Bool {
        session != nil
    }

    /// User-visible account line for the menu (never includes token).
    var accountLabel: String? {
        guard let session else { return nil }
        if let email = session.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        return "Signed in"
    }

    init(store: KeychainSessionStore = KeychainSessionStore()) {
        self.store = store
        reload()
        ApplicationURLHandler.onOpenURL = { [weak self] url in
            Task { @MainActor in
                self?.handleOpenURL(url)
            }
        }
    }

    /// Builds an API client from the current Keychain session. On 401/403 the client clears Keychain and signs out.
    func makeAPIClient(urlSession: URLSession = .shared) throws -> APIClient {
        guard let session else {
            throw APIClientError.unauthorized
        }
        return try APIClient(session: session, urlSession: urlSession) { [weak self] in
            Task { @MainActor in
                self?.clearSession()
            }
        }
    }

    func reload() {
        session = store.load()
    }

    func clearSession() {
        store.clear()
        session = nil
    }

    func handleOpenURL(_ url: URL) {
        guard url.scheme?.lowercased() == "vaultbreak" else { return }

        switch url.host?.lowercased() {
        case "session-updated":
            reload()
        case "open":
            break
        default:
            break
        }
    }
}
