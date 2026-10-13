import AppKit
import SwiftUI

@main
struct VaultBreakApp: App {
    @NSApplicationDelegateAdaptor(VaultBreakAppDelegate.self) private var appDelegate
    @StateObject private var sessionModel = AppSessionModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: sessionModel)
                .onAppear {
                    ApplicationURLHandler.onOpenURL = { url in
                        sessionModel.handleOpenURL(url)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    sessionModel.reload()
                }
        } label: {
            MenuBarExtraLabel(model: sessionModel)
        }
        .menuBarExtraStyle(.menu)
    }
}
