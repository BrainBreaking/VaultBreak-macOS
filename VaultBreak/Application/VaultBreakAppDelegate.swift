import AppKit

@MainActor
enum ApplicationURLHandler {
    static var onOpenURL: ((URL) -> Void)?
}

final class VaultBreakAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { @MainActor in
                ApplicationURLHandler.onOpenURL?(url)
            }
        }
    }
}
