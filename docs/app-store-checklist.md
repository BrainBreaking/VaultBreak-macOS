# Mac App Store checklist (VaultBreak)

Status: **planning** — distribution decision: **dual track (B)** confirmed (2026-10-16). Keep **Developer ID + notarization + GitHub Releases** for CLI Keychain sharing; MAS is a separate sandboxed build. See [signing-and-notarization.md](./signing-and-notarization.md).

Bundle ID: `com.brainbreaking.vaultbreak`  
Min OS: macOS 13+

---

## Two distribution tracks (do not conflate)

| | Direct (current) | Mac App Store |
|--|------------------|---------------|
| Signing | Developer ID Application | Apple Distribution + MAS profile |
| Gatekeeper | Notarize + staple | Not required (Store-signed) |
| Sandbox | Optional (docs recommend off for CLI Keychain sharing) | **Required on** |
| Package | `.dmg` / `.zip` on GitHub | Upload via Xcode / Transporter → App Store Connect |
| Updates | Manual / GitHub | App Store |

Recommendation: keep **direct distribution** as the primary path for power users (CLI + shared Keychain). Treat MAS as a **separate product slice** (build config / entitlements / session model), not a one-flag flip.

---

## Blockers (must resolve before first MAS submit)

### 1. App Sandbox

- [x] Direct track: `VaultBreak/VaultBreak.entitlements` with sandbox **false** (CLI Keychain + SMAppService)
- [x] MAS track: `VaultBreak/VaultBreakMAS.entitlements` with sandbox **true**, `network.client`, `keychain-access-groups`
- [x] Wire entitlements in `project.yml` — Debug/Release → Direct; `ReleaseMAS` → MAS + `VAULTBREAK_MAS`
- [x] Confirm Hardened Runtime remains on for the MAS archive (ReleaseMAS inherits ENABLE_HARDENED_RUNTIME)
- [x] SMAppService not required for MAS v1 (sandbox MAS uses in-app device auth; no login-item entitlement added)

### 2. Keychain — stop shelling out to `/usr/bin/security`

`SystemKeychainSessionDataSource` prefers `Process` → `/usr/bin/security` for the Direct track (go-keyring ACL). **Sandbox blocks this on MAS.**

- [x] MAS build (`VAULTBREAK_MAS`) defaults to **SecItem-only** (`SecItemKeychainSessionDataSource`) — no `Process`
- [x] Dual-track isolates CLI-created Keychain items: MAS does not share with Homebrew CLI
- [x] Unit tests cover SecItem round-trip (`KeychainSessionStoreTests`)

### 3. CLI / session sharing strategy

- [x] **B — Dual track** (confirmed): GitHub build keeps CLI Keychain sharing; MAS build is SecItem-only + in-app device auth (no CLI Keychain share)

### 4. Menu-bar (`LSUIElement`) review risk

- [ ] Decide Dock / primary UI story for review (mini-console as first window, optional Dock icon when console opens)
- [ ] Ensure a reviewer can complete: install → sign in → view secret → lock with Touch ID → sign out without needing the CLI
- [ ] Smoke-test cold launch with no prior Keychain session

---

## Engineering checklist

- [x] Separate Xcode configuration / scheme: `Release` (direct) vs `ReleaseMAS` + scheme `VaultBreakMAS`
- [x] `ExportOptions-MAS.plist` with `method = app-store-connect`, team `647LMXX4U7`
- [x] Development Team + Apple Distribution certificate installed (team `647LMXX4U7`)
- [x] Mac App Store provisioning profile **VaultBreak Mac App Store** (`UJCGYA65N6`)
- [x] Archive + upload to App Store Connect (`VaultBreakMAS` / `ReleaseMAS` → build **2** VALID, attached to version **1.0**)
- [x] No private APIs; no unsigned nested binaries (MAS pkg upload accepted)
- [x] ATS: HTTPS only to VaultBreak API (already the case for production)
- [x] Privacy usage strings present (`NSFaceIDUsageDescription` already in `Info.plist`)
- [x] Version / build numbers map to ASC (`MARKETING_VERSION` 1.0 / `CURRENT_PROJECT_VERSION` 2)

