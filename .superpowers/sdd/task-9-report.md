# Task 9 report — Swift API client (secrets list/get)

## Outcome
DONE — URLSession-based client with URLProtocol tests; 401/403 clears session; URL handler registered at `AppSessionModel` init (Task 8 fix).

## Deliverables
| File | Change |
|------|--------|
| `VaultBreak/API/Models.swift` | `SecretMetadata`, `SecretWithValue`, `APIClientError` |
| `VaultBreak/API/APIClient.swift` | `listSecrets()`, `getSecret(id:)`, injectable session, `onUnauthorized` |
| `VaultBreak/Session/AppSessionModel.swift` | URL handler in init; `makeAPIClient` wires unauthorized → `clearSession()` |
| `VaultBreak/VaultBreakApp.swift` | Removed URL wiring from menu `onAppear` |
| `VaultBreakTests/APIClientTests.swift` | Mock URLProtocol + 401 session clear test |

## Tests
- `xcodebuild test -scheme VaultBreak -destination 'platform=macOS'`: **20 tests**, 0 failures

## Security
- No logging of Bearer token or secret values
- 401/403 → Keychain clear + signed-out tray via `clearSession()`

## Commit
SHA: see `git log -1 --oneline` — Message: `feat(api): secrets list/get client for tray popover`
