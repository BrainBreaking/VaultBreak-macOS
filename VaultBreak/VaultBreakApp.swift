import AppKit
import SwiftUI

@main
struct VaultBreakApp: App {
    @NSApplicationDelegateAdaptor(VaultBreakAppDelegate.self) private var appDelegate
    @StateObject private var sessionModel: AppSessionModel
    @StateObject private var vaultLock = VaultLockState()
    @StateObject private var handoffModel: HandoffAttentionModel

    init() {
        let session = AppSessionModel()
        _sessionModel = StateObject(wrappedValue: session)
        _handoffModel = StateObject(wrappedValue: HandoffAttentionModel(sessionModel: session))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: sessionModel, lockState: vaultLock, handoffModel: handoffModel)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    sessionModel.reload()
                }
        } label: {
            MenuBarExtraLabel(model: sessionModel, handoffModel: handoffModel)
        }
        .menuBarExtraStyle(.window)
    }
}
