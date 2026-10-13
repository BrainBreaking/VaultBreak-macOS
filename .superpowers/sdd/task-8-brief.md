# Task 8 brief — Menu bar signed-in / out

## Goal
Reflect Keychain session in the menu bar: dimmed icon + login hint when signed out; normal icon + email + disabled Open Vault when signed in.

## Approach
- `AppSessionModel` (`ObservableObject`) wraps `KeychainSessionStore`, exposes `isSignedIn`, `accountLabel` (never token).
- Reload on init, `NSApplication.didBecomeActive`, and `vaultbreak://session-updated`.
- `vaultbreak://open` no-op until M5.
- `MenuBarExtra` with dynamic label opacity and `.menu` style for Quit / status rows.

## Tests
- `AppSessionModelTests` with shared mock data source pattern from Task 7.

## Gate
`xcodegen generate && xcodebuild test -scheme VaultBreak -destination 'platform=macOS'`
