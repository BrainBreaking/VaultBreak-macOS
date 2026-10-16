import XCTest
@testable import VaultBreak

private final class MockLocalAuthentication: LocalAuthenticationEvaluating {
    var canEvaluate = true
    var evaluateResult: Result<Bool, Error> = .success(true)
    private(set) var lastReason: String?

    func canEvaluateDeviceOwnerAuthentication() -> Bool {
        canEvaluate
    }

    func evaluateDeviceOwnerAuthentication(reason: String) async throws -> Bool {
        lastReason = reason
        return try evaluateResult.get()
    }
}

@MainActor
final class VaultLockStateTests: XCTestCase {
    func testStartsLocked() {
        let lock = VaultLockState(authenticator: MockLocalAuthentication())
        XCTAssertTrue(lock.isLocked)
    }

    func testLockSetsLockedState() async {
        let auth = MockLocalAuthentication()
        let lock = VaultLockState(authenticator: auth)
        await lock.unlock()
        XCTAssertFalse(lock.isLocked)

        lock.lock()
        XCTAssertTrue(lock.isLocked)
        XCTAssertNil(lock.unlockError)
    }

    func testUnlockSuccessClearsLocked() async {
        let auth = MockLocalAuthentication()
        auth.evaluateResult = .success(true)
        let lock = VaultLockState(authenticator: auth)

        await lock.unlock()

        XCTAssertFalse(lock.isLocked)
        XCTAssertNil(lock.unlockError)
        XCTAssertNotNil(auth.lastReason)
    }

    func testUnlockFailureStaysLocked() async {
        struct FakeAuthError: Error {}
        let auth = MockLocalAuthentication()
        auth.evaluateResult = .failure(FakeAuthError())
        let lock = VaultLockState(authenticator: auth)

        await lock.unlock()

        XCTAssertTrue(lock.isLocked)
        XCTAssertEqual(lock.unlockError, "Unlock failed")
    }

    func testUnlockDeniedStaysLocked() async {
        let auth = MockLocalAuthentication()
        auth.evaluateResult = .success(false)
        let lock = VaultLockState(authenticator: auth)

        await lock.unlock()

        XCTAssertTrue(lock.isLocked)
        XCTAssertEqual(lock.unlockError, "Unlock failed")
    }

    func testCanUseDeviceOwnerAuthenticationReflectsMock() {
        let auth = MockLocalAuthentication()
        auth.canEvaluate = false
        let lock = VaultLockState(authenticator: auth)
        XCTAssertFalse(lock.canUseDeviceOwnerAuthentication)

        auth.canEvaluate = true
        XCTAssertTrue(lock.canUseDeviceOwnerAuthentication)
    }
}
