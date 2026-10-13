import AppKit
import SwiftUI

@main
struct VaultBreakApp: App {
    @NSApplicationDelegateAdaptor(VaultBreakAppDelegate.self) private var appDelegate
    @StateObject private var sessionModel: AppSessionModel
    @StateObject private var vaultLock: VaultLockState
    @StateObject private var handoffModel: HandoffAttentionModel

    init() {
        let session = AppSessionModel()
        let vaultLock = VaultLockState()
        session.onOpenVault = {
            MiniConsolePresenter.open(sessionModel: session, lockState: vaultLock)
        }
        ApplicationURLHandler.onOpenURL = { url in
            Task { @MainActor in
                session.handleOpenURL(url)
            }
        }
        _sessionModel = StateObject(wrappedValue: session)
        _vaultLock = StateObject(wrappedValue: vaultLock)
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
