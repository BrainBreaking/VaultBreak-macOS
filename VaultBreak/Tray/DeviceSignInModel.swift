import Foundation

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
    private let openURL: (URL) -> Void
    private let apiUrl: String
    private var task: Task<Void, Never>?
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
        openURL: @escaping (URL) -> Void
    ) {
        self.requestCode = { try await client.requestDeviceCode() }
        self.poll = { try await client.pollForToken(code: $0) }
        self.apiUrl = apiUrl
        self.openURL = openURL
    }

    init(
        requestCode: @escaping @Sendable () async throws -> DeviceCodeResponse,
        poll: @escaping @Sendable (DeviceCodeResponse) async throws -> DeviceTokenResponse,
        apiUrl: String = VaultBreakWeb.baseURL.absoluteString,
        openURL: @escaping (URL) -> Void
    ) {
        self.requestCode = requestCode
        self.poll = poll
        self.apiUrl = apiUrl
        self.openURL = openURL
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
            if let url = URL(string: target) {
                openURL(url)
            }
            let token = try await poll(code)
            try Task.checkCancellation()
            guard gen == generation else { return }
            let session = Session(apiUrl: apiUrl, token: token.accessToken, updatedAt: Date())
            try apply(session)
            state = .idle
        } catch is CancellationError {
            finishCancelled(gen)
        } catch let error as URLError where error.code == .cancelled {
            finishCancelled(gen)
        } catch {
            if Task.isCancelled {
                finishCancelled(gen)
            } else if gen == generation {
                state = .failed(message: Self.message(for: error))
            }
        }
        if gen == generation { task = nil }
    }

    private func finishCancelled(_ gen: Int) {
        if gen == generation { state = .idle }
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
