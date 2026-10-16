# Task 13 SDD Code Review — Mini Vault Console (Secrets CRUD)

| Field | Value |
|-------|-------|
| Repo | VaultBreak-macOS |
| Commit | `b4e107a` — feat(console): mini vault window with secrets CRUD |
| Reviewer | SDD code-reviewer (continuous) |
| Date | 2026-10-12 |

## Verdict

**ACCEPT WITH NOTES** — Ready to proceed to **Task 14**. No blocking defects against the Task 13 brief.

---

## Checklist

| # | Requirement | Result |
|---|-------------|--------|
| 1 | **Open Vault…** opens `NSWindow` with secrets table | **Pass** — `MiniConsolePresenter.open` → `MiniConsoleWindowController` (560×420, resizable); `SecretsListView` `Table` with Name / Updated / Edit / Delete |
| 2 | Create / edit use secure fields; delete with confirmation | **Pass** — `CreateSecretSheet` / `EditSecretSheet` use `SecureField`; destructive `alert` before delete |
| 3 | Activation policy `.accessory` default; `.regular` while console visible | **Pass** — `VaultBreakAppDelegate` sets `.accessory` at launch; `show()` → `.regular`; `windowWillClose` → `.accessory` + presenter release |
| 4 | API: POST/PUT/DELETE aligned with CLI | **Pass** — POST `/api/v1/secrets` `{"name","value"}`; PUT `/api/v1/secrets/{id}` `{"value"}`; DELETE `/api/v1/secrets/{id}` |
| 5 | Delete expects 204 | **Pass** — `testDeleteSecret204`; client `performDELETE` accepts empty 204 body |
| 6 | Lock gates plaintext / CRUD | **Pass** — locked branch hides table and CRUD; unlock CTA only; `.task(id: lockState.isLocked)` loads list only when unlocked |
| 7 | **Open Vault…** when signed in | **Pass** — `MenuBarContentView` button inside `model.isSignedIn` block |
| 8 | Tests pass | **Pass** — `xcodebuild test -scheme VaultBreak -destination 'platform=macOS'` → **46** tests, **0** failures (per task-13-report; re-run recommended on CI) |

---

## Findings

| Sev | Area | Finding |
|-----|------|---------|
| **Low** | Lock / memory | **Lock Vault** clears `PopoverSecretsViewModel` via `clearLoadedSecrets()` but does not reset `ConsoleSecretsViewModel.secrets`. UI is gated when locked (metadata not shown); cached names may remain in memory until window is closed or reload. Same class of gap as Task 12 optional lock hardening. |
| **Low** | Tests | CRUD covered at `APIClient` layer only; no unit tests for `ConsoleSecretsViewModel` or console UI flows. |
| **Info** | Activation policy | Policy restored on **window close**, not on minimize. A miniaturized console leaves `.regular` until the user closes the window — consistent with “while console visible” if dock/window still exists. |
| **Info** | Lock + open console | User can lock while the vault window stays open; sheets are not auto-dismissed. Locked overlay blocks further CRUD; acceptable for v1. |

---

## Evidence

### API bodies (CLI parity)

```70:98:VaultBreak/API/APIClient.swift
    func createSecret(name: String, value: String) async throws -> SecretMetadata {
        ...
        let body = try JSONSerialization.data(withJSONObject: ["name": trimmedName, "value": value])
        let data = try await performPOST(path: "/api/v1/secrets", body: body)
        ...
    }

    func updateSecret(id: String, value: String) async throws -> SecretMetadata {
        ...
        let body = try JSONSerialization.data(withJSONObject: ["value": value])
        let data = try await performPUT(path: path, body: body)
        ...
    }

    func deleteSecret(id: String) async throws {
        ...
        try await performDELETE(path: path)
    }
```

### Activation policy lifecycle

```53:62:VaultBreak/Console/MiniConsoleWindow.swift
    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        MiniConsolePresenter.releaseWindow()
    }
```

### Lock gating (no table when locked)

```12:23:VaultBreak/Console/SecretsListView.swift
        Group {
            if lockState.isLocked {
                lockedContent
            } else {
                unlockedContent
            }
        }
        ...
        .task(id: lockState.isLocked) {
            guard !lockState.isLocked else { return }
            await viewModel.loadSecrets()
        }
```

### Test assertions (create / update / delete)

- `testCreateSecret201`: POST path, body `name` + `value`
- `testUpdateSecret200`: PUT path `/api/v1/secrets/sec-42`, body `value` only
- `testDeleteSecret204`: DELETE path, status 204
- `testCreateSecret409Conflict`: conflict surfaced as `APIClientError.conflict` → user-facing message in VM

---

## Recommendation

**Proceed to Task 14.**

Optional follow-ups (non-blocking):

1. On lock (or `lockState.isLocked`), call `ConsoleSecretsViewModel` clear helper mirroring popover behavior if stricter memory hygiene is required.
2. Add `ConsoleSecretsViewModelTests` for create/update/delete error mapping and reload after mutations.
3. Document or handle minimize → accessory if product wants menu-bar-only behavior while window is minimized.
