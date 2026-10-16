import Foundation
import ServiceManagement

@MainActor
enum LoginItemService {
    private static let enabledKey = "loginItemEnabled"

    /// User preference; defaults to `true` when never set.
    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            syncRegistration()
        }
    }

    /// On first launch, persist default ON and register the login item when appropriate.
    static func applyOnFirstLaunch() {
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            UserDefaults.standard.set(true, forKey: enabledKey)
        }
        syncRegistration()
    }

    static func syncRegistration() {
        let service = SMAppService.mainApp
        do {
            if isEnabled {
                if service.status == .notRegistered {
                    try service.register()
                }
            } else if service.status == .enabled {
                try service.unregister()
            }
        } catch {
            // Login item registration is best-effort; user can retry from Preferences.
        }
    }
}
