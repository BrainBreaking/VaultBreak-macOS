import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: PopoverSecretsViewModel
    @ObservedObject var lockState: VaultLockState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
