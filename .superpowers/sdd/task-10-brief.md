# Task 10 — Popover UI — search, reveal/copy, clipboard clear

## Goal
Signed-in menu bar window: search secrets by name, copy value via API get, timed clipboard clear (30s). Names only in list — never show secret values in cells.

## Deliverables
- `VaultBreak/Support/Clipboard.swift` — injectable pasteboard + scheduler
- `VaultBreak/Tray/PopoverSecretsViewModel.swift` — load, filter, copy
- `VaultBreak/Tray/PopoverView.swift` — search field + list + Copy
- Extend `MenuBarContentView` signed-in branch; `.menuBarExtraStyle(.window)` for layout
- `VaultBreakTests/ClipboardTests.swift`, `PopoverSecretsViewModelTests.swift`

## Security
- No secret values or tokens in logs or list UI
- Clipboard cleared after 30 seconds (configurable in helper for tests)

## Manual test (headless CI)
Run app locally after `vaultbreak login`; open menu bar extra, search, Copy, verify pasteboard and auto-clear.
