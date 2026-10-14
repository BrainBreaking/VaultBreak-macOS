import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppSessionModel
    @ObservedObject var lockState: VaultLockState
    @ObservedObject var handoffModel: HandoffAttentionModel
    @StateObject private var popoverViewModel: PopoverSecretsViewModel
    @State private var popoverVisible = false
    @State private var appIsActive = NSApplication.shared.isActive
    @StateObject private var signIn = DeviceSignInModel(openURL: { NSWorkspace.shared.open($0) })

    init(model: AppSessionModel, lockState: VaultLockState, handoffModel: HandoffAttentionModel) {
        self.model = model
        self.lockState = lockState
        self.handoffModel = handoffModel
        _popoverViewModel = StateObject(wrappedValue: PopoverSecretsViewModel(sessionModel: model))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isSignedIn {
                if let label = model.accountLabel {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(BrainBreakingTheme.muted)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                }
                PopoverView(viewModel: popoverViewModel, lockState: lockState, handoffModel: handoffModel)
                Divider().overlay(BrainBreakingTheme.border)
                Button {
                    MiniConsolePresenter.open(sessionModel: model, lockState: lockState)
                } label: {
                    Text("Open Vault…")
                        .foregroundStyle(BrainBreakingTheme.sand)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                if lockState.isLocked {
                    Button {
                        Task { await lockState.unlock() }
                    } label: {
                        Text("Unlock Vault…")
                            .foregroundStyle(BrainBreakingTheme.sand)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                } else {
                    Button {
                        lockState.lock()
                        popoverViewModel.clearLoadedSecrets()
                    } label: {
                        Text("Lock Vault")
                            .foregroundStyle(BrainBreakingTheme.sand)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                Button {
                    NSWorkspace.shared.open(VaultBreakWeb.overviewURL)
                } label: {
                    Text("Management")
                        .foregroundStyle(BrainBreakingTheme.sand)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Button {
                    confirmAndLogOut()
                } label: {
                    Text("Log out…")
                        .foregroundStyle(BrainBreakingTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("VaultBreak")
                        .font(.headline)
                        .foregroundStyle(BrainBreakingTheme.sand)
                    switch signIn.state {
                    case .idle, .failed:
                        if case .failed(let message) = signIn.state {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Button("Sign in…") {
                            signIn.start { try model.applySession($0) }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(BrainBreakingTheme.sand)
                    case .starting:
                        Text("Contacting VaultBreak…")
                            .font(.subheadline)
                            .foregroundStyle(BrainBreakingTheme.muted)
                        Button("Cancel") { signIn.cancel() }
                            .buttonStyle(.plain)
                            .foregroundStyle(BrainBreakingTheme.muted)
                    case .waiting(let userCode):
                        Text(userCode)
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(BrainBreakingTheme.sand)
                            .textSelection(.enabled)
                        Text("Waiting for approval…")
                            .font(.subheadline)
                            .foregroundStyle(BrainBreakingTheme.muted)
                        Button("Cancel") { signIn.cancel() }
                            .buttonStyle(.plain)
                            .foregroundStyle(BrainBreakingTheme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
            Divider().overlay(BrainBreakingTheme.border)
            Toggle("Open at Login", isOn: Binding(
                get: { LoginItemService.isEnabled },
                set: { LoginItemService.isEnabled = $0 }
            ))
            .toggleStyle(.switch)
            .tint(BrainBreakingTheme.accent)
            .foregroundStyle(BrainBreakingTheme.sand)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BrainBreakingTheme.muted)
            .keyboardShortcut("q")
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: 340)
        .background(BrainBreakingTheme.ink)
        .onAppear {
            popoverVisible = true
            updateHandoffPolling()
        }
        .onDisappear {
            popoverVisible = false
            updateHandoffPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appIsActive = true
            updateHandoffPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            appIsActive = false
            updateHandoffPolling()
        }
        .onChange(of: model.isSignedIn) { signedIn in
            if !signedIn {
                lockState.lock()
                popoverViewModel.clearLoadedSecrets()
            }
            updateHandoffPolling()
        }
    }

    private func confirmAndLogOut() {
        let alert = NSAlert()
        alert.messageText = "Sign out of VaultBreak on this Mac?"
        alert.informativeText = "You will need to sign in again to view secrets and handoffs."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Sign Out")
        NSApplication.shared.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do {
            try model.clearSession()
            lockState.lock()
            popoverViewModel.clearLoadedSecrets()
        } catch {
            let fail = NSAlert()
            fail.messageText = "Could not sign out"
            fail.informativeText =
                "VaultBreak could not remove the saved session from Keychain. Try again, or delete the item manually in Keychain Access."
            fail.alertStyle = .warning
            fail.addButton(withTitle: "OK")
            fail.runModal()
        }
    }

    private func updateHandoffPolling() {
        let shouldPoll = model.isSignedIn && (popoverVisible || appIsActive)
        handoffModel.setPollingActive(shouldPoll)
    }
}

struct MenuBarExtraLabel: View {
    @ObservedObject var model: AppSessionModel
    @ObservedObject var lockState: VaultLockState
    @ObservedObject var handoffModel: HandoffAttentionModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: handoffModel.needsAttention ? "exclamationmark.shield.fill" : "lock.shield")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    model.isSignedIn
                        ? (lockState.isLocked ? BrainBreakingTheme.muted : BrainBreakingTheme.sand)
                        : BrainBreakingTheme.muted.opacity(0.7)
                )
            if handoffModel.needsAttention {
                Circle()
                    .fill(BrainBreakingTheme.accent)
                    .frame(width: 7, height: 7)
                    .offset(x: 5, y: -5)
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if !model.isSignedIn { return "VaultBreak, not signed in" }
        if handoffModel.needsAttention { return "VaultBreak, pending handoffs need attention" }
        if lockState.isLocked { return "VaultBreak, locked" }
        return "VaultBreak, unlocked"
    }
}
