# Task 11 — UI vault lock + LocalAuthentication

## Goal
When the user is signed in, protect the popover secret list and copy actions behind a UI lock. Unlock with `LocalAuthentication` (`deviceOwnerAuthentication`). Locking must not remove Keychain session tokens.

## Deliverables
- `VaultBreak/Lock/VaultLockState.swift` — `VaultLockState` + `LocalAuthenticationEvaluating` seam
- Wire `PopoverView` / `MenuBarContentView` — locked: unlock UI only; unlocked: search/list/copy
- Tray **Lock Vault** / **Unlock Vault…** menu actions when signed in
- `NSFaceIDUsageDescription` in Info.plist
- `VaultBreakTests/VaultLockStateTests.swift`

## Security
- `lock()` sets `isLocked` only — never `KeychainSessionStore.clear`
- Session sign-out still uses existing `AppSessionModel.clearSession()` path only

## Tests
- Initial locked state
- Lock after unlock
- Unlock success / failure / denied
- `canUseDeviceOwnerAuthentication` passthrough
