import AuthenticationServices
import XCTest
@testable import VaultBreak

@MainActor
final class DeviceSignInModelTests: XCTestCase {
    nonisolated private static func code(complete: String? = "https://vault.brainbreaking.com/device?user_code=ABCD-1234") -> DeviceCodeResponse {
        DeviceCodeResponse(
            deviceCode: "dev",
            userCode: "ABCD-1234",
            verificationUri: "https://vault.brainbreaking.com/device",
            verificationUriComplete: complete,
            interval: 1,
            expiresIn: 60
        )
    }

    private final class Recorder: @unchecked Sendable {
        var sessions: [Session] = []
        var urls: [URL] = []
    }

    func testSuccessAppliesProductionSessionAndOpensCompleteURL() async {
        let rec = Recorder()
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeviceSignInModel(
            requestCode: { Self.code() },
            poll: { _ in DeviceTokenResponse(accessToken: "tok", tokenType: "Bearer") },
            authenticator: authenticator
        )
        sut.start { rec.sessions.append($0) }
        await sut.waitUntilFinished()

        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(rec.sessions.count, 1)
        XCTAssertEqual(rec.sessions.first?.token, "tok")
        XCTAssertEqual(rec.sessions.first?.apiUrl, VaultBreakWeb.baseURL.absoluteString)
        XCTAssertEqual(authenticator.startedURLs.first?.absoluteString, "https://vault.brainbreaking.com/device?user_code=ABCD-1234")
    }

