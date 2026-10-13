# Task 14 — Mini-console — handoffs tab

## Goal
Extend the mini-console (Task 13) with a **Handoffs** tab listing all handoffs, revoke for pending items, and a session status strip.

## Deliverables
- `HandoffsListView.swift` + `ConsoleHandoffsViewModel` — full list via `listHandoffs`, revoke via `revokeHandoff`, open handoffs web URL
- `MiniConsoleContentView.swift` — `TabView`: Secrets | Handoffs + bottom status strip
- `SessionDisplay.swift` — `apiURLHost(from:)`, `consoleEmail(from:)` helpers
- Wire `MiniConsoleWindow` to `MiniConsoleContentView` with both view models
- `SessionDisplayTests` — host/email extraction

## Status strip
- Email (or `—`)
- API URL host (or `—`)
- Vault: Locked / Unlocked

## Commit
`feat(console): handoffs tab and status strip`
