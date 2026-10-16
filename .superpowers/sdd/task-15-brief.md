# Task 15 — Login Item + URL scheme polish

## Goal
Register VaultBreak as a login item (macOS 13+ via `SMAppService.mainApp`) with a Preferences toggle (default ON), and polish `vaultbreak://` handling so CLI login/logout can refresh the menu bar app without user interaction.

## Deliverables
- `LoginItemService.swift` — UserDefaults preference (default ON), `applyOnFirstLaunch()`, `syncRegistration()` with `SMAppService.mainApp`
- Preferences menu toggle “Open at Login” wired to `LoginItemService.isEnabled`
- `VaultBreakURL.swift` — `VaultBreakURLParser` for hosts `open`, `session-updated`
- `AppSessionModel.handleOpenURL` — `open` → mini-console focus; `session-updated` → reload Keychain session (no popover)
- `VaultBreakURLParserTests.swift` — URL parsing unit tests
- Regenerate Xcode project (XcodeGen) so new files are in target

## URL behavior
| URL | Action |
|-----|--------|
| `vaultbreak://open` | Same as “Open Vault…” — show/focus mini-console |
| `vaultbreak://session-updated` | Reload session from Keychain |

## Commit
`feat(app): login item and vaultbreak URL polish`
