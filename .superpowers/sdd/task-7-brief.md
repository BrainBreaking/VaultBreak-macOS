# Task 7 brief — Swift Session + Keychain reader

## Repo
`/Users/arianthox/Workspace/BrainBreaking/VaultBreak-macOS` on `main` @ `4823ed7` (or later)

## Plan
Task 7 in macos-desktop plan.

## Deliverables
- `VaultBreak/Session/Session.swift` — Codable matching Go camelCase JSON
- `VaultBreak/Session/KeychainSessionStore.swift` — load/clear; service `com.brainbreaking.vaultbreak`, account `session`
- Unit tests: decode fixture JSON (prefer date decoding ISO8601)
- Add VaultBreakTests target in project.yml + xcodegen generate
- Verify: `xcodebuild test -scheme VaultBreak -destination 'platform=macOS'`
- Commit: `feat(session): read Keychain session blob shared with CLI`
- Write `.superpowers/sdd/task-7-report.md` with SHA

Do not start Task 8. Do not ask user questions.
