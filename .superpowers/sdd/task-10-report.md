# Task 10 report — Popover UI (search, copy, clipboard clear)

## Summary

Signed-in menu bar window shows a searchable secret list (names only), Copy fetches value via API, writes pasteboard, and schedules clipboard clear after 30 seconds. Rescheduling on repeat copy cancels the prior clear timer.

## Files

| Path | Role |
|------|------|
| `VaultBreak/Support/Clipboard.swift` | Pasteboard + scheduler abstractions; `ClipboardClearService` |
| `VaultBreak/API/SecretsAPIClient.swift` | Testable protocol over list/get |
| `VaultBreak/Tray/PopoverSecretsViewModel.swift` | Load, filter, copy, copied feedback |
| `VaultBreak/Tray/PopoverView.swift` | Search field + list UI |
| `VaultBreak/Tray/MenuBarContentView.swift` | Wires VM; signed-in vs signed-out |
| `VaultBreakTests/ClipboardTests.swift` | Clipboard service + mock scheduler |
| `VaultBreakTests/PopoverSecretsViewModelTests.swift` | VM with mock API client |

## Security / UX

- List cells show secret **names** only; values never rendered in the list.
- Copy path uses `getSecret` only at copy time; brief “Copied” label on row (no value shown).
- No logging of secret values or tokens.
- Unauthorized API errors surface user message; `AppSessionModel.makeAPIClient()` `onUnauthorized` clears session (Task 9).

## Tests

```bash
xcodegen generate && xcodebuild test -scheme VaultBreak -destination 'platform=macOS'
```

**26 tests**, 0 failures (ClipboardTests + PopoverSecretsViewModelTests + existing suites).

## Commit

`feat(tray): search secrets and copy with timed clipboard clear` — see `git log -1 --oneline` on main.

## Manual test (headless / CI)

Popover UI requires signed-in session and live API; verify manually on device: sign in, open menu bar window, search, Copy, confirm pasteboard clears ~30s later.
