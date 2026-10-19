# App Store Connect setup — VaultBreak (Mac)

Hand-held steps to create the Mac App Store listing. Engineering (sandbox / SecItem) is separate — see [app-store-checklist.md](./app-store-checklist.md).

**Team:** `647LMXX4U7`  
**Account Holder:** `rick.sanchez@brainbreaking.com`  
**Bundle ID:** `com.brainbreaking.vaultbreak`

---

## Values cheat sheet

| Field | Value |
|-------|--------|
| Bundle ID | `com.brainbreaking.vaultbreak` |
| App name | VaultBreak |
| Platform | macOS |
| Primary language | English (U.S.) |
| SKU | `vaultbreak-mac` (or any unique string you prefer) |
| Privacy Policy URL | `https://vault.brainbreaking.com/legal/privacy` |
| Support URL | `https://vault.brainbreaking.com` |
| Marketing URL (optional) | `https://www.brainbreaking.com` or leave blank |
| Contact email | `ops@brainbreaking.com` |
| Age Suitability URL | **Leave blank** |
| Category (suggested) | Productivity (secondary: Utilities) |

---

## Step 0 — Prerequisites

1. Sign in at [developer.apple.com](https://developer.apple.com) and [appstoreconnect.apple.com](https://appstoreconnect.apple.com) as Account Holder (or Admin).
2. Confirm membership is **Active** (Team `647LMXX4U7`).
3. Confirm Privacy Policy loads: [vault.brainbreaking.com/legal/privacy](https://vault.brainbreaking.com/legal/privacy).

---

## Step 1 — Agreements, tax, banking

1. Open [App Store Connect](https://appstoreconnect.apple.com) → **Business** (or **Agreements, Tax, and Banking**).
2. Accept any pending **Paid Applications** / **Free Applications** agreements.
3. Complete tax and banking if you will charge (or prepare Free + no IAP for v1).

---

## Step 2 — Register the Bundle ID

1. Open [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).
2. Click **+** → **App IDs** → **Continue**.
3. Select **App** → **Continue**.
4. Fill in:
   - **Description:** `VaultBreak`
   - **Bundle ID:** Explicit → `com.brainbreaking.vaultbreak`
5. Capabilities (enable only what you need later):
   - For v1 MAS you can leave most off; Keychain / App Groups can be added when you wire the sandboxed build.
6. **Continue** → **Register**.

> Must match `PRODUCT_BUNDLE_IDENTIFIER` / `project.yml` exactly.

---

## Step 3 — Create the app record

1. App Store Connect → **My Apps** → **+** → **New App**.
2. Select **macOS**.
3. Fill in:
   - **Name:** VaultBreak  
   - **Primary Language:** English (U.S.)  
   - **Bundle ID:** choose `com.brainbreaking.vaultbreak`  
   - **SKU:** `vaultbreak-mac`  
   - **User Access:** Full Access (unless you restrict)
4. **Create**.

---

## Step 4 — App Information

Path: **My Apps** → **VaultBreak** → **App Information** (under General).

| Field | What to enter |
|-------|----------------|
| Name | VaultBreak |
| Subtitle (optional) | Short tagline if you want one |
| Privacy Policy URL | `https://vault.brainbreaking.com/legal/privacy` |
| Category | Productivity / Utilities |
| **Age Suitability URL** | **Leave empty** (optional; not your Privacy Policy) |
| Content Rights | Answer per your assets |

### Age Suitability URL (optional) — detail

- Apple uses this for a **developer-hosted page about age / content suitability** (e.g. social / region rules).
- It is **not** required for VaultBreak.
- Do **not** paste the Privacy Policy URL here.
- Leave blank unless you later publish a dedicated age-suitability page.

Save when done.

---

## Step 5 — Age rating

1. Still under App Information (or **Age Rating** / questionnaire link).
2. Complete the questionnaire honestly (secrets vault / productivity — typically low age rating; no unrestricted web, gambling, etc.).
3. Save.

---

## Step 6 — App Privacy (nutrition labels) — **done (Published 2026-10-17)**

ASC API cannot set or publish App Privacy (`appDataUsages` is web-only). Publish in the web UI cleared `APP_DATA_USAGES_REQUIRED`.

**Published answers (v1):** Name + Email Address — App Functionality — Linked to user — Tracking **No**.

| Item | Value |
|------|--------|
| URL | [App Privacy — VaultBreak](https://appstoreconnect.apple.com/apps/6823775554/appPrivacy) |
| Policy | [vault.brainbreaking.com/legal/privacy](https://vault.brainbreaking.com/legal/privacy) |

---

## Step 7 — Pricing and availability

1. **Pricing and Availability**.
2. Choose **Free** (or Paid if decided).
3. Select territories (All or subset).
4. Save.

---

## Step 8 — Version / listing metadata

Create or open the first version (e.g. **1.0** Prepare for Submission).

Fill:

| Field | Suggested |
|-------|-----------|
| Description | What VaultBreak does (menu bar vault companion, sign-in, secrets, lock) |
| Keywords | vault, secrets, password, mac, menu bar, … |
| Support URL | `https://vault.brainbreaking.com` |
| Marketing URL | optional |
| Copyright | `© 2026 BrainBreaking` (or your legal name) |
| Review Notes | Paste template from [app-store-checklist.md](./app-store-checklist.md) § Demo account + Review Notes |
| Demo account | Dedicated Google account (approved member) → ASC Sign-in Information Username/Password; same email in Review Notes |

### Screenshots — **done (ASC API)**

| Item | Value |
|------|--------|
| Display type | `APP_DESKTOP` (only Mac type the API accepts; `MAC_PROFILE` is not createable) |
| Set id | `5504bf2e-6bb5-4cc8-898e-6d0fd6c3ef82` |
| Size | 1280×800 PNG ×3 |
| Local files | `build/asc-screenshots/{01-tray-secrets,02-console,03-signin}.png` |
| Asset state | all **COMPLETE** (cleared prior `SCREENSHOT_REQUIRED`) |

### Export compliance

- Answer encryption questions in ASC (or set `ITSAppUsesNonExemptEncryption` in Info.plist later). Typical HTTPS-only apps often qualify for the standard exemption — answer accurately for your build.

---

## Step 9 — Build upload

**Done via ASC API + local signing (2026-10-17):**

| Item | Value |
|------|--------|
| Archive | `build/VaultBreakMAS.xcarchive` (scheme `VaultBreakMAS` / `ReleaseMAS`) |
| Signing | Apple Distribution + profile **VaultBreak Mac App Store** |
| Installer | Mac Installer Distribution (ASC cert; export uses `3rd Party Mac Developer Installer`) |
| Upload | `xcodebuild -exportArchive` + `ExportOptions-MAS.plist` (`destination=upload`) |
| Build (initial) | ASC id `9d73b1ca-db92-489d-a70e-0187e98f4f55` — CFBundleVersion **1**, state **VALID** |
| Build (current) | ASC id `1fc1a66a-7b23-4e64-a4ec-03b49912c353` — CFBundleVersion **2**, state **VALID**, attached to **1.0** |
| Export compliance | `usesNonExemptEncryption=false` set on build 2 |
| Copyright | `2026 BrainBreaking` |
| en-US localization | description / keywords / marketing + support URLs filled |
| Review detail | demo Google account + Review Notes already set in ASC |

Build **2** includes the menu-bar secret contrast fix (`.preferredColorScheme(.dark)` on MenuBarExtra).

**Re-upload command (when you need a new build):**

```bash
xcodebuild -scheme VaultBreakMAS -configuration ReleaseMAS \
  -destination 'generic/platform=macOS' \
  -archivePath "$PWD/build/VaultBreakMAS.xcarchive" archive

xcodebuild -exportArchive \
  -archivePath "$PWD/build/VaultBreakMAS.xcarchive" \
  -exportOptionsPlist ExportOptions-MAS.plist \
  -exportPath "$PWD/build/mas-export"
```

**Submit for Review — resubmitted (ASC API 2026-10-19):**

| Item | Value |
|------|--------|
| Prior submission | `8330f311-f434-431a-8906-2b2fbe0c8d0d` — cancelled (`COMPLETE` / developer rejected) to swap builds |
| Review submission | `4dea5873-2f7e-4a1e-b756-b0ed1c4dcf64` |
| Submitted | `2026-10-19T20:52:07Z` |
| Submission state | `WAITING_FOR_REVIEW` |
| Version 1.0 state | `WAITING_FOR_REVIEW` |
| Attached build | CFBundleVersion **2** (`1fc1a66a-…`) |

Demo Google account ready while Apple reviews: `vaultbreak.asc.review@gmail.com` — approved member, demo secret + handoff seeded (2026-10-17).

---

## Progress checklist

- [x] Step 1 — Agreements / tax / banking
- [x] Step 2 — Bundle ID registered
- [x] Step 3 — App record created
- [x] Step 4 — App Information (Privacy URL set; Age Suitability **blank**)
- [x] Step 5 — Age rating questionnaire
- [x] Step 6 — App Privacy labels **Published**
- [x] Step 7 — Pricing / availability
- [x] Step 8 — Version metadata + Review Notes + `APP_DESKTOP` screenshots (COMPLETE)
- [x] Step 9 — MAS build **2** uploaded + attached to 1.0 (contrast fix)
- [x] Submit for Review — `WAITING_FOR_REVIEW` (2026-10-19; submission `4dea5873-…`)


---

## Related

- [app-store-checklist.md](./app-store-checklist.md) — engineering + business blockers
- [signing-and-notarization.md](./signing-and-notarization.md) — Developer ID track (not MAS)
