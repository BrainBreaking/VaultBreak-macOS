import XCTest
@testable import VaultBreak

private final class LoginItemPreferencesStub: LoginItemPreferences {
    var values: [String: Any] = [:]

    func object(forKey key: String) -> Any? { values[key] }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}

private final class LoginItemRegistrationStub: LoginItemRegistering {
    var registrationStatus: LoginItemRegistrationStatus = .notRegistered
    var registerCount = 0
    var unregisterCount = 0
    var error: Error?

    func register() throws {
        registerCount += 1
        if let error { throw error }
        registrationStatus = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        if let error { throw error }
        registrationStatus = .notRegistered
    }
}

@MainActor
final class LoginItemServiceTests: XCTestCase {
    func testFreshInstallDefaultsOffWithoutRegistering() {
        let preferences = LoginItemPreferencesStub()
        let registration = LoginItemRegistrationStub()
        let sut = LoginItemController(preferences: preferences, registration: registration)

        sut.applyConsentMigrationIfNeeded()

        XCTAssertFalse(sut.isEnabled)
        XCTAssertEqual(registration.registerCount, 0)
        XCTAssertEqual(registration.unregisterCount, 0)
    }

    func testLegacyImplicitEnabledRegistrationIsMigratedOff() {
        let preferences = LoginItemPreferencesStub()
        preferences.values[LoginItemController.enabledKey] = true
        let registration = LoginItemRegistrationStub()
        registration.registrationStatus = .enabled
        let sut = LoginItemController(preferences: preferences, registration: registration)

        sut.applyConsentMigrationIfNeeded()

        XCTAssertFalse(sut.isEnabled)
        XCTAssertEqual(registration.unregisterCount, 1)
    }

    func testExplicitEnableRegistersAndPersistsConsent() {
        let preferences = LoginItemPreferencesStub()
        let registration = LoginItemRegistrationStub()
        let sut = LoginItemController(preferences: preferences, registration: registration)

        XCTAssertTrue(sut.setEnabled(true))

        XCTAssertTrue(sut.isEnabled)
        XCTAssertEqual(registration.registerCount, 1)
        XCTAssertEqual(preferences.values[LoginItemController.consentKey] as? Bool, true)
    }

    func testExplicitEnableAttemptsRegistrationWhenServiceHasNoRecord() {
        let preferences = LoginItemPreferencesStub()
        let registration = LoginItemRegistrationStub()
        registration.registrationStatus = .notFound
        let sut = LoginItemController(preferences: preferences, registration: registration)

        XCTAssertTrue(sut.setEnabled(true))

        XCTAssertTrue(sut.isEnabled)
        XCTAssertEqual(registration.registerCount, 1)
        XCTAssertEqual(preferences.values[LoginItemController.consentKey] as? Bool, true)
    }

    func testExplicitDisableUnregisters() {
        let preferences = LoginItemPreferencesStub()
        preferences.values[LoginItemController.consentKey] = true
        preferences.values[LoginItemController.enabledKey] = true
        let registration = LoginItemRegistrationStub()
        registration.registrationStatus = .enabled
        let sut = LoginItemController(preferences: preferences, registration: registration)

        XCTAssertTrue(sut.setEnabled(false))

        XCTAssertFalse(sut.isEnabled)
        XCTAssertEqual(registration.unregisterCount, 1)
    }

    func testRequiresApprovalRemainsEnabledWithoutDuplicateRegistration() {
        let preferences = LoginItemPreferencesStub()
        let registration = LoginItemRegistrationStub()
        registration.registrationStatus = .requiresApproval
        let sut = LoginItemController(preferences: preferences, registration: registration)

        XCTAssertTrue(sut.setEnabled(true))

        XCTAssertTrue(sut.isEnabled)
        XCTAssertEqual(registration.registerCount, 0)
    }

    func testRegistrationFailureRollsToggleBack() {
        let preferences = LoginItemPreferencesStub()
        let registration = LoginItemRegistrationStub()
        registration.error = NSError(domain: "test", code: 1)
        let sut = LoginItemController(preferences: preferences, registration: registration)

        XCTAssertFalse(sut.setEnabled(true))

        XCTAssertFalse(sut.isEnabled)
        XCTAssertEqual(registration.registerCount, 1)
    }

    func testSubsequentLaunchPreservesExplicitEnable() {
        let preferences = LoginItemPreferencesStub()
        preferences.values[LoginItemController.consentKey] = true
        preferences.values[LoginItemController.enabledKey] = true
        let registration = LoginItemRegistrationStub()
        registration.registrationStatus = .enabled
        let sut = LoginItemController(preferences: preferences, registration: registration)

        sut.applyConsentMigrationIfNeeded()

        XCTAssertTrue(sut.isEnabled)
        XCTAssertEqual(registration.registerCount, 0)
        XCTAssertEqual(registration.unregisterCount, 0)
    }

    func testExternalDisableClearsStoredConsentWithoutRegisteringOnLaunch() {
        let preferences = LoginItemPreferencesStub()
        preferences.values[LoginItemController.consentKey] = true
        preferences.values[LoginItemController.enabledKey] = true
        let registration = LoginItemRegistrationStub()
        registration.registrationStatus = .notRegistered
        let sut = LoginItemController(preferences: preferences, registration: registration)

        sut.applyConsentMigrationIfNeeded()

        XCTAssertFalse(sut.isEnabled)
        XCTAssertEqual(preferences.values[LoginItemController.consentKey] as? Bool, false)
        XCTAssertEqual(preferences.values[LoginItemController.enabledKey] as? Bool, false)
        XCTAssertEqual(registration.registerCount, 0)
    }

    func testStoredEnableIsNotShownWhenSystemStatusIsNotRegistered() {
        let preferences = LoginItemPreferencesStub()
        preferences.values[LoginItemController.consentKey] = true
        preferences.values[LoginItemController.enabledKey] = true
        let registration = LoginItemRegistrationStub()
        registration.registrationStatus = .notRegistered
        let sut = LoginItemController(preferences: preferences, registration: registration)

        XCTAssertFalse(sut.isEnabled)
    }
}
