import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppSessionModel

    var body: some View {
        Group {
            if model.isSignedIn {
                if let label = model.accountLabel {
                    Text(label)
                }
                Button("Open Vault…") {
                    openVaultPlaceholder()
                }
                .disabled(true)
            } else {
                Text("Not signed in — run vaultbreak login")
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func openVaultPlaceholder() {
        // M5: open popover / main UI
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
