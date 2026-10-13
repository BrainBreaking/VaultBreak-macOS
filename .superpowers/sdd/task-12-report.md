# Task 12 report — Handoffs API + attention state

## Summary
- Extended `APIClient` with `listHandoffs()` (`GET /api/v1/handoffs`) and `revokeHandoff(id:)` (`POST /api/v1/handoffs/{id}` body `{"action":"revoke"}`), aligned with vaultbreak-cli.
- Added `Handoff`, `HandoffAttention` models; attention when any handoff has `status == "pending"`.
- `HandoffAttentionCoordinator` polls every 60s when signed in and (popover open or app active); injectable scheduler for tests.
- Menu bar icon uses alternate SF Symbol when attention needed; popover shows pending handoffs with **Open** (https://vault.brainbreaking.com/handoffs) and **Revoke**.
- Task 11 hardening: `PopoverSecretsViewModel.clearLoadedSecrets()` on vault lock clears secret names from memory.

## Tests
- `HandoffAttentionTests`: fixture parse, `needsAttention`, polling gating, scheduler injection.
- `APIClientTests`: list handoffs + revoke (body from `httpBody` or stream).
- Full suite: **42 tests**, `xcodebuild test -scheme VaultBreak -destination 'platform=macOS'` exit 0.

## Files
- `VaultBreak/API/Models.swift`, `APIClient.swift`, `SecretsAPIClient.swift`
- `VaultBreak/Tray/HandoffAttention.swift`, `MenuBarContentView.swift`, `PopoverView.swift`, `PopoverSecretsViewModel.swift`, `VaultBreakApp.swift`
- `VaultBreakTests/HandoffAttentionTests.swift`, `APIClientTests.swift`, `PopoverSecretsViewModelTests.swift`
- `VaultBreak.xcodeproj/project.pbxproj`
