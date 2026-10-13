# Signing and notarization (VaultBreak macOS)

This guide covers **Developer ID Application** signing, Apple **notarization**, **stapling**, and **Gatekeeper** expectations for the menu-bar companion (`com.brainbreaking.vaultbreak`). Distribution is via [GitHub Releases](https://github.com/BrainBreaking/VaultBreak-macOS/releases) — the CLI points users to `https://github.com/BrainBreaking/VaultBreak-macOS/releases/latest`.

**Status:** As of Task 16, **no release assets are published yet**. Build and notarize locally (or in CI with Apple credentials), then **manually upload** the first `.dmg` or `.zip` to GitHub Releases. Do not claim a notarized binary exists until it appears on that page.

## Prerequisites

- Apple Developer Program membership
- **Developer ID Application** certificate in Keychain (not “Apple Development”)
- App-specific password or App Store Connect API key for `notarytool`
- Xcode 15+ with command-line tools
- Release build: `xcodebuild -scheme VaultBreak -configuration Release -destination 'platform=macOS' archive`

Bundle ID (from `project.yml`): **`com.brainbreaking.vaultbreak`**

## Release asset naming

Use consistent names so the CLI README and release notes stay predictable:

| Asset | Suggested name | Notes |
|-------|----------------|--------|
| Disk image | `VaultBreak-<semver>.dmg` | Preferred for end users (drag to Applications) |
| Zip | `VaultBreak-<semver>-macOS.zip` | Alternative; must contain `VaultBreak.app` at top level |
| Checksums (optional) | `SHA256SUMS.txt` | One line per file |

Example version `0.1.0`:

- `VaultBreak-0.1.0.dmg`
- `VaultBreak-0.1.0-macOS.zip`

Tag the Git release `v0.1.0` (or match your semver). The **`/releases/latest`** URL redirects to the newest tag.

## 1. Archive and export

```bash
cd /path/to/VaultBreak-macOS
xcodegen generate   # if needed

ARCHIVE_PATH="$PWD/build/VaultBreak.xcarchive"
xcodebuild -scheme VaultBreak \
  -configuration Release \
  -destination 'platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive

# Export a signed .app (Developer ID) via Xcode Organizer or xcodebuild -exportArchive
# with ExportOptions.plist: method = developer-id
```

Ensure **Release** build settings in Xcode use:

- **Code Signing Identity:** Developer ID Application
- **Development Team:** your team ID
- **Hardened Runtime:** ON (required for notarization)

## 2. Codesign the app

If signing outside Xcode’s export step:

```bash
APP="build/export/VaultBreak.app"
IDENTITY="Developer ID Application: Your Name (TEAMID)"

codesign --force --options runtime --deep --sign "$IDENTITY" \
  --entitlements VaultBreak/VaultBreak.entitlements \
  "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute -v "$APP"
```

### Entitlements (Keychain, login item, URL scheme)

The app uses the **generic Keychain** API (`SecItemCopyMatching` / `SecItemDelete`) with service **`com.brainbreaking.vaultbreak`** and account **`session`** — the same blob as `vaultbreak-cli` (go-keyring). There is no separate app group; both processes read the same Keychain item when signed with compatible access.

Recommended **`VaultBreak/VaultBreak.entitlements`** (add to XcodeGen `project.yml` when you formalize signing):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <false/>
  <key>com.apple.security.cs.allow-jit</key>
  <false/>
  <key>com.apple.security.cs.disable-library-validation</key>
  <false/>
  <key>com.apple.security.device.audio-input</key>
  <false/>
  <key>com.apple.security.network.client</key>
  <true/>
  <key>keychain-access-groups</key>
  <array>
    <string>$(AppIdentifierPrefix)com.brainbreaking.vaultbreak</string>
  </array>
</dict>
</plist>
```

Notes:

- **Keychain:** CLI and app must use the same service string; tests assert `KeychainSessionStore.service == "com.brainbreaking.vaultbreak"`.
- **Login Item:** `SMAppService.mainApp` (Task 15) does not require a custom entitlement in most cases; users may need to approve in **System Settings → General → Login Items**.
- **URL scheme:** Registered in `VaultBreak/Info.plist` as `vaultbreak` (`CFBundleURLSchemes`). No extra entitlement beyond correct signing and user launching the app once so macOS registers the handler.
- **LocalAuthentication / Touch ID:** `NSFaceIDUsageDescription` is in `Info.plist` for vault UI lock (Task 11).

Adjust entitlements if you enable **App Sandbox** later — sandboxed apps need explicit Keychain access groups and network client entitlements.

## 3. Package for notarization

Notarization accepts a **zip** of the signed `.app` or a **signed `.dmg`**.

**Zip:**

```bash
VERSION=0.1.0
ditto -c -k --keepParent "$APP" "VaultBreak-${VERSION}-macOS.zip"
```

**DMG (example):**

```bash
hdiutil create -volname VaultBreak -srcfolder "$APP" -ov -format UDZO "VaultBreak-${VERSION}.dmg"
codesign --sign "$IDENTITY" "VaultBreak-${VERSION}.dmg"
```

## 4. Submit with notarytool

Store credentials once (API key recommended for CI):

```bash
# API key (preferred)
xcrun notarytool store-credentials "vaultbreak-notary" \
  --key /path/to/AuthKey_XXXXXXXXXX.p8 \
  --key-id XXXXXXXXXX \
  --issuer YOUR_ISSUER_UUID

# Submit
xcrun notarytool submit "VaultBreak-${VERSION}.dmg" \
  --keychain-profile "vaultbreak-notary" \
  --wait

# Or zip
xcrun notarytool submit "VaultBreak-${VERSION}-macOS.zip" \
  --keychain-profile "vaultbreak-notary" \
  --wait
```

On failure, fetch the log:

```bash
xcrun notarytool log <submission-id> --keychain-profile "vaultbreak-notary"
```

Common fixes: missing hardened runtime, unsigned nested binaries, invalid entitlements, or deprecated APIs.

## 5. Staple the ticket

After **Accepted**, staple notarization to the distributed file:

```bash
xcrun stapler staple "VaultBreak-${VERSION}.dmg"
# or for zip-based distribution, staple the .app inside before re-zipping:
xcrun stapler staple "$APP"
```

Verify:

```bash
xcrun stapler validate "VaultBreak-${VERSION}.dmg"
spctl -a -t open --context context:primary-signature -v "VaultBreak-${VERSION}.dmg"
```

Gatekeeper on other Macs trusts stapled Developer ID software without an immediate online check.

## 6. Publish to GitHub Releases (manual until CI exists)

1. Create a release on [BrainBreaking/VaultBreak-macOS](https://github.com/BrainBreaking/VaultBreak-macOS/releases/new).
2. Upload **`VaultBreak-<version>.dmg`** (and/or zip + checksums).
3. Confirm `https://github.com/BrainBreaking/VaultBreak-macOS/releases/latest` resolves and downloads work.

Without Apple credentials in your environment, stop after producing an **unsigned or ad-hoc** local build for development; still document the asset names above and publish when credentials are available.

## 7. User install path

1. Install `vaultbreak` CLI and run `vaultbreak login`.
2. Download the latest release (or run `vaultbreak app` — prints the releases URL if the app is missing).
3. Drag **VaultBreak.app** to `/Applications`.
4. Open once; enable **Open at Login** in the menu if desired.
5. CLI login/logout sends `vaultbreak://session-updated` so the menu bar refreshes.

## Quick checklist

- [ ] Release archive built with Hardened Runtime
- [ ] Signed with Developer ID Application
- [ ] Entitlements match Keychain + network usage
- [ ] `notarytool submit` → Accepted
- [ ] `stapler staple` on shipped artifact
- [ ] Assets uploaded to GitHub Releases with standard names
- [ ] Smoke test on a clean Mac: open app, `vaultbreak app status`, login flow
