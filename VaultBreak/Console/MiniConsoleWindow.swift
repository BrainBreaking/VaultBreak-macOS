import AppKit
import SwiftUI

@MainActor
enum MiniConsolePresenter {
    private static var windowController: MiniConsoleWindowController?

    static func open(sessionModel: AppSessionModel, lockState: VaultLockState) {
        if windowController == nil {
            windowController = MiniConsoleWindowController(
                sessionModel: sessionModel,
                lockState: lockState
            )
        }
        windowController?.show()
    }
}

@MainActor
final class MiniConsoleWindowController: NSWindowController, NSWindowDelegate {
    private let sessionModel: AppSessionModel
    private let lockState: VaultLockState
    private let secretsViewModel: ConsoleSecretsViewModel
    private let handoffsViewModel: ConsoleHandoffsViewModel

    init(sessionModel: AppSessionModel, lockState: VaultLockState) {
        self.sessionModel = sessionModel
        self.lockState = lockState
        self.secretsViewModel = ConsoleSecretsViewModel {
            try? sessionModel.makeAPIClient()
        }
        self.handoffsViewModel = ConsoleHandoffsViewModel {
            try? sessionModel.makeAPIClient()
        }

        let root = MiniConsoleContentView(
            sessionModel: sessionModel,
            lockState: lockState,
            secretsViewModel: secretsViewModel,
            handoffsViewModel: handoffsViewModel
        )
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vault"
        window.contentViewController = hosting
        window.minSize = NSSize(width: 400, height: 280)
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        MiniConsolePresenter.releaseWindow()
    }
}

extension MiniConsolePresenter {
    fileprivate static func releaseWindow() {
        windowController = nil
    }
}
