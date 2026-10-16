# Task 12 — Handoffs API + attention state

## Goal
Surface pending handoffs in the menu bar (attention badge) and popover with Open / Revoke actions aligned to the CLI API.

## API (CLI parity)
- `GET /api/v1/handoffs` → `{ "handoffs": [...] }`
- `POST /api/v1/handoffs/{id}` body `{ "action": "revoke" }` → `{ "handoff": ... }`
- Attention when any handoff has `status == "pending"`

## Deliverables
- `Handoff` Codable models + `HandoffsAPIClient` seam on `APIClient`
- `VaultBreak/Tray/HandoffAttention.swift` — polling (60s default, injectable timer), attention flag
- Menu bar label alternate icon when attention
- Popover pending-handoffs section (signed in + unlocked): Open (web), Revoke
- Task 11 hardening: clear popover secret list on lock

## Polling
Run while signed in AND (menu popover visible OR app active). Refresh immediately when conditions become true.

## Tests
- Fixture decode + `needsAttention`
- URLProtocol list + revoke
- Polling timer seam (unit test without 60s wait)

## Commit
`feat(tray): pending handoff attention with revoke/open`
