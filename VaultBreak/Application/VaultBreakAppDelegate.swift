import AppKit

@MainActor
enum ApplicationURLHandler {
    static var onOpenURL: ((URL) -> Void)?
}

final class VaultBreakAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in
            LoginItemService.applyOnFirstLaunch()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { @MainActor in
                ApplicationURLHandler.onOpenURL?(url)
            }
        }
    }
}
