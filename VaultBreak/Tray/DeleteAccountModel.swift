import AuthenticationServices
import Foundation

@MainActor
final class DeleteAccountModel: ObservableObject {
    enum State: Equatable {
        case idle
        case authorizing
        case presenting
        case failed(message: String)
    }

    @Published private(set) var state: State = .idle

    private let authenticator: WebAuthenticationStarting
    private var authentication: WebAuthenticationCancelling?
    private var task: Task<Void, Never>?
    private var generation = 0

    init(authenticator: WebAuthenticationStarting? = nil) {
        self.authenticator = authenticator ?? WebAuthenticationSessionPresenter()
    }

    func start(
        authorizing: @escaping @MainActor () async throws -> URL,
        clearingSession: @escaping @MainActor () throws -> Void
    ) {
        guard state != .authorizing, state != .presenting else { return }
        generation += 1
        let currentGeneration = generation
        state = .authorizing
        task = Task { [weak self] in
            do {
                let url = try await authorizing()
                try Task.checkCancellation()
                guard let self,
                      currentGeneration == self.generation,
                      url.scheme?.lowercased() == "https"
                else { return }
                self.state = .presenting
                self.authentication = try self.authenticator.start(
                    url: url,
                    callbackScheme: VaultBreakURLParser.callbackScheme
                ) { [weak self] result in
                    self?.complete(
                        result,
                        generation: currentGeneration,
                        clearingSession: clearingSession
                    )
                }
            } catch is CancellationError {
                if currentGeneration == self?.generation { self?.state = .idle }
            } catch {
                if currentGeneration == self?.generation {
                    self?.state = .failed(
                        message: "Could not authorize account deletion. Sign in again and retry."
                    )
                }
            }
            if currentGeneration == self?.generation { self?.task = nil }
        }
    }

    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        authentication?.cancel()
        authentication = nil
        state = .idle
    }

    private func complete(
        _ result: Result<URL, Error>,
        generation currentGeneration: Int,
        clearingSession: @MainActor () throws -> Void
    ) {
        guard currentGeneration == generation, state == .presenting else { return }
        authentication = nil
        switch result {
        case .success(let callback):
            guard VaultBreakURLParser.isExactAccountDeletedCallback(callback) else {
                state = .failed(message: "The account deletion confirmation was invalid.")
                return
            }
            do {
                try clearingSession()
                state = .idle
            } catch {
                state = .failed(
                    message: "Your account was deleted, but the local session could not be removed. Sign out manually."
                )
            }
        case .failure(let error) where Self.isAuthenticationCancellation(error):
            state = .idle
        case .failure:
            state = .failed(message: "The secure account deletion session failed. Try again.")
        }
    }

    private static func isAuthenticationCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == ASWebAuthenticationSessionErrorDomain
            && error.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue
    }
}
