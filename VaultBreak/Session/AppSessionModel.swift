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
