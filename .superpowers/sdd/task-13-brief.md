# Task 13 — Mini-console window — secrets CRUD

## Goal
Provide a dedicated **Open Vault…** window for listing secrets and create / edit / delete operations, aligned with the CLI secrets API.

## API (CLI parity)
- `GET /api/v1/secrets` — list metadata (existing)
- `GET /api/v1/secrets/{id}` — metadata + value (existing)
- `POST /api/v1/secrets` — body `{ "name", "value" }` → 201 `{ "secret" }`
- `PUT /api/v1/secrets/{id}` — body `{ "value" }` → 200 `{ "secret" }`
- `DELETE /api/v1/secrets/{id}` — 204 No Content
- 409 conflict on duplicate name → `APIClientError.conflict`

## Deliverables
- Extend `SecretsAPIClient` + `APIClient` with create / update / delete
- `VaultBreak/Console/MiniConsoleWindow.swift` — presenter, activation policy, `NSWindowController`
- `VaultBreak/Console/SecretsListView.swift` — table, forms, delete confirmation
- `VaultBreak/Console/ConsoleSecretsViewModel.swift` — async CRUD + list
- Menu **Open Vault…** when signed in → presenter
- `NSApp.setActivationPolicy(.accessory)` at launch; `.regular` while console visible
- `VaultLockState` — lock CTA; CRUD / plaintext requires unlock

## Tests
- URLProtocol: create 201, update 200, delete 204, create 409
- Full suite via `xcodebuild test`

## Commit
`feat(console): mini vault window with secrets CRUD`
