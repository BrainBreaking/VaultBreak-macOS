# Delete Account Preview Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A throwaway member can finish Delete Account against a Vercel preview, then once against production, without resubmitting the Mac app.

**Architecture:** The web deletion flow already exists as uncommitted work in `VaultBreak`. Ship that work on a preview branch whose database is not production. The Mac Debug build reads `VAULTBREAK_API_BASE_URL` and otherwise keeps `https://vault.brainbreaking.com`. Release builds cannot see the override.

**Tech Stack:** Next.js 15 on Vercel, Drizzle SQL migration `0007`, SwiftUI menu-bar app, XCTest, `ASWebAuthenticationSession`.

## Global Constraints

- Do not commit `.env.local` or any secret value.
- Do not turn `AUTH_DEV_BYPASS` on for the preview or production check.
- Do not delete a member you intend to keep. Use a throwaway email.
- Do not change App Store Connect metadata and do not upload or resubmit a build.
- Do not point the preview `DATABASE_URL` at the production Neon database.
- The confirmation phrase is `DELETE MY VAULTBREAK ACCOUNT`.
- The success callback is exactly `vaultbreak://account-deleted`.

---

## File map

| File | Responsibility |
|---|---|
| `VaultBreak-macOS/VaultBreak/API/VaultBreakWeb.swift` | Production origin plus Debug-only https override |
| `VaultBreak-macOS/VaultBreakTests/VaultBreakWebTests.swift` | Override acceptance and rejection |
| `VaultBreak/src/lib/account-deletion/**` | Already written. Include in the web PR |
| `VaultBreak/src/app/account/delete/**` | Already written. Include in the web PR |
| `VaultBreak/src/app/api/account/route.ts` | Already written. Include in the web PR |
| `VaultBreak/src/app/api/v1/account/deletion-authorization/route.ts` | Already written. Include in the web PR |
| `VaultBreak/drizzle/0007_apple_identity_account_deletion.sql` | Apply to the preview database, later to production |
| `VaultBreak/docs/deploy.md` | Already notes that `0007` must be applied before this release |

Repos:

- Mac app: `/Users/arianthox/Workspace/BrainBreaking/VaultBreak-macOS` on `feat/macos-desktop-companion`
- Web: `/Users/arianthox/Workspace/BrainBreaking/VaultBreak` on `main` at `66bb31c`

---

### Task 1: Debug-only API origin

**Files:**
- Modify: `VaultBreak-macOS/VaultBreak/API/VaultBreakWeb.swift`
- Test: `VaultBreak-macOS/VaultBreakTests/VaultBreakWebTests.swift`

**Interfaces:**
- Consumes: process environment key `VAULTBREAK_API_BASE_URL`
- Produces: `VaultBreakWeb.resolvedBaseURL(environment:) -> URL` and `VaultBreakWeb.baseURL`, which `DeviceAuthClient` and `DeviceSignInModel` already use as their default

- [x] **Step 1: Write the failing tests**

Add these methods to `VaultBreakWebTests`:

```swift
func testResolvedBaseURLStaysOnProductionWhenUnset() {
    XCTAssertEqual(
        VaultBreakWeb.resolvedBaseURL(environment: [:]).absoluteString,
        "https://vault.brainbreaking.com"
    )
}

func testResolvedBaseURLAcceptsHttpsOrigin() {
    let url = VaultBreakWeb.resolvedBaseURL(environment: [
        "VAULTBREAK_API_BASE_URL": "https://vaultbreak-git-preview.vercel.app/",
    ])
    XCTAssertEqual(url.absoluteString, "https://vaultbreak-git-preview.vercel.app")
}

func testResolvedBaseURLRejectsHttpUserPathAndQuery() {
    let rejected = [
        "http://localhost:3000",
        "https://user:secret@preview.vercel.app",
        "https://preview.vercel.app/account/delete",
        "https://preview.vercel.app/?next=/",
        "not a url",
    ]
    for raw in rejected {
        XCTAssertEqual(
            VaultBreakWeb.resolvedBaseURL(environment: [
                "VAULTBREAK_API_BASE_URL": raw,
            ]).absoluteString,
            "https://vault.brainbreaking.com",
            raw
        )
    }
}
```

