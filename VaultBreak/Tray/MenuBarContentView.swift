import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppSessionModel
    @ObservedObject var lockState: VaultLockState
    @StateObject private var popoverViewModel: PopoverSecretsViewModel

    init(model: AppSessionModel, lockState: VaultLockState) {
        self.model = model
        self.lockState = lockState
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
                PopoverView(viewModel: popoverViewModel, lockState: lockState)
                Divider()
                if lockState.isLocked {
                    Button("Unlock Vault…") {
                        Task { await lockState.unlock() }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                } else {
                    Button("Lock Vault") {
                        lockState.lock()
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
        .onChange(of: model.isSignedIn) { signedIn in
            if !signedIn {
                lockState.lock()
            }
        }
    }
}

struct MenuBarExtraLabel: View {
    @ObservedObject var model: AppSessionModel

    var body: some View {
        Image(systemName: "lock.shield")
            .symbolRenderingMode(.hierarchical)
            .opacity(model.isSignedIn ? 1 : 0.45)
            .accessibilityLabel(model.isSignedIn ? "VaultBreak, signed in" : "VaultBreak, not signed in")
    }
}