- [ ] Optional: CI job that archives MAS build (upload still manual or via API key)

---

## App Store Connect / business checklist

- [x] Apple Developer Program membership (paid, active) — Team ID `647LMXX4U7`, enrolled as **Individual**, renews 2027-03-23
- [x] Account Holder Apple ID primary email set to `rick.sanchez@brainbreaking.com` (Option 1 — same Team ID)
- [ ] Confirm ASC seller / display name (Individual legal name vs “BrainBreaking” branding — may need DBA / company transfer later)
- [x] App record created in App Store Connect (Mac platform)
- [x] Agreements, tax, banking current
- [x] Privacy Policy URL: `https://vault.brainbreaking.com/legal/privacy` (seed + public page; deploy before ASC submit)
- [x] Support URL / marketing URL (ASC Steps 1–8)
- [x] Age rating questionnaire
- [x] App Privacy (“nutrition labels”) — **Published** (Name + Email, App Functionality, linked; tracking No)
- [x] Export compliance / encryption answers — ASC build `usesNonExemptEncryption=false`
- [x] Screenshots for required Mac sizes — 3× `APP_DESKTOP` 1280×800 COMPLETE via ASC API
- [x] App description, keywords, category (e.g. Productivity / Utilities) — en-US filled via ASC API
- [x] Reviewer demo account set in ASC App Review Information
- [x] Review Notes set in ASC
- [x] Pricing / availability set in ASC

---

## Demo account + Review Notes

VaultBreak production login is **Google only** (no email/password form). Apple still needs Sign-in Information on the version page. Use a dedicated Google account for review.

### Create the demo account — **done** (2026-10-17)

1. [x] Google account: `vaultbreak.asc.review@gmail.com`
2. [x] 2FA off for the review window
3. [x] Production member **approved** + terms accepted
4. [x] Demo secret created (Secrets non-empty)
5. [x] Demo handoff created
6. [x] ASC Sign-in Information = that Google email / password
7. [x] Review Notes in ASC

Do **not** use `AUTH_DEV_BYPASS` on production. Do **not** put personal admin credentials in ASC.

Keep this account working (approved + seeded) while Apple reviews.

### Review Notes (paste into ASC)

```text
VaultBreak is a menu-bar companion for https://vault.brainbreaking.com (secrets vault + handoffs).

API base: https://vault.brainbreaking.com
Privacy: https://vault.brainbreaking.com/legal/privacy
Support: ops@brainbreaking.com

SIGN-IN (required)
Web and device approval use Google Sign-In (no in-app password field).
Demo Google account is in Sign-in Information (Username = Google email, Password = Google password).
Please use that account only; do not require 2FA.

MAC APP FLOW
1. Launch VaultBreak — icon appears in the menu bar (LSUIElement).
2. Open the menu → Sign in…
3. Browser opens a VaultBreak device-authorization URL.
4. Sign in with the demo Google account if prompted, then Approve the device.
5. Return to the menu bar app — it should show signed-in (email).
6. Open Secrets (popover or mini-console) — demo secrets are pre-seeded.
7. Unlock with Touch ID / Mac password if prompted (local only; we never receive biometrics).
8. Management opens the web overview in the browser.
9. Log out from the menu to clear the session.

No CLI is required for this App Store build.
No in-app purchases.
Sandbox build uses in-app device auth only (no shared Keychain with Homebrew CLI).
```

---

## Explicitly out of scope for v1 MAS (unless decided otherwise)

- CI auto-submit to App Store
- Notarized DMG replaced by Store-only distribution
- Shared Keychain with unsigned / Homebrew CLI inside the sandboxed app
- iOS / iPadOS companion

---

## Submit status

- [x] Submit for Review — version 1.0 build **2** `WAITING_FOR_REVIEW` (2026-10-19 via ASC API; submission `4dea5873-…`; includes menu-bar contrast fix)

## Related docs

- [asc-setup-steps.md](./asc-setup-steps.md) — App Store Connect click-path (Bundle ID → listing)
- [signing-and-notarization.md](./signing-and-notarization.md) — direct distribution
- README Distribution section — GitHub Releases URL

