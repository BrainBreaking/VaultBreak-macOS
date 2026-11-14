import Foundation
import ServiceManagement

enum LoginItemRegistrationStatus: Equatable {
    case enabled
    case requiresApproval
    case notRegistered
    case notFound
}

protocol LoginItemRegistering {
    var registrationStatus: LoginItemRegistrationStatus { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemRegistering {
    var registrationStatus: LoginItemRegistrationStatus {
        switch status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered: return .notRegistered
        case .notFound: return .notFound
        @unknown default: return .notFound
        }
    }
}

protocol LoginItemPreferences: AnyObject {
    func object(forKey key: String) -> Any?
    func bool(forKey key: String) -> Bool
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: LoginItemPreferences {}

@MainActor
struct LoginItemController {
    static let enabledKey = "loginItemEnabled"
    static let consentKey = "loginItemExplicitConsentV1"

    private let preferences: LoginItemPreferences
    private let registration: LoginItemRegistering

    init(preferences: LoginItemPreferences, registration: LoginItemRegistering) {
        self.preferences = preferences
        self.registration = registration
    }

    var isEnabled: Bool {
        let statusAllowsLaunch = registration.registrationStatus == .enabled
            || registration.registrationStatus == .requiresApproval
        return statusAllowsLaunch
            && preferences.bool(forKey: Self.consentKey)
            && preferences.bool(forKey: Self.enabledKey)
    }

    /// An old enabled preference does not prove consent. On the first launch
    /// after this change it is migrated to off and any registration is removed.
    func applyConsentMigrationIfNeeded() {
        guard preferences.object(forKey: Self.consentKey) == nil else {
            reconcileRegistrationWithoutEnabling()
            return
        }
        preferences.set(false, forKey: Self.consentKey)
        preferences.set(false, forKey: Self.enabledKey)
        unregisterIfNeeded()
    }

    /// Returns false when ServiceManagement rejected the requested change.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        preferences.set(enabled, forKey: Self.consentKey)
        preferences.set(enabled, forKey: Self.enabledKey)
        do {
            if enabled {
                if registration.registrationStatus == .notRegistered
                    || registration.registrationStatus == .notFound {
                    try registration.register()
                }
            } else if registration.registrationStatus != .notRegistered,
                      registration.registrationStatus != .notFound {
                try registration.unregister()
            }
            return true
        } catch {
            preferences.set(!enabled, forKey: Self.consentKey)
            preferences.set(!enabled, forKey: Self.enabledKey)
            return false
        }
    }

    /// Launch reconciliation can only turn the feature off. Registration is
    /// reserved exclusively for a fresh in-app `setEnabled(true)` action.
    private func reconcileRegistrationWithoutEnabling() {
        if registration.registrationStatus == .notRegistered
            || registration.registrationStatus == .notFound {
            preferences.set(false, forKey: Self.consentKey)
            preferences.set(false, forKey: Self.enabledKey)
        } else if !preferences.bool(forKey: Self.consentKey)
                    || !preferences.bool(forKey: Self.enabledKey) {
            unregisterIfNeeded()
        }
    }

    private func unregisterIfNeeded() {
        if registration.registrationStatus != .notRegistered,
           registration.registrationStatus != .notFound {
            try? registration.unregister()
        }
    }
}

@MainActor
enum LoginItemService {
    private static var controller: LoginItemController {
        LoginItemController(preferences: UserDefaults.standard, registration: SMAppService.mainApp)
    }

    static var isEnabled: Bool { controller.isEnabled }

    static func applyConsentMigrationIfNeeded() {
        controller.applyConsentMigrationIfNeeded()
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        controller.setEnabled(enabled)
    }
}
