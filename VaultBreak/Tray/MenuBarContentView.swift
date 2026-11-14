import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppSessionModel
    @ObservedObject var lockState: VaultLockState
    @ObservedObject var handoffModel: HandoffAttentionModel
    @StateObject private var popoverViewModel: PopoverSecretsViewModel
    @State private var popoverVisible = false
    @State private var appIsActive = NSApplication.shared.isActive
    @State private var loginItemEnabled = LoginItemService.isEnabled
    @State private var loginItemError: String?
    @State private var quitButtonHovered = false
    @StateObject private var signIn = DeviceSignInModel()
    @StateObject private var deleteAccount = DeleteAccountModel()

    init(model: AppSessionModel, lockState: VaultLockState, handoffModel: HandoffAttentionModel) {
        self.model = model
        self.lockState = lockState
        self.handoffModel = handoffModel
        _popoverViewModel = StateObject(wrappedValue: PopoverSecretsViewModel(sessionModel: model))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isSignedIn {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VaultBreak")
                            .font(.headline)
                            .foregroundStyle(BrainBreakingTheme.sand)
                        Text(signedInDescription)
                            .font(.caption)
                            .foregroundStyle(BrainBreakingTheme.muted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .accessibilityLabel(signedInDescription)
                    }
                    Spacer(minLength: 8)
                    Menu {
                        Button("Manage Account…") {
                            NSWorkspace.shared.open(VaultBreakWeb.overviewURL)
                        }
                        Button("Sign Out…") {
                            confirmAndLogOut()
                        }
                        Divider()
                        Button("Delete Account…", role: .destructive) {
                            startAccountDeletion()
                        }
                        .disabled(
                            deleteAccount.state == .authorizing || deleteAccount.state == .presenting
                        )
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Account actions")
                    .accessibilityLabel("Account menu")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                Divider().overlay(BrainBreakingTheme.border)
                PopoverView(
                    viewModel: popoverViewModel,
                    lockState: lockState,
                    handoffModel: handoffModel,
                    onOpenVault: {
                        MiniConsolePresenter.open(sessionModel: model, lockState: lockState)
                    }
                )
                if case .failed(let message) = deleteAccount.state {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(BrainBreakingTheme.sand, BrainBreakingTheme.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Launch at Login")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(BrainBreakingTheme.sand)
                        Text("Start VaultBreak when you log in to this Mac.")
                            .font(.caption)
                            .foregroundStyle(BrainBreakingTheme.muted)
                    }
                    Spacer(minLength: 8)
                    Toggle("Launch at Login", isOn: Binding(
                        get: { loginItemEnabled },
                        set: { requestedValue in
                            if LoginItemService.setEnabled(requestedValue) {
                                loginItemEnabled = requestedValue
                                loginItemError = nil
                            } else {
                                loginItemEnabled = LoginItemService.isEnabled
                                loginItemError = "Could not change the login setting. Try again."
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(BrainBreakingTheme.accent)
                    .accessibilityLabel("Launch at Login")
                    .accessibilityHint("Starts VaultBreak automatically when you log in to this Mac")
                }
                if let loginItemError {
                    Label(loginItemError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(10)
            .background(BrainBreakingTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.caption.weight(.semibold))
                    Text("Quit VaultBreak")
                        .font(.subheadline)
                    Spacer()
                    Text("⌘Q")
                        .font(.caption.monospaced())
                        .foregroundStyle(BrainBreakingTheme.muted)
                }
                .foregroundStyle(BrainBreakingTheme.sand)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    (quitButtonHovered ? BrainBreakingTheme.surface : BrainBreakingTheme.surface.opacity(0.45)),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
            .onHover { quitButtonHovered = $0 }
            .accessibilityHint("Closes VaultBreak")
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .frame(width: 340)
        .background(BrainBreakingTheme.ink)
        .environment(\.colorScheme, .dark)
        .onAppear {
            loginItemEnabled = LoginItemService.isEnabled
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

    private var signedInDescription: String {
        guard let label = model.accountLabel, label != "Signed in" else {
            return "Signed in"
        }
        return "Signed in as \(label)"
    }

    private func startAccountDeletion() {
        deleteAccount.start(
            authorizing: {
                let client = try model.makeAPIClient()
                return try await client.accountDeletionAuthorizationURL()
            },
            clearingSession: { try model.clearSession() }
        )
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
