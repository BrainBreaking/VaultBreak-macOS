import Foundation

@MainActor
final class ConsoleSecretsViewModel: ObservableObject {
    @Published private(set) var secrets: [SecretMetadata] = []
    @Published private(set) var loadError: String?
    @Published private(set) var isLoading = false
    @Published var actionError: String?
    @Published var isSaving = false

    private let clientFactory: () -> SecretsAPIClient?

    init(clientFactory: @escaping () -> SecretsAPIClient?) {
        self.clientFactory = clientFactory
    }

    func loadSecrets() async {
        guard let client = clientFactory() else {
            loadError = "Not signed in"
            secrets = []
            return
        }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            secrets = try await client.listSecrets()
        } catch APIClientError.unauthorized {
            loadError = "Session expired — sign in again"
            secrets = []
        } catch {
            loadError = error.localizedDescription
        }
    }

    func createSecret(name: String, value: String) async -> Bool {
        guard let client = clientFactory() else {
            actionError = "Not signed in"
            return false
        }
        isSaving = true
        actionError = nil
        defer { isSaving = false }
        do {
            _ = try await client.createSecret(name: name, value: value)
            await loadSecrets()
            return true
        } catch APIClientError.conflict {
            actionError = "A secret with that name already exists"
            return false
        } catch APIClientError.unauthorized {
            actionError = "Session expired — sign in again"
            return false
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    func updateSecret(id: String, value: String) async -> Bool {
        guard let client = clientFactory() else {
            actionError = "Not signed in"
            return false
        }
        isSaving = true
        actionError = nil
        defer { isSaving = false }
        do {
            _ = try await client.updateSecret(id: id, value: value)
            await loadSecrets()
            return true
        } catch APIClientError.unauthorized {
            actionError = "Session expired — sign in again"
            return false
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    func deleteSecret(id: String) async -> Bool {
        guard let client = clientFactory() else {
            actionError = "Not signed in"
            return false
        }
        isSaving = true
        actionError = nil
        defer { isSaving = false }
        do {
            try await client.deleteSecret(id: id)
            await loadSecrets()
            return true
        } catch APIClientError.unauthorized {
            actionError = "Session expired — sign in again"
            return false
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }
}
