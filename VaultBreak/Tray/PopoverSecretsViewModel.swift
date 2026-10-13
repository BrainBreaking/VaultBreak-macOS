import Foundation

@MainActor
final class PopoverSecretsViewModel: ObservableObject {
    @Published private(set) var secrets: [SecretMetadata] = []
    @Published var searchText: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?
    @Published private(set) var copyError: String?
    @Published private(set) var copiedSecretID: String?

    private let clientFactory: () throws -> any SecretsAPIClient
    private let clipboard: ClipboardClearService
    private var copiedIndicatorTask: Task<Void, Never>?

    var filteredSecrets: [SecretMetadata] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return secrets }
        return secrets.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    init(
        clientFactory: @escaping () throws -> any SecretsAPIClient,
        clipboard: ClipboardClearService = ClipboardClearService()
    ) {
        self.clientFactory = clientFactory
        self.clipboard = clipboard
    }

    convenience init(sessionModel: AppSessionModel, clipboard: ClipboardClearService = ClipboardClearService()) {
        self.init(clientFactory: { try sessionModel.makeAPIClient() }, clipboard: clipboard)
    }

    func loadSecrets() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let client = try clientFactory()
            secrets = try await client.listSecrets()
        } catch APIClientError.unauthorized {
            secrets = []
            loadError = "Session expired — sign in again"
        } catch {
            secrets = []
            loadError = "Could not load secrets"
        }
    }

    func copySecret(id: String) async {
        copyError = nil
        copiedIndicatorTask?.cancel()

        do {
            let client = try clientFactory()
            let secret = try await client.getSecret(id: id)
            clipboard.copyWithTimedClear(secret.value)
            copiedSecretID = id
            copiedIndicatorTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if !Task.isCancelled, copiedSecretID == id {
                    copiedSecretID = nil
                }
            }
        } catch APIClientError.unauthorized {
            copyError = "Session expired — sign in again"
        } catch {
            copyError = "Copy failed"
        }
    }
}
