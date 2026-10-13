# Task 11 report — UI vault lock + LocalAuthentication

## Summary
- `VaultLockState` starts locked; `lock()` / `unlock()` control popover secret UI only.
- `LocalAuthenticationEvaluating` wraps `LAContext` for unit tests.
- Popover shows unlock panel when locked; search/list/copy when unlocked.
- Tray menu: **Lock Vault** / **Unlock Vault…** when signed in.
- `NSFaceIDUsageDescription` added for Touch ID / password prompts.

## Security
- `VaultLockState` does not reference `KeychainSessionStore` or `AppSessionModel.clearSession()`.
- Sign-out path unchanged; `onChange(isSignedIn)` re-locks UI when session disappears.

## Tests
- `VaultLockStateTests`: 6 cases (locked default, lock, unlock success/fail/deny, canEvaluate).
- Full suite: **32 tests**, `xcodebuild test` exit 0.

## Manual
- Sign in via CLI; open menu bar — unlock with Touch ID or password; lock from menu; confirm secrets hidden when locked.