    func testFallsBackToVerificationUri() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeviceSignInModel(
            requestCode: { Self.code(complete: nil) },
            poll: { _ in DeviceTokenResponse(accessToken: "t", tokenType: "Bearer") },
            authenticator: authenticator
        )
        sut.start { _ in }
        await sut.waitUntilFinished()
        XCTAssertEqual(authenticator.startedURLs.first?.absoluteString, "https://vault.brainbreaking.com/device")
    }

    func testErrorShowsMessageAndDoesNotApply() async {
        let rec = Recorder()
        let sut = DeviceSignInModel(
            requestCode: { Self.code() },
            poll: { _ in throw DeviceAuthError.accessDenied },
            authenticator: WebAuthenticationStarterStub()
        )
        sut.start { rec.sessions.append($0) }
        await sut.waitUntilFinished()

        XCTAssertTrue(rec.sessions.isEmpty)
        if case .failed = sut.state {} else { XCTFail("expected failed, got \(sut.state)") }
    }

    func testURLErrorCancelledIsSilent() async {
        let rec = Recorder()
        let sut = DeviceSignInModel(
            requestCode: { Self.code() },
            poll: { _ in throw URLError(.cancelled) },
            authenticator: WebAuthenticationStarterStub()
        )
        sut.start { rec.sessions.append($0) }
        await sut.waitUntilFinished()
        XCTAssertEqual(sut.state, .idle)
        XCTAssertTrue(rec.sessions.isEmpty)
    }

    func testCancellationErrorIsSilent() async {
        let sut = DeviceSignInModel(
            requestCode: { throw CancellationError() },
            poll: { _ in throw CancellationError() },
            authenticator: WebAuthenticationStarterStub()
        )
        sut.start { _ in }
        await sut.waitUntilFinished()
        XCTAssertEqual(sut.state, .idle)
    }

    func testCancelWhileWaitingReturnsToIdleWithoutApplying() async {
        let rec = Recorder()
        let sut = DeviceSignInModel(
            requestCode: { Self.code() },
            poll: { _ in
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return DeviceTokenResponse(accessToken: "late", tokenType: "Bearer")
            },
            authenticator: WebAuthenticationStarterStub()
        )
        sut.start { rec.sessions.append($0) }
        let deadline = Date().addingTimeInterval(2)
        while sut.state != .waiting(userCode: "ABCD-1234"), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(sut.state, .waiting(userCode: "ABCD-1234"))
        sut.cancel()
        XCTAssertEqual(sut.state, .idle)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sut.state, .idle)
        XCTAssertTrue(rec.sessions.isEmpty)
    }

    func testDoubleStartIsIgnored() async {
        final class Counter: @unchecked Sendable { var n = 0 }
        let counter = Counter()
        let sut = DeviceSignInModel(
            requestCode: {
                counter.n += 1
                return Self.code()
            },
            poll: { _ in
                try await Task.sleep(nanoseconds: 200_000_000)
                return DeviceTokenResponse(accessToken: "t", tokenType: "Bearer")
            },
            authenticator: WebAuthenticationStarterStub()
        )
        sut.start { _ in }
        sut.start { _ in }
        await sut.waitUntilFinished()
        XCTAssertEqual(counter.n, 1)
    }

    func testApplyFailureSurfacesErrorMessage() async {
        let sut = DeviceSignInModel(
            requestCode: { Self.code() },
            poll: { _ in DeviceTokenResponse(accessToken: "t", tokenType: "Bearer") },
            authenticator: WebAuthenticationStarterStub()
        )
        sut.start { _ in throw URLError(.badURL) }
        await sut.waitUntilFinished()
        if case .failed = sut.state {} else { XCTFail("expected failed") }
    }

    func testValidAuthenticationCallbackKeepsPollingAuthoritative() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeviceSignInModel(
            requestCode: { Self.code() },
            poll: { _ in
                try await Task.sleep(nanoseconds: 100_000_000)
                return DeviceTokenResponse(accessToken: "t", tokenType: "Bearer")
            },
            authenticator: authenticator
        )
        sut.start { _ in }
        while authenticator.completion == nil { await Task.yield() }

        authenticator.completion?(.success(URL(string: "vaultbreak://session-updated?result=approved")!))
        await sut.waitUntilFinished()

        XCTAssertEqual(sut.state, .idle)
    }

    func testDeniedCallbackLeavesPollToReportAccessDenied() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeviceSignInModel(
            requestCode: { Self.code() },
            poll: { _ in
                try await Task.sleep(nanoseconds: 50_000_000)
                throw DeviceAuthError.accessDenied
            },
            authenticator: authenticator
        )
        sut.start { _ in }
        while authenticator.completion == nil { await Task.yield() }

        authenticator.completion?(.success(URL(string: "vaultbreak://session-updated?result=denied")!))
        await sut.waitUntilFinished()

        XCTAssertEqual(sut.state, .failed(message: "Sign-in was denied."))
    }

    func testInvalidAuthenticationCallbackFailsAndStopsPolling() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeviceSignInModel(
            requestCode: { Self.code() },
            poll: { _ in
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return DeviceTokenResponse(accessToken: "t", tokenType: "Bearer")
            },
            authenticator: authenticator
        )
        sut.start { _ in }
        while authenticator.completion == nil { await Task.yield() }

        authenticator.completion?(.success(URL(string: "vaultbreak://session-updated?result=unknown")!))

        if case .failed(let message) = sut.state {
            XCTAssertTrue(message.contains("invalid"))
        } else {
            XCTFail("expected invalid callback failure")
        }
    }

    func testAuthenticationCancellationStopsPollingSilently() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeviceSignInModel(
            requestCode: { Self.code() },
            poll: { _ in
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return DeviceTokenResponse(accessToken: "t", tokenType: "Bearer")
            },
            authenticator: authenticator
        )
        sut.start { _ in }
        while authenticator.completion == nil { await Task.yield() }
        let error = NSError(
            domain: ASWebAuthenticationSessionErrorDomain,
            code: ASWebAuthenticationSessionError.Code.canceledLogin.rawValue
        )

        authenticator.completion?(.failure(error))

        XCTAssertEqual(sut.state, .idle)
    }

    func testAuthenticationErrorStopsPollingWithFailure() async {
        let authenticator = WebAuthenticationStarterStub()
        let sut = DeviceSignInModel(
            requestCode: { Self.code() },
            poll: { _ in
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return DeviceTokenResponse(accessToken: "t", tokenType: "Bearer")
            },
            authenticator: authenticator
        )
        sut.start { _ in }
        while authenticator.completion == nil { await Task.yield() }

        authenticator.completion?(.failure(NSError(domain: "test", code: 1)))

        if case .failed = sut.state {} else { XCTFail("expected failure") }
    }

    func testInvalidVerificationURLFailsWithoutPollingOrStartingSession() async {
        let authenticator = WebAuthenticationStarterStub()
        final class PollRecorder: @unchecked Sendable { var count = 0 }
        let recorder = PollRecorder()
        let sut = DeviceSignInModel(
            requestCode: {
                DeviceCodeResponse(
                    deviceCode: "dev",
                    userCode: "ABCD-1234",
                    verificationUri: "not a url",
                    verificationUriComplete: nil,
                    interval: 1,
                    expiresIn: 60
                )
            },
            poll: { _ in
                recorder.count += 1
                return DeviceTokenResponse(accessToken: "t", tokenType: "Bearer")
            },
            authenticator: authenticator
        )

        sut.start { _ in }
        await sut.waitUntilFinished()

        XCTAssertEqual(recorder.count, 0)
        XCTAssertTrue(authenticator.startedURLs.isEmpty)
        if case .failed = sut.state {} else { XCTFail("expected failure") }
    }
}
