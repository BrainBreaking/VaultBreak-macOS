import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: PopoverSecretsViewModel
    @ObservedObject var lockState: VaultLockState
    @ObservedObject var handoffModel: HandoffAttentionModel
    let onOpenVault: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            handoffsSection
            if lockState.isLocked {
                lockedContent
            } else {
                secretsContent
            }
        }
        .padding(12)
        .task(id: lockState.isLocked) {
            guard !lockState.isLocked else { return }
            await viewModel.loadSecrets()
        }
    }

    @ViewBuilder
    private var handoffsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Handoffs")
                    .font(.headline)
                Text("\(handoffModel.pendingHandoffs.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15), in: Capsule())
                Spacer()
                if !handoffModel.pendingHandoffs.isEmpty {
                    Button("Review All…") {
                        handoffModel.openHandoffsInBrowser()
                    }
                }
            }
            if let error = handoffModel.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if handoffModel.pendingHandoffs.isEmpty {
                Text("No pending handoffs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(handoffModel.pendingHandoffs) { handoff in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(handoff.title)
                                .lineLimit(2)
                            Text(handoff.status)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Button("Revoke") {
                            Task { await handoffModel.revokeHandoff(id: handoff.id) }
                        }
                    }
                }
            }
        }
        Divider()
    }

    @ViewBuilder
    private var lockedContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Vault is locked")
                .font(.headline)
            Text(
                lockState.canUseDeviceOwnerAuthentication
                    ? "Unlock with Touch ID or your Mac password."
                    : "Unlock with your Mac password."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            if lockState.isUnlocking {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Unlocking…")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(BrainBreakingTheme.muted)
                .frame(minWidth: 140, minHeight: 32)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Unlocking vault")
            } else {
                Button {
                    Task { await lockState.unlock() }
                } label: {
                    Label("Unlock Vault", systemImage: "lock.open.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(BrainBreakingTheme.accent)
                .keyboardShortcut(.defaultAction)
                .accessibilityHint("Authenticates with Touch ID or your Mac password")
            }
            if let unlockError = lockState.unlockError {
                Text(unlockError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(minWidth: 280, minHeight: 160)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var secretsContent: some View {
        TextField("Search secrets", text: $viewModel.searchText)
            .textFieldStyle(.roundedBorder)

        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let loadError = viewModel.loadError {
            Text(loadError)
                .foregroundStyle(.secondary)
                .font(.caption)
        }

        if let copyError = viewModel.copyError {
            Text(copyError)
                .foregroundStyle(.red)
                .font(.caption)
        }

        List(viewModel.filteredSecrets) { item in
            HStack {
                Text(item.name)
                    .lineLimit(1)
                Spacer()
                Button {
                    Task { await viewModel.copySecret(id: item.id) }
                } label: {
                    Label(
                        viewModel.copiedSecretID == item.id ? "Copied" : "Copy",
                        systemImage: viewModel.copiedSecretID == item.id
                            ? "checkmark.circle.fill"
                            : "doc.on.doc"
                    )
                    .font(.caption.weight(.medium))
                    .frame(minWidth: 58)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(
                    viewModel.copiedSecretID == item.id
                        ? Color.green
                        : BrainBreakingTheme.sand
                )
                .disabled(viewModel.isLoading)
                .accessibilityLabel(
                    viewModel.copiedSecretID == item.id
                        ? "Secret copied"
                        : "Copy \(item.name)"
                )
            }
        }
        .listStyle(.plain)
        .frame(minWidth: 280, minHeight: 160, maxHeight: 320)

        HStack {
            Button {
                onOpenVault()
            } label: {
                Label("Open in Window", systemImage: "macwindow")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(BrainBreakingTheme.accent)
            .accessibilityHint("Opens the vault in a larger window")
            Spacer()
            Button("Lock Vault", systemImage: "lock.fill") {
                lockState.lock()
                viewModel.clearLoadedSecrets()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(BrainBreakingTheme.muted)
            .accessibilityHint("Immediately locks access to secrets")
        }
    }
}
