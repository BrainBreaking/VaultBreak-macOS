# Handoff Recipient Email Implementation Plan

> **For agentic workers:** Implement task-by-task. Steps use checkbox syntax.

**Goal:** Optional recipient email on CreateHandoffSheet; pass to API; show email status on success.

**Architecture:** Thread `recipientEmail` through `HandoffsAPIClient` → `APIClient` → `ConsoleHandoffsViewModel` → sheet. Decode optional `email` from create response into `CreateHandoffResult`. No server changes.

**Tech Stack:** SwiftUI, XCTest, existing VaultBreak API v1.

## Global Constraints

- Optional only; Copy link remains primary.
- Additive API client fields; empty string omitted from JSON.
- Client-side email validation when non-empty.

## File map

| File | Change |
|------|--------|
| `API/Models.swift` | `CreateHandoffResult.emailSent`, `emailReason` |
| `API/SecretsAPIClient.swift` | Protocol `recipientEmail` |
| `API/APIClient.swift` | Payload + decode `email` |
| `Console/ConsoleHandoffsViewModel.swift` | Param + `lastCreatedEmailNote` |
| `Console/HandoffsListView.swift` | Field + success note |
| Tests | API + ViewModel + mock signatures |

## Tasks

- [ ] Models + APIClient + protocol + tests
- [ ] ViewModel + sheet UI + tests
- [ ] `xcodebuild test` (or scheme equivalent)