- [x] **Step 2: Run the tests and confirm they fail to compile**

```bash
cd /Users/arianthox/Workspace/BrainBreaking/VaultBreak-macOS
make test
```

Expected: compile error that `VaultBreakWeb` has no `resolvedBaseURL`.

- [x] **Step 3: Implement the override**

Replace `VaultBreak/API/VaultBreakWeb.swift` with:

```swift
import Foundation

/// Single source of truth for VaultBreak web app URLs.
enum VaultBreakWeb {
    static let productionBaseURL = URL(string: "https://vault.brainbreaking.com")!

    static var baseURL: URL {
        resolvedBaseURL()
    }

    static var overviewURL: URL { baseURL.appendingPathComponent("overview") }
    static var handoffsURL: URL { baseURL.appendingPathComponent("handoffs") }
    static var accountDeletionURL: URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("account/delete"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "return_to", value: "vaultbreak://account-deleted")
        ]
        return components.url!
    }

    static func resolvedBaseURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        #if DEBUG
        if let override = httpsOrigin(from: environment["VAULTBREAK_API_BASE_URL"]) {
            return override
        }
        #endif
        return productionBaseURL
    }

    /// Accepts an https origin only. A path, query, user, or non-https scheme returns nil.
    static func httpsOrigin(from raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil,
              let host = url.host?.lowercased(),
              !host.isEmpty,
              url.path.isEmpty || url.path == "/",
              url.query == nil,
              url.fragment == nil
        else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.port = url.port
        return components.url
    }
}
```

`#if DEBUG` is set for the Debug configuration that `make test` and local Run use. Release and ReleaseMAS do not define it, so an App Store or Developer ID build ignores the variable even if the environment contains it.

- [x] **Step 4: Run the Mac tests**

```bash
cd /Users/arianthox/Workspace/BrainBreaking/VaultBreak-macOS
make test
```

Expected: `TEST SUCCEEDED`. Existing overview and handoff assertions still expect production because the test process does not set `VAULTBREAK_API_BASE_URL`.

- [ ] **Step 5: Commit the Mac override on the existing feature branch**

```bash
cd /Users/arianthox/Workspace/BrainBreaking/VaultBreak-macOS
git add VaultBreak/API/VaultBreakWeb.swift VaultBreakTests/VaultBreakWebTests.swift
git commit -m "$(cat <<'EOF'
Allow Debug builds to target an https VaultBreak preview.

Release builds stay on vault.brainbreaking.com so a local override cannot ship.
EOF
)"
```

Do not commit unrelated dirty files in that command.

---

### Task 2: Web deletion pull request

**Files:** already present in `/Users/arianthox/Workspace/BrainBreaking/VaultBreak`. Do not rewrite them.

**Interfaces:**
- `POST /api/v1/account/deletion-authorization` returns `{ deletionUrl, expiresIn, account }`. `deletionUrl` uses the request origin, path `/account/delete`, query `authorization` and `return_to=vaultbreak://account-deleted`.
- `DELETE /api/account` deletes the browser session member after the phrase and a sign-in newer than 10 minutes.

- [ ] **Step 1: Create the branch from current main**

```bash
cd /Users/arianthox/Workspace/BrainBreaking/VaultBreak
git checkout -b feat/account-deletion-preview
```

- [ ] **Step 2: Stage the deletion set**

Stage these paths:

```text
drizzle/0007_apple_identity_account_deletion.sql
docs/account-deletion.md
docs/deploy.md
src/lib/account-deletion
src/lib/auth/oauth-identity.ts
src/lib/device-auth/native-callback.ts
src/app/account
src/app/api/account
src/app/api/v1/account
src/app/login/apple-sign-in-button.tsx
src/lib/db/schema.ts
src/lib/auth.ts
src/lib/auth.config.ts
src/lib/auth-member.ts
src/lib/api-v1/http.ts
src/lib/api-tokens/auth.ts
src/lib/safe-ops-next.ts
src/middleware.ts
src/app/login/page.tsx
src/types
tests/account-deletion.test.ts
tests/api-account-deletion.test.ts
tests/api-deletion-authorization.test.ts
tests/oauth-identity.test.ts
tests/recent-auth.test.ts
tests/device-native-callback.test.ts
tests/safe-ops-next.test.ts
```

