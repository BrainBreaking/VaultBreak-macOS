import SwiftUI

@main
struct VaultBreakApp: App {
    var body: some Scene {
        MenuBarExtra("VaultBreak", systemImage: "lock.shield") {
            MenuBarPlaceholderView()
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VaultBreak")
                .font(.headline)
            Text("Signed out")
                .foregroundStyle(.secondary)
            Text("Run `vaultbreak login` in Terminal to connect.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(minWidth: 220)
    }
}
