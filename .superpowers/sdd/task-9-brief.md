# Task 9 — Swift API client (secrets list + get)

## Goal
HTTP client for `GET /api/v1/secrets` and `GET /api/v1/secrets/{id}` aligned with vaultbreak-cli JSON.

## Contract (CLI)
- List: `{ "secrets": [Secret] }`
- Get: `{ "secret": Secret, "value": string }`
- Secret fields: `id`, `name`, `labels`, `createdAt`, `updatedAt` (camelCase)
- 401/403 → unauthorized; clear Keychain session and tray signed-out state

## Deliverables
- `VaultBreak/API/Models.swift`, `VaultBreak/API/APIClient.swift`
- `VaultBreakTests/APIClientTests.swift` (URLProtocol mock)
- Register `ApplicationURLHandler` at `AppSessionModel` init (Task 8 fix)
- `AppSessionModel.makeAPIClient(onUnauthorized:)` wires 401/403 to `clearSession()`

## Security
- Never log bearer token or secret values
