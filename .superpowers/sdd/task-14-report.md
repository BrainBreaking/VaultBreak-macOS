# Task 14 report — handoffs tab and status strip

## Summary
Mini-console now uses a two-tab layout (Secrets | Handoffs) with a bottom status strip showing signed-in email, API host, and vault lock state.

## Files
| Path | Change |
|------|--------|
| `VaultBreak/Console/HandoffsListView.swift` | Handoffs tab UI |
| `VaultBreak/Console/ConsoleHandoffsViewModel.swift` | Load/revoke/open browser |
| `VaultBreak/Console/MiniConsoleContentView.swift` | TabView + status strip |
| `VaultBreak/Session/SessionDisplay.swift` | Display helpers |
| `VaultBreak/Console/MiniConsoleWindow.swift` | Root → MiniConsoleContentView |
| `VaultBreakTests/SessionDisplayTests.swift` | Unit tests |
| `VaultBreak.xcodeproj/project.pbxproj` | Target membership |

## Tests
- `xcodebuild test -scheme VaultBreak -destination 'platform=macOS'` — **50 tests**, 0 failures

## M5
Task 13 secrets CRUD + Task 14 handoffs tab complete.
