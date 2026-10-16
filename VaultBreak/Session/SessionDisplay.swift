import Foundation

enum SessionDisplay {
    static let placeholder = "—"

    /// Host from session API base URL for status strip (invalid/missing → placeholder).
    static func apiURLHost(from apiURLString: String) -> String {
        let trimmed = apiURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return placeholder }
        guard let url = URL(string: trimmed), let host = url.host, !host.isEmpty else {
            return placeholder
        }
        return host
    }

    /// Email for console status strip (missing/blank → placeholder).
    static func consoleEmail(from session: Session?) -> String {
        guard let session else { return placeholder }
        if let email = session.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        return placeholder
    }
}
