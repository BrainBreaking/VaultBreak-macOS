import Foundation
import LocalAuthentication

/// Test seam for `LAContext` device-owner authentication.
protocol LocalAuthenticationEvaluating: AnyObject {
    func canEvaluateDeviceOwnerAuthentication() -> Bool
    func evaluateDeviceOwnerAuthentication(reason: String) async throws -> Bool
}

final class LAContextEvaluator: LocalAuthenticationEvaluating {
    private let context: LAContext

    init(context: LAContext = LAContext()) {
        self.context = context
    }

    func canEvaluateDeviceOwnerAuthentication() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func evaluateDeviceOwnerAuthentication(reason: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
}

@MainActor
final class VaultLockState: ObservableObject {
    @Published private(set) var isLocked = true
    @Published private(set) var unlockError: String?
    @Published private(set) var isUnlocking = false

    private let authenticator: LocalAuthenticationEvaluating

    init(authenticator: LocalAuthenticationEvaluating = LAContextEvaluator()) {
        self.authenticator = authenticator
    }

    /// Whether LocalAuthentication can prompt (Touch ID, Apple Watch, or device password).
    var canUseDeviceOwnerAuthentication: Bool {
        authenticator.canEvaluateDeviceOwnerAuthentication()
    }

    func lock() {
        isLocked = true
        unlockError = nil
    }

    /// UI lock only — does not clear Keychain session tokens.
    func unlock() async {
        guard isLocked else { return }
        isUnlocking = true
        unlockError = nil
        defer { isUnlocking = false }

        do {
            let success = try await authenticator.evaluateDeviceOwnerAuthentication(
                reason: "Unlock VaultBreak to view and copy secrets"
            )
            if success {
                isLocked = false
            } else {
                unlockError = "Unlock failed"
            }
        } catch {
            unlockError = "Unlock failed"
        }
    }
}