Also stage `.env.example` only when `git diff .env.example` documents `AUTH_APPLE_ID`, `AUTH_APPLE_SECRET`, or `ACCOUNT_DELETION_HASH_KEY` and does not add a real secret.

Do not stage `.env.local`, `drizzle/meta`, `docs/superpowers`, `messages/en.json`, `messages/es.json`, `messages/fr.json`, or device-approve and membership files unless `git diff` shows the deletion page or route fails to compile without that hunk. If a file mixes an unrelated hunk with a required hunk, split the hunk before committing.

- [x] **Step 3: Run the complete web test, PostgreSQL integration, and coverage suites**

```bash
cd /Users/arianthox/Workspace/BrainBreaking/VaultBreak
npx vitest run \
  tests/account-deletion.test.ts \
  tests/api-account-deletion.test.ts \
  tests/api-deletion-authorization.test.ts \
  tests/oauth-identity.test.ts \
  tests/safe-ops-next.test.ts \
  tests/device-native-callback.test.ts
```

Current result: the complete database-enabled suite passes, including recent-auth and the PostgreSQL remediation tests. CI runs the same tests under the approved Node 22 runtime and enforces remediation coverage thresholds.

- [ ] **Step 4: Commit and open the pull request**

```bash
git commit -m "$(cat <<'EOF'
Add native account deletion for the Mac companion.

The preview deploy is how Delete Account is validated before production.
EOF
)"
git push -u origin HEAD
gh pr create --title "Add native account deletion" --body "$(cat <<'EOF'
## Summary
- Adds the account deletion page, native authorization route, and migration 0007.
- Keeps deletion bound to the browser member who signs in inside the Mac auth sheet.

## Test plan
- [ ] Preview deployment is https and is not production
- [ ] Preview DATABASE_URL is a separate Neon branch
- [ ] AUTH_DEV_BYPASS is false on the preview
- [ ] 0007 is applied to that preview database
- [ ] Mac Debug click-through with a throwaway member returns to signed out

EOF
)"
```

Do not merge this pull request in this task.

---

### Task 3: Preview database, OAuth, and migration

**Files:** none in git. Vercel Preview environment and the preview Neon branch.

- [ ] **Step 1: Wait for the Vercel preview URL**

Copy the `https://…vercel.app` URL from the pull request. Call it `$PREVIEW`.

- [ ] **Step 2: Confirm the preview database is not production**

In Vercel, open the Preview environment `DATABASE_URL`. Compare the host with Production `DATABASE_URL`. They must differ. If they match, create a Neon branch from production and set that branch’s pooled URL as Preview `DATABASE_URL` only. Redeploy the preview after changing it.

- [ ] **Step 3: Set the other Preview values**

| Name | Preview value |
|---|---|
| `APP_BASE_URL` | `$PREVIEW` |
| `AUTH_SECRET` | a preview-only secret, already required by Auth.js |
| `AUTH_DEV_BYPASS` | `false` |
| `ACCOUNT_DELETION_HASH_KEY` | unset is acceptable; receipts then use `AUTH_SECRET` |
| `AUTH_GOOGLE_ID` / `AUTH_GOOGLE_SECRET` | same Google client as production only after step 4 |
| `AUTH_APPLE_ID` / `AUTH_APPLE_SECRET` | optional for this click-through; Google is enough |

- [ ] **Step 4: Authorize the preview origin for Google sign-in**

Add `$PREVIEW` to the Google OAuth authorized JavaScript origins and redirect URIs used by Auth.js (`$PREVIEW/api/auth/callback/google`). Device sign-in opens `$PREVIEW/device/approve` because the device-code route builds that URL from the request origin. A preview that is not an authorized redirect cannot complete sign-in.

