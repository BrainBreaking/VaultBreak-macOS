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
        let sut = DeviceSignInModel(
            requestCode: { Self.code() },
            poll: { _ in DeviceTokenResponse(accessToken: "tok", tokenType: "Bearer") },
            openURL: { rec.urls.append($0) }
        )
        sut.start { rec.sessions.append($0) }
        await sut.waitUntilFinished()

        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(rec.sessions.count, 1)
        XCTAssertEqual(rec.sessions.first?.token, "tok")
        XCTAssertEqual(rec.sessions.first?.apiUrl, VaultBreakWeb.baseURL.absoluteString)
        XCTAssertEqual(rec.urls.first?.absoluteString, "https://vault.brainbreaking.com/device?user_code=ABCD-1234")
    }

    func testFallsBackToVerificationUri() async {
        let rec = Recorder()
        let sut = DeviceSignInModel(
            requestCode: { Self.code(complete: nil) },
            poll: { _ in DeviceTokenResponse(accessToken: "t", tokenType: "Bearer") },
            openURL: { rec.urls.append($0) }
        )
        sut.start { _ in }
        await sut.waitUntilFinished()
        XCTAssertEqual(rec.urls.first?.absoluteString, "https://vault.brainbreaking.com/device")
    }

    func testErrorShowsMessageAndDoesNotApply() async {
        let rec = Recorder()
        let sut = DeviceSignInModel(
            requestCode: { Self.code() },
            poll: { _ in throw DeviceAuthError.accessDenied },
            openURL: { _ in }
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
            openURL: { _ in }
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
            openURL: { _ in }
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
            openURL: { _ in }
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
            openURL: { _ in }
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
            openURL: { _ in }
        )
        sut.start { _ in throw URLError(.badURL) }
        await sut.waitUntilFinished()
        if case .failed = sut.state {} else { XCTFail("expected failed") }
    }

    func testInvalidVerificationURLFailsWithoutPolling() async {
        let rec = Recorder()
        var polled = false
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
                polled = true
                return DeviceTokenResponse(accessToken: "t", tokenType: "Bearer")
            },
            openURL: { rec.urls.append($0) }
        )
        sut.start { rec.sessions.append($0) }
        await sut.waitUntilFinished()
        XCTAssertFalse(polled)
        XCTAssertTrue(rec.urls.isEmpty)
        XCTAssertTrue(rec.sessions.isEmpty)
        if case .failed(let message) = sut.state {
            XCTAssertTrue(message.contains("Invalid sign-in URL"))
        } else {
            XCTFail("expected failed, got \(sut.state)")
        }
    }
}
