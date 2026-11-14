# Apple review remediation — 2026-10-27

## Submission and review result

- App: VaultBreak for macOS
- Version/build: 1.0 (2)
- Review submission: `4dea5873-2f7e-4a1e-b756-b0ed1c4dcf64`
- Submitted through the App Store Connect API: 2026-10-19
- Live API result on 2026-10-27: submission `UNRESOLVED_ISSUES`, item/version `REJECTED`
- Build 2 remains `VALID` and App Store eligible.

Apple cited:

1. Guideline 2.4.5(iii): the app enabled Open at Login without explicit consent.
2. Guideline 4: sign-in opened the default browser instead of using `ASWebAuthenticationSession`.
3. Guideline 2.3.6: the age-rating declaration claimed Parental Controls that the app does not provide.
4. Apple additionally reminded the team that apps supporting account creation must provide account deletion.

## Approved product decisions

- Open at Login must default off and require an explicit in-app user action.
- Legacy implicit registrations must be migrated off unless explicit consent is recorded.
- Authentication must use `ASWebAuthenticationSession`.
- Add Sign in with Apple alongside Google.
- Account deletion deletes member-owned private data and credentials while anonymizing retained/shared handoffs and audit records so other users' data is not damaged.
- Do not mutate App Store metadata or resubmit until code, tests, and runtime validation pass.

## Cross-repository contracts

### macOS sign-in

- Start: `POST /api/v1/device/code` with `{"client":"macos"}`.
- The server returns an allowlisted `verificationUriComplete`.
- Web approval returns one of:
  - `vaultbreak://session-updated?result=approved`
  - `vaultbreak://session-updated?result=denied`
- No token or device code is returned in the callback; device-token polling remains authoritative.

### Account deletion

- Native entry point: `/account/delete?return_to=vaultbreak://account-deleted`.
- Only the exact allowlisted return URL is accepted.
- On success, the web session is cleared and the browser returns `vaultbreak://account-deleted` with no token or user data.
- The macOS app clears its local Keychain session only after that exact callback.

### Sign in with Apple deployment configuration

- Required: `AUTH_APPLE_ID`, `AUTH_APPLE_SECRET`, and `AUTH_SECRET` (or optional `ACCOUNT_DELETION_HASH_KEY` for deletion receipts).
- Register callback: `https://vault.brainbreaking.com/api/auth/callback/apple`.
- Never store the Apple private key or generated client-secret material in the repository.

## Implemented, pending runtime validation

### VaultBreak-macOS

- Explicit-consent login-item service and migration.
- `ASWebAuthenticationSession` sign-in presenter and callback validation.
- Device-code request contract for the macOS client.
- Visible Delete Account action and exact callback handling.
- XCTest coverage for login-item migration/errors, auth outcomes, callback validation, deletion, and Keychain cleanup.

### VaultBreak web/backend

- macOS-specific device-approval callback flow.
- Auth.js Sign in with Apple provider and stable Apple-subject identity binding.
- Account-deletion service, API, UI, migration, privacy-policy updates, and tests.
- Intended deletion behavior: private member data and credentials deleted; shared records anonymized/pseudonymized; last approved administrator protected.

## Review findings

Source review on 2026-10-29 closed the product behavior Apple asked for. The Resolution Center footer codes are 2.3.6, 2.4.5, and 4.0.0. Guideline 5.1.1(v) is the account-deletion reminder, not a fourth rejection code.

| Finding | Status |
|---|---|
| 2.4.5 Open at Login | Done. The menu toggle starts off. Registration happens only when the user turns it on. A System Settings disable is not registered again on launch. |
| 4.0.0 sign-in | Done. Sign-in uses `ASWebAuthenticationSession`. The `vaultbreak` URL scheme is registered in `Info.plist`. |
| 5.1.1(v) account deletion | Done. The menu has Delete Account. The Mac app requests a short-lived authorization URL, the web page deletes only the matching signed-in member, and the local session clears only from the active deletion sheet when the callback is exactly `vaultbreak://account-deleted`. |
| 2.3.6 age rating | Not a code change. The app has no Parental Controls or Age Assurance. Set Parental Controls to None on the App Information page. |

Internal blockers from the first code review:

1. Done. Live membership is checked before a deletion receipt. A recreated email is a new account.
2. Done. Native deletion uses a single-use authorization bound to the member, and deletion requires a browser sign-in from the last 10 minutes.
3. Done. Recipient emails are matched case-insensitively, and reviewer/actor identifier columns are cleared or pseudonymized.
4. Done. `SMAppService` status is authoritative, with XCTest coverage.
5. Done in the working tree. CI now provisions PostgreSQL and exercises destructive deletion, identifier pseudonymization, native authorization binding, concurrent last-admin protection, and Apple subject conflicts against real transactions.
6. Done. `docs/deploy.md` says to apply migrations through `0007` before deploying.
7. Done. An existing Apple subject resolves to its bound member or is rejected.
8. Done. A forged `vaultbreak://account-deleted` URL does not clear the menu-bar session.

The security review found no hard-coded secrets, access-token leakage, open redirects, or evident CSRF bypass in the remediation diff.

## Still pending

- Run the configured PostgreSQL integration and coverage job in hosted CI after the branch is pushed.
- Real menu-bar runtime check of sign-in, Open at Login, and Delete Account.
- Confirm Sign in with Apple is configured in Apple Developer and the production environment.
- In App Store Connect, set Age Rating **Parental Controls** to **None**. Also set unrestricted web access to None: the app is not a browser. Leave user-generated content set only if handoff titles and messages should count as user-generated content.
- After that validation, upload build 3, attach it to version 1.0, update review notes, reply in Resolution Center, and resubmit. Do not do that until asked.

Final local validation on 2026-10-29 passed all 352 web tests against PostgreSQL 16 and all 118 macOS tests. Remediation coverage was 100% lines, 100% functions, 98.63% statements, and 93.4% branches. The Node 22 production build passed, and `npm audit --omit=dev` reported zero vulnerabilities. The `VaultBreakMAS` unsigned ReleaseMAS build and archive also passed with the `APP_STORE` compilation condition enabled.

## Security note

App Store review details contain plaintext demo credentials. Do not copy them into source, logs, documentation, or future memory files. Rotate the demo password after review.
