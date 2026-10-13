# Task 15 report — login item and URL scheme polish

## Summary
Login item registration uses `SMAppService.mainApp` with a menu-bar Preferences toggle (default ON). URL scheme handlers focus the mini-console or reload the Keychain-backed session without requiring the popover.

## Files
| Path | Change |
|------|--------|
| `VaultBreak/Application/LoginItemService.swift` | Login item register/unregister |
| `VaultBreak/Session/VaultBreakURL.swift` | URL action parser |
| `VaultBreak/Session/AppSessionModel.swift` | `handleOpenURL` routing |
| `VaultBreak/VaultBreakApp.swift` | First-launch login item + URL handler |
| `VaultBreak/Application/VaultBreakAppDelegate.swift` | URL events |
| `VaultBreak/Tray/MenuBarContentView.swift` | “Open at Login” toggle |
| `VaultBreakTests/VaultBreakURLParserTests.swift` | Parser tests |
| `VaultBreakTests/AppSessionModelTests.swift` | URL handling tests |
| `VaultBreak.xcodeproj/project.pbxproj` | XcodeGen sync |

## Tests
- `xcodebuild test -scheme VaultBreak -destination 'platform=macOS'` — **55 tests**, 0 failures

## Integration
CLI (Task 15 worktree) calls `open vaultbreak://session-updated` after login/logout so the app refreshes tray state when installed.
