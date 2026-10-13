import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: PopoverSecretsViewModel
    @ObservedObject var lockState: VaultLockState
    @ObservedObject var handoffModel: HandoffAttentionModel

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
                Text("Pending handoffs")
                    .font(.headline)
                Spacer()
                Button("Open") {
                    handoffModel.openHandoffsInBrowser()
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
            if lockState.isUnlocking {
                ProgressView()
            } else {
                Button("Unlock") {
                    Task { await lockState.unlock() }
                }
                .keyboardShortcut(.defaultAction)
                if !lockState.canUseDeviceOwnerAuthentication {
                    Text("Device password will be requested if biometry is unavailable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
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
                if viewModel.copiedSecretID == item.id {
                    Text("Copied")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Copy") {
                    Task { await viewModel.copySecret(id: item.id) }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .listStyle(.plain)
        .frame(minWidth: 280, minHeight: 160, maxHeight: 320)
    }
}
