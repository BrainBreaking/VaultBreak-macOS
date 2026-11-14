import AuthenticationServices
import XCTest
@testable import VaultBreak

@MainActor
private final class WebAuthenticationHandleStub: WebAuthenticationCancelling {
    private(set) var cancelCount = 0
    func cancel() { cancelCount += 1 }
}

@MainActor
final class WebAuthenticationStarterStub: WebAuthenticationStarting {
    var startedURLs: [URL] = []
    var callbackSchemes: [String] = []
    var completion: (@MainActor (Result<URL, Error>) -> Void)?
    var startError: Error?
    fileprivate let handle = WebAuthenticationHandleStub()

    func start(
        url: URL,
        callbackScheme: String,
        completion: @escaping @MainActor (Result<URL, Error>) -> Void
    ) throws -> WebAuthenticationCancelling {
        if let startError { throw startError }
        startedURLs.append(url)
        callbackSchemes.append(callbackScheme)
        self.completion = completion
        return handle
    }
}

@MainActor
final class DeleteAccountModelTests: XCTestCase {
    func testStartsAuthorizedDeletionPageWithCallback() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeleteAccountModel(authenticator: authenticator)

        let deletionURL = URL(string: "https://vault.brainbreaking.com/account/delete?authorization=opaque")!
        sut.start(authorizing: { deletionURL }, clearingSession: {})
        await Task.yield()

        XCTAssertEqual(sut.state, .presenting)
        XCTAssertEqual(authenticator.startedURLs, [deletionURL])
        XCTAssertEqual(authenticator.callbackSchemes, ["vaultbreak"])
        XCTAssertTrue(deletionURL.absoluteString.contains("account/delete"))
    }

    func testConfirmedDeletionClearsLocalSession() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeleteAccountModel(authenticator: authenticator)
        var clearCount = 0
        sut.start(
            authorizing: { URL(string: "https://vault.example.com/account/delete")! },
            clearingSession: { clearCount += 1 }
        )
        await Task.yield()

        authenticator.completion?(.success(URL(string: "vaultbreak://account-deleted")!))

        XCTAssertEqual(clearCount, 1)
        XCTAssertEqual(sut.state, .idle)
    }

    func testInvalidCallbackDoesNotClearSession() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeleteAccountModel(authenticator: authenticator)
        var clearCount = 0
        sut.start(
            authorizing: { URL(string: "https://vault.example.com/account/delete")! },
            clearingSession: { clearCount += 1 }
        )
        await Task.yield()

        authenticator.completion?(.success(URL(string: "vaultbreak://session-updated")!))

        XCTAssertEqual(clearCount, 0)
        if case .failed = sut.state {} else { XCTFail("expected failure") }
    }

    func testCallbackWithUnexpectedDataDoesNotClearSession() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeleteAccountModel(authenticator: authenticator)
        var clearCount = 0
        sut.start(
            authorizing: { URL(string: "https://vault.example.com/account/delete")! },
            clearingSession: { clearCount += 1 }
        )
        await Task.yield()

        authenticator.completion?(
            .success(URL(string: "vaultbreak://account-deleted?unexpected=1")!)
        )

        XCTAssertEqual(clearCount, 0)
        if case .failed = sut.state {} else { XCTFail("expected failure") }
    }

    func testCancellationIsSilent() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeleteAccountModel(authenticator: authenticator)
        sut.start(
            authorizing: { URL(string: "https://vault.example.com/account/delete")! },
            clearingSession: {}
        )
        await Task.yield()
        let error = NSError(
            domain: ASWebAuthenticationSessionErrorDomain,
            code: ASWebAuthenticationSessionError.Code.canceledLogin.rawValue
        )

        authenticator.completion?(.failure(error))

        XCTAssertEqual(sut.state, .idle)
    }

    func testSessionErrorIsShown() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeleteAccountModel(authenticator: authenticator)
        sut.start(
            authorizing: { URL(string: "https://vault.example.com/account/delete")! },
            clearingSession: {}
        )
        await Task.yield()

        authenticator.completion?(.failure(NSError(domain: "test", code: 1)))

        if case .failed = sut.state {} else { XCTFail("expected failure") }
    }

    func testStartErrorIsShown() async {
        let authenticator = WebAuthenticationStarterStub()
        authenticator.startError = NSError(domain: "test", code: 1)
        let sut = DeleteAccountModel(authenticator: authenticator)

        sut.start(
            authorizing: { URL(string: "https://vault.example.com/account/delete")! },
            clearingSession: {}
        )
        await Task.yield()

        if case .failed = sut.state {} else { XCTFail("expected failure") }
    }

    func testConfirmedDeletionReportsLocalClearFailure() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeleteAccountModel(authenticator: authenticator)
        sut.start(
            authorizing: { URL(string: "https://vault.example.com/account/delete")! },
            clearingSession: { throw NSError(domain: "keychain", code: 1) }
        )
        await Task.yield()

        authenticator.completion?(.success(URL(string: "vaultbreak://account-deleted")!))

        if case .failed(let message) = sut.state {
            XCTAssertTrue(message.contains("local session"))
        } else {
            XCTFail("expected local clear failure")
        }
    }

    func testAuthorizationFailureDoesNotPresentWebSession() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeleteAccountModel(authenticator: authenticator)

        sut.start(
            authorizing: { throw URLError(.userAuthenticationRequired) },
            clearingSession: {}
        )
        await Task.yield()

        XCTAssertTrue(authenticator.startedURLs.isEmpty)
        if case .failed = sut.state {} else { XCTFail("expected failure") }
    }
}
