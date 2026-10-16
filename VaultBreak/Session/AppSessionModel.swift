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

    /// Opens the mini-console when `vaultbreak://open` is received (set by the app entry point).
    var onOpenVault: (() -> Void)?

    init(store: KeychainSessionStore = KeychainSessionStore()) {
        self.store = store
        reload()
    }

    /// Builds an API client from the current Keychain session. On 401/403 the client clears Keychain and signs out.
    func makeAPIClient(urlSession: URLSession = .shared) throws -> APIClient {
        guard let session else {
            throw APIClientError.unauthorized
        }
        return try APIClient(session: session, urlSession: urlSession) { [weak self] in
            Task { @MainActor in
                try? self?.clearSession()
            }
        }
    }

    func reload() {
        session = store.load()
    }

    func clearSession() throws {
        try store.clear()
        session = nil
    }

    /// Persists a new session (device login) and updates in-memory state.
    func applySession(_ session: Session) throws {
        try store.save(session)
        self.session = session
    }

    /// Opens the VaultBreak web app for handoff review (same host as CLI `open`).
    func openHandoffsInBrowser() {
        NSWorkspace.shared.open(VaultBreakWeb.handoffsURL)
    }

    func handleOpenURL(_ url: URL) {
        switch VaultBreakURLParser.action(for: url) {
        case .sessionUpdated:
            reload()
        case .open:
            onOpenVault?()
        case nil:
            break
        }
    }
}
