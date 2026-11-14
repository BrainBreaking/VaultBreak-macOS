import Foundation
import AuthenticationServices

/// Drives the tray "Sign in…" device-authorization flow.
@MainActor
final class DeviceSignInModel: ObservableObject {
    enum State: Equatable {
        case idle
        case starting
        case waiting(userCode: String)
        case failed(message: String)
    }

    @Published private(set) var state: State = .idle

    private let requestCode: @Sendable () async throws -> DeviceCodeResponse
    private let poll: @Sendable (DeviceCodeResponse) async throws -> DeviceTokenResponse
    private let authenticator: WebAuthenticationStarting
    private let apiUrl: String
    private var task: Task<Void, Never>?
    private var authentication: WebAuthenticationCancelling?
    private var generation = 0

    var isBusy: Bool {
        switch state {
        case .starting, .waiting: return true
        case .idle, .failed: return false
        }
    }

    init(
        client: DeviceAuthClient = DeviceAuthClient(),
        apiUrl: String = VaultBreakWeb.baseURL.absoluteString,
        authenticator: WebAuthenticationStarting? = nil
    ) {
        self.requestCode = { try await client.requestDeviceCode() }
        self.poll = { try await client.pollForToken(code: $0) }
        self.apiUrl = apiUrl
        self.authenticator = authenticator ?? WebAuthenticationSessionPresenter()
    }

    init(
        requestCode: @escaping @Sendable () async throws -> DeviceCodeResponse,
        poll: @escaping @Sendable (DeviceCodeResponse) async throws -> DeviceTokenResponse,
        apiUrl: String = VaultBreakWeb.baseURL.absoluteString,
        authenticator: WebAuthenticationStarting
    ) {
        self.requestCode = requestCode
        self.poll = poll
        self.apiUrl = apiUrl
        self.authenticator = authenticator
    }

    /// Starts the flow; ignored while a flow is already running.
    func start(applying apply: @escaping @MainActor (Session) throws -> Void) {
        guard !isBusy else { return }
        state = .starting
        generation += 1
        let gen = generation
        task = Task { [weak self] in
            await self?.run(generation: gen, apply: apply)
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

    /// Awaitable for tests.
    func waitUntilFinished() async {
        await task?.value
    }

    private func run(generation gen: Int, apply: @MainActor (Session) throws -> Void) async {
        do {
            let code = try await requestCode()
            try Task.checkCancellation()
            guard gen == generation else { return }
            state = .waiting(userCode: code.userCode)
            let target = code.verificationUriComplete ?? code.verificationUri
            guard let url = URL(string: target), url.scheme?.lowercased() == "https" else {
                throw WebAuthenticationSessionStartError.couldNotStart
            }
            authentication = try authenticator.start(
                url: url,
                callbackScheme: VaultBreakURLParser.callbackScheme
            ) { [weak self] result in
                self?.handleAuthenticationResult(result, generation: gen)
            }
            let token = try await poll(code)
            try Task.checkCancellation()
            guard gen == generation else { return }
            let session = Session(apiUrl: apiUrl, token: token.accessToken, updatedAt: Date())
            try apply(session)
            state = .idle
            authentication?.cancel()
            authentication = nil
        } catch is CancellationError {
            finishCancelled(gen)
        } catch let error as URLError where error.code == .cancelled {
            finishCancelled(gen)
        } catch {
            if Task.isCancelled {
                finishCancelled(gen)
            } else if gen == generation {
                state = .failed(message: Self.message(for: error))
                authentication?.cancel()
                authentication = nil
            }
        }
        if gen == generation { task = nil }
    }

    private func finishCancelled(_ gen: Int) {
        if gen == generation {
            authentication?.cancel()
            authentication = nil
            state = .idle
        }
    }

    private func handleAuthenticationResult(_ result: Result<URL, Error>, generation gen: Int) {
        guard gen == generation, isBusy else { return }
        switch result {
        case .success(let callback):
            guard VaultBreakURLParser.authenticationResult(for: callback) != nil else {
                failAuthentication(message: "The sign-in callback was invalid.")
                return
            }
            // Device-code polling remains authoritative for the access token.
        case .failure(let error) where Self.isAuthenticationCancellation(error):
            cancel()
        case .failure:
            failAuthentication(message: "The secure sign-in session failed. Try again.")
        }
    }

    private func failAuthentication(message: String) {
        generation += 1
        task?.cancel()
        task = nil
        authentication?.cancel()
        authentication = nil
        state = .failed(message: message)
    }

    private static func isAuthenticationCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == ASWebAuthenticationSessionErrorDomain
            && error.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue
    }

    static func message(for error: Error) -> String {
        switch error {
        case DeviceAuthError.accessDenied:
            return "Sign-in was denied."
        case DeviceAuthError.expired:
            return "The code expired. Try again."
        case DeviceAuthError.http(_, let message):
            return message ?? "Sign-in failed. Try again."
        case is KeychainSessionError:
            return "Could not save the session to Keychain."
        case is URLError:
            return "Network error. Check your connection and try again."
        default:
            return "Sign-in failed. Try again."
        }
    }
}
