import AppKit
import SwiftUI

@main
struct VaultBreakApp: App {
    @NSApplicationDelegateAdaptor(VaultBreakAppDelegate.self) private var appDelegate
    @StateObject private var sessionModel = AppSessionModel()
    @StateObject private var vaultLock = VaultLockState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: sessionModel, lockState: vaultLock)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    sessionModel.reload()
                }
        } label: {
            MenuBarExtraLabel(model: sessionModel)
        }
        .menuBarExtraStyle(.window)
    }
}
