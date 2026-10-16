import SwiftUI

struct SecretsListView: View {
    @ObservedObject var viewModel: ConsoleSecretsViewModel
    @ObservedObject var lockState: VaultLockState

    @State private var showCreateSheet = false
    @State private var secretToEdit: SecretMetadata?
    @State private var secretToDelete: SecretMetadata?

    var body: some View {
        Group {
            if lockState.isLocked {
                lockedContent
            } else {
                unlockedContent
            }
        }
        .frame(minWidth: 400, minHeight: 280)
        .task(id: lockState.isLocked) {
            guard !lockState.isLocked else { return }
            await viewModel.loadSecrets()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateSecretSheet(viewModel: viewModel, isPresented: $showCreateSheet)
        }
        .sheet(item: $secretToEdit) { secret in
            EditSecretSheet(secret: secret, viewModel: viewModel, onDismiss: { secretToEdit = nil })
        }
        .alert(
            "Delete secret?",
            isPresented: Binding(
                get: { secretToDelete != nil },
                set: { if !$0 { secretToDelete = nil } }
            ),
            presenting: secretToDelete
        ) { secret in
            Button("Delete", role: .destructive) {
                Task {
                    _ = await viewModel.deleteSecret(id: secret.id)
                    secretToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                secretToDelete = nil
            }
        } message: { secret in
            Text("Remove “\(secret.name)” from the vault? This cannot be undone.")
        }
    }

    @ViewBuilder
    private var lockedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Unlock the vault to manage secrets")
                .font(.headline)
            if lockState.isUnlocking {
                ProgressView()
            } else {
                Button("Unlock") {
                    Task { await lockState.unlock() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var unlockedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Secrets")
                    .font(.title2.bold())
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Label("New Secret", systemImage: "plus")
                }
                .disabled(viewModel.isSaving)
            }

            if let loadError = viewModel.loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let actionError = viewModel.actionError {
                Text(actionError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if viewModel.isLoading && viewModel.secrets.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.secrets.isEmpty {
                Text("No secrets yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(viewModel.secrets) {
                    TableColumn("Name") { secret in
                        Text(secret.name)
                    }
                    TableColumn("Updated") { secret in
                        Text(secret.updatedAt, style: .date)
                            .font(.caption)
                    }
                    TableColumn("") { secret in
                        HStack {
                            Button("Edit") {
                                secretToEdit = secret
                            }
                            .disabled(viewModel.isSaving)
                            Button("Delete", role: .destructive) {
                                secretToDelete = secret
                            }
                            .disabled(viewModel.isSaving)
                        }
                    }
                    .width(120)
                }
            }
        }
        .padding()
    }
}

private struct CreateSecretSheet: View {
    @ObservedObject var viewModel: ConsoleSecretsViewModel
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var value = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New secret")
                .font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
            SecureField("Value", text: $value)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Create") {
                    Task {
                        let ok = await viewModel.createSecret(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            value: value
                        )
                        if ok {
                            isPresented = false
                            name = ""
                            value = ""
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || value.isEmpty
                        || viewModel.isSaving
                )
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear { nameFocused = true }
    }
}

private struct EditSecretSheet: View {
    let secret: SecretMetadata
    @ObservedObject var viewModel: ConsoleSecretsViewModel
    var onDismiss: () -> Void
    @State private var value = ""
    @FocusState private var valueFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit “\(secret.name)”")
                .font(.headline)
            SecureField("New value", text: $value)
                .textFieldStyle(.roundedBorder)
                .focused($valueFocused)
            HStack {
                Spacer()
                Button("Cancel", action: onDismiss)
                Button("Save") {
                    Task {
                        let ok = await viewModel.updateSecret(id: secret.id, value: value)
                        if ok { onDismiss() }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(value.isEmpty || viewModel.isSaving)
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear { valueFocused = true }
    }
}
