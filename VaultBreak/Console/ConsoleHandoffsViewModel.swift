import AppKit
import Foundation

@MainActor
final class ConsoleHandoffsViewModel: ObservableObject {
    @Published private(set) var handoffs: [Handoff] = []
    @Published private(set) var loadError: String?
    @Published private(set) var isLoading = false
    @Published var actionError: String?

    private let clientFactory: () -> (any HandoffsAPIClient)?

    init(clientFactory: @escaping () -> (any HandoffsAPIClient)?) {
        self.clientFactory = clientFactory
    }

    func loadHandoffs() async {
        guard let client = clientFactory() else {
            loadError = "Not signed in"
            handoffs = []
            return
        }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let list = try await client.listHandoffs()
            handoffs = list.sorted { $0.expiresAt < $1.expiresAt }
        } catch APIClientError.unauthorized {
            loadError = "Session expired — sign in again"
            handoffs = []
        } catch {
            loadError = error.localizedDescription
        }
    }

    func revokeHandoff(id: String) async {
        guard let client = clientFactory() else {
            actionError = "Not signed in"
            return
        }
        actionError = nil
        do {
            _ = try await client.revokeHandoff(id: id)
            await loadHandoffs()
        } catch APIClientError.unauthorized {
            actionError = "Session expired — sign in again"
        } catch {
            actionError = "Revoke failed"
        }
    }

    func openHandoffsInBrowser() {
        NSWorkspace.shared.open(HandoffAttention.handoffsWebURL)
    }

    func isPending(_ handoff: Handoff) -> Bool {
        handoff.status == HandoffAttention.pendingStatus
    }
}
