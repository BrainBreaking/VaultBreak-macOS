import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppSessionModel
    @ObservedObject var lockState: VaultLockState
    @ObservedObject var handoffModel: HandoffAttentionModel
    @StateObject private var popoverViewModel: PopoverSecretsViewModel
    @State private var popoverVisible = false
    @State private var appIsActive = NSApplication.shared.isActive

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
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }
                PopoverView(viewModel: popoverViewModel, lockState: lockState, handoffModel: handoffModel)
                Divider()
                Button("Open Vault…") {
                    MiniConsolePresenter.open(sessionModel: model, lockState: lockState)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                if lockState.isLocked {
                    Button("Unlock Vault…") {
                        Task { await lockState.unlock() }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                } else {
                    Button("Lock Vault") {
                        lockState.lock()
                        popoverViewModel.clearLoadedSecrets()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            } else {
                Text("Not signed in — run vaultbreak login")
                    .padding(12)
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: 320)
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

    private func updateHandoffPolling() {
        let shouldPoll = model.isSignedIn && (popoverVisible || appIsActive)
        handoffModel.setPollingActive(shouldPoll)
    }
}

struct MenuBarExtraLabel: View {
    @ObservedObject var model: AppSessionModel
    @ObservedObject var handoffModel: HandoffAttentionModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: handoffModel.needsAttention ? "exclamationmark.shield.fill" : "lock.shield")
                .symbolRenderingMode(.hierarchical)
                .opacity(model.isSignedIn ? 1 : 0.45)
            if handoffModel.needsAttention {
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
                    .offset(x: 5, y: -5)
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if !model.isSignedIn { return "VaultBreak, not signed in" }
        if handoffModel.needsAttention { return "VaultBreak, pending handoffs need attention" }
        return "VaultBreak, signed in"
    }
}
