import SwiftUI

/// Brain Breaking brand tokens shared by tray popover and mini-console.
enum BrainBreakingTheme {
    static let ink = Color(red: 10 / 255, green: 10 / 255, blue: 8 / 255)
    static let surface = Color(red: 18 / 255, green: 18 / 255, blue: 16 / 255)
    static let sand = Color(red: 247 / 255, green: 246 / 255, blue: 242 / 255)
    /// Secondary labels on ink — kept brighter than mid-gray so MenuBarExtra stays readable.
    static let muted = Color(red: 168 / 255, green: 168 / 255, blue: 158 / 255)
    static let accent = Color(red: 217 / 255, green: 59 / 255, blue: 45 / 255)
    static let accentHover = Color(red: 232 / 255, green: 71 / 255, blue: 42 / 255)
    static let border = sand.opacity(0.12)
    static let rowHeight: CGFloat = 30
}

/// Single Lock switch — ON = unlocked, OFF = locked (no separate Lock/Unlock buttons).
struct VaultLockSwitch: View {
    @ObservedObject var lockState: VaultLockState
    var onDidLock: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Text(lockState.isLocked ? "Vault locked" : "Vault unlocked")
                .font(.caption.weight(.medium))
                .foregroundStyle(lockState.isLocked ? BrainBreakingTheme.muted : BrainBreakingTheme.sand)
            Toggle(
                "",
                isOn: Binding(
                    get: { !lockState.isLocked },
                    set: { wantUnlocked in
                        if wantUnlocked {
                            Task { await lockState.unlock() }
                        } else {
                            lockState.lock()
                            onDidLock?()
                        }
                    }
                )
            )
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
            .disabled(lockState.isUnlocking)
            .tint(BrainBreakingTheme.accent)
            if lockState.isUnlocking {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lockState.isLocked ? "Vault locked" : "Vault unlocked")
        .accessibilityHint("Toggle to lock or unlock the vault")
    }
}
