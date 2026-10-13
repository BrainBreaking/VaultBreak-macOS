# Task 12 SDD Code Review — Pending Handoff Attention

| Field | Value |
|-------|-------|
| Repo | VaultBreak-macOS |
| Commit | `6028b12` — feat(tray): pending handoff attention with revoke/open |
| Reviewer | SDD code-reviewer (continuous) |
| Date | 2026-10-12 |

## Verdict

**ACCEPT WITH NOTES** — Ready to proceed to Task 13. No blocking defects; minor spec/doc gaps noted below.

---

## Checklist

| # | Requirement | Result |
|---|-------------|--------|
| 1 | `GET /api/v1/handoffs` | **Pass** — `APIClient.listHandoffs()` |
| 2 | `POST /api/v1/handoffs/{id}` body `{"action":"revoke"}` | **Pass** — matches `vaultbreak-cli/internal/api/handoffs.go` |
| 3 | Attention = `status == "pending"` | **Pass** — `HandoffAttention.needsAttention` |
| 4 | 60s poll when signed in ∧ (popover open ∨ app active) | **Pass** — `MenuBarContentView.updateHandoffPolling()` |
| 5 | Tray alternate/badge when attention | **Pass** — `MenuBarExtraLabel` icon + red dot |
| 6 | Popover Revoke / Open → handoffs web UI | **Pass** — `HandoffAttention.handoffsWebURL` |
| 7 | Optional: clear secrets VM on lock | **Partial** — `clearLoadedSecrets()` on Lock Vault + sign-out only |
| 8 | Tests pass | **Pass** — `xcodebuild test -scheme VaultBreak -destination 'platform=macOS'` → 42 tests, 0 failures |

---

## Findings

| Sev | Area | Finding |
|-----|------|---------|
| **Low** | Brief vs UI | Task brief says handoffs section when **signed in + unlocked**; `PopoverView` shows pending handoffs whenever signed in (including vault locked). No secret payloads are shown when locked; only handoff metadata + Revoke/Open. |
| **Low** | Lock hardening | Secrets cleared on explicit **Lock Vault** and **Sign out**, not on every `VaultLockState.isLocked` transition. All current `lock()` call sites in app code clear secrets; acceptable for Task 12 optional item. |
| **Low** | Tests | No unit test for `HandoffAttentionModel.revokeHandoff` (API revoke encoding covered in `APIClientTests`). |
| **Info** | Docs | `task-12-report.md` references `HandoffAttentionCoordinator`; implementation is `HandoffAttentionModel`. |
| **Info** | Polling | `DefaultHandoffPollingScheduler` sleeps before first interval tick; immediate refresh on `setPollingActive(true)` via `Task { await refresh() }` satisfies responsiveness. |

---

## Evidence

### API parity (CLI)

- List: `GET /api/v1/handoffs`
- Revoke: `POST /api/v1/handoffs/{id}` with JSON `{"action":"revoke"}`

### Polling lifecycle

- Injectable `HandoffPollingScheduler` (test double in `HandoffAttentionTests`)
- `stopPolling()` cancels task; `deinit` stops polling — no obvious timer leak

### Secrets when locked

- `PopoverView` gates secret list on `lockState.isLocked`
- `PopoverSecretsViewModel.clearLoadedSecrets()` tested in `PopoverSecretsViewModelTests`

---

## Recommendation

Proceed to **Task 13**. Optional follow-ups (non-blocking): gate handoffs UI on unlock if product wants strict brief alignment; add `revokeHandoff` model test; rename doc references to `HandoffAttentionModel`.