- [ ] **Step 5: Apply migration 0007 to the preview database**

Run `drizzle/0007_apple_identity_account_deletion.sql` against the preview `DATABASE_URL` with the Neon SQL editor or `psql`. The script creates `auth_identities`, `account_deletions`, and `account_deletion_authorizations`. Do not print the connection string.

- [ ] **Step 6: Probe the preview routes**

```bash
curl -sI "$PREVIEW/account/delete" | head -n 15
curl -sI -X POST "$PREVIEW/api/v1/account/deletion-authorization" | head -n 15
```

Expected: not `x-matched-path: /_not-found`. The page may redirect to login. The POST without a bearer token may return 401. A 404 with `x-matched-path: /_not-found` means the preview is still the old deployment.

---

### Task 4: Mac click-through against the preview

**Files:** none. Uses the Debug build from Task 1.

- [ ] **Step 1: Rebuild and quit any running VaultBreak**

```bash
cd /Users/arianthox/Workspace/BrainBreaking/VaultBreak-macOS
make build
osascript -e 'quit app "VaultBreak"'
```

- [ ] **Step 2: Launch with the preview origin**

`open` does not pass the variable through. Launch the executable:

```bash
VAULTBREAK_API_BASE_URL="$PREVIEW" \
  /Users/arianthox/Library/Developer/Xcode/DerivedData/VaultBreak-firjdbmiliamhxdluklwjxazftcs/Build/Products/Debug/VaultBreak.app/Contents/MacOS/VaultBreak
```

If `make build` prints a different `BUILT_PRODUCTS_DIR`, use that path. The menu icon is the lock shield.

- [ ] **Step 3: Sign in as the throwaway member**

If the menu already says signed in, choose Log out first. The stored session keeps its old `apiUrl`, and the environment variable does not rewrite it.

Choose Sign in…, approve the device code in the sheet as the throwaway member, and wait until the menu shows that member.

- [ ] **Step 4: Delete the throwaway account**

Choose Delete Account…. If the sheet asks for sign-in, sign in again as the same member. A session older than 10 minutes asks for that again on purpose. Type `DELETE MY VAULTBREAK ACCOUNT` and confirm.

Expected: the sheet closes and the menu returns to Sign in…. The local session is cleared only after `vaultbreak://account-deleted`.

- [ ] **Step 5: Stop if the sheet errors**

Leave the pull request unmerged. An expired authorization, a member mismatch, or a missing `0007` table must be fixed before Task 5. Do not retry against production.

---

### Task 5: Production repeat

Do this only after Task 4 succeeds.

- [ ] **Step 1: Merge the web pull request to `main`**

Vercel deploys `main` to `https://vault.brainbreaking.com`.

- [ ] **Step 2: Apply `0007` to the production database**

Use the production `DATABASE_URL`, not the preview branch. Apply the same SQL file. Deploying the code without the tables makes deletion fail closed.

- [ ] **Step 3: Repeat the click-through on production with a new throwaway member**

Quit the preview launch. Start the Debug app with no `VAULTBREAK_API_BASE_URL` so it uses `https://vault.brainbreaking.com`. Log out if the menu still holds the preview session. Create or invite a different throwaway member, sign in, and delete that member the same way.

Expected: menu returns to Sign in…. The member cannot sign in again.

- [ ] **Step 4: Leave the App Store submission alone**

Parental Controls = None remains a separate App Store Connect edit. Do not upload build 3 and do not reply in Resolution Center as part of this plan.

---

## Self-review

- Task 1 and the PostgreSQL/coverage hardening are implemented in the working trees. Tasks 2–5 still require source-control, preview, and production operations.
- The preview cannot be tested on `http://localhost` because the Mac client intentionally accepts only an HTTPS origin.
- A preview that shares the production database would make Task 4 a production delete. Task 3 step 2 blocks that.
- Spec coverage: preview branch, separate database, Debug override, throwaway click-through, production repeat, no resubmit.
