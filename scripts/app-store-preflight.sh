#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
API_BASE_URL="${API_BASE_URL:-https://vault.brainbreaking.com}"
REQUIRE_APPLE_SIGN_IN="${REQUIRE_APPLE_SIGN_IN:-1}"
PREFLIGHT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vaultbreak-preflight.XXXXXX")"
DERIVED_DATA="$PREFLIGHT_DIR/DerivedData"
ARCHIVE_PATH="$PREFLIGHT_DIR/VaultBreakMAS.xcarchive"
PROVIDERS_JSON="$PREFLIGHT_DIR/providers.json"
BUILD_SETTINGS="$PREFLIGHT_DIR/build-settings.txt"
FAILURES=0

cleanup() {
    rm -rf -- "$PREFLIGHT_DIR"
}
trap cleanup EXIT

pass() {
    printf '✅ %s\n' "$1"
}

fail() {
    printf '❌ %s\n' "$1" >&2
    FAILURES=$((FAILURES + 1))
}

expect_value() {
    local description="$1"
    local actual="$2"
    local expected="$3"
    if [ "$actual" = "$expected" ]; then
        pass "$description"
    else
        fail "$description (expected '$expected', got '$actual')"
    fi
}

expect_file_contains() {
    local description="$1"
    local pattern="$2"
    local file="$3"
    if grep -Eq "$pattern" "$file"; then
        pass "$description"
    else
        fail "$description"
    fi
}

http_status() {
    local method="$1"
    local path="$2"
    local output="$3"
    curl --silent --show-error --location \
        --proto '=https' --tlsv1.2 \
        --request "$method" \
        --output "$output" \
        --write-out '%{http_code}' \
        "$API_BASE_URL$path"
}

cd "$PROJECT_ROOT"

printf '\nVaultBreak App Store preflight\n'
printf 'Production: %s\n\n' "$API_BASE_URL"

printf '1. Unit and integration tests\n'
xcodebuild test \
    -project VaultBreak.xcodeproj \
    -scheme VaultBreak \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet
pass 'macOS XCTest suite passed'

printf '\n2. ReleaseMAS configuration and archive\n'
xcodebuild \
    -project VaultBreak.xcodeproj \
    -scheme VaultBreakMAS \
    -configuration ReleaseMAS \
    -showBuildSettings > "$BUILD_SETTINGS"

expect_file_contains \
    'ReleaseMAS uses Mac App Store entitlements' \
    'CODE_SIGN_ENTITLEMENTS = VaultBreak/VaultBreakMAS.entitlements' \
    "$BUILD_SETTINGS"
expect_file_contains 'App Sandbox is enabled' 'ENABLE_APP_SANDBOX = YES' "$BUILD_SETTINGS"
expect_file_contains \
    'APP_STORE compilation condition is enabled' \
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS = .*APP_STORE' \
    "$BUILD_SETTINGS"
expect_file_contains \
    'Bundle identifier is correct' \
    'PRODUCT_BUNDLE_IDENTIFIER = com.brainbreaking.vaultbreak' \
    "$BUILD_SETTINGS"

xcodebuild archive \
    -project VaultBreak.xcodeproj \
    -scheme VaultBreakMAS \
    -configuration ReleaseMAS \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

APP_PATH="$ARCHIVE_PATH/Products/Applications/VaultBreak.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
BINARY="$APP_PATH/Contents/MacOS/VaultBreak"
if [ -x "$BINARY" ]; then
    pass 'ReleaseMAS archive contains an executable app'
else
    fail 'ReleaseMAS archive is missing its executable'
fi

expect_value \
    'Archived bundle identifier is correct' \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")" \
    'com.brainbreaking.vaultbreak'
expect_value \
    'Archived app is a menu-bar application' \
    "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$INFO_PLIST")" \
    'true'
expect_value \
    'Mac App Store entitlement enables sandboxing' \
    "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' VaultBreak/VaultBreakMAS.entitlements)" \
    'true'
expect_value \
    'Mac App Store entitlement allows production networking' \
    "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.network.client' VaultBreak/VaultBreakMAS.entitlements)" \
    'true'

if strings "$BINARY" | grep -q 'VAULTBREAK_API_BASE_URL'; then
    fail 'ReleaseMAS binary contains the Debug API override key'
else
    pass 'ReleaseMAS binary excludes the Debug API override'
fi

printf '\n3. Production smoke tests\n'
HOME_STATUS="$(http_status GET / "$PREFLIGHT_DIR/home.html")"
expect_value 'Production home page responds' "$HOME_STATUS" '200'

PROVIDERS_STATUS="$(http_status GET /api/auth/providers "$PROVIDERS_JSON")"
expect_value 'Authentication provider endpoint responds' "$PROVIDERS_STATUS" '200'

if /usr/bin/plutil -extract google.id raw -o - "$PROVIDERS_JSON" >/dev/null 2>&1; then
    pass 'Google sign-in is advertised'
else
    fail 'Google sign-in is missing'
fi

if /usr/bin/plutil -extract apple.id raw -o - "$PROVIDERS_JSON" >/dev/null 2>&1; then
    pass 'Sign in with Apple is advertised'
elif [ "$REQUIRE_APPLE_SIGN_IN" = '1' ]; then
    fail 'Sign in with Apple is missing (set REQUIRE_APPLE_SIGN_IN=0 only for interim runs)'
else
    printf '⚠️  Sign in with Apple is not configured; allowed by this interim run.\n'
fi

ME_STATUS="$(http_status GET /api/me "$PREFLIGHT_DIR/me.json")"
expect_value 'Account endpoint rejects unauthenticated access' "$ME_STATUS" '401'

DELETE_AUTH_STATUS="$(http_status POST /api/v1/account/deletion-authorization "$PREFLIGHT_DIR/delete-auth.json")"
expect_value 'Deletion authorization rejects unauthenticated access' "$DELETE_AUTH_STATUS" '401'

DELETE_STATUS="$(http_status DELETE /api/account "$PREFLIGHT_DIR/delete.json")"
expect_value 'Account deletion rejects unauthenticated access' "$DELETE_STATUS" '401'

printf '\n4. Manual security gates (intentionally not automated)\n'
printf '• Log out and back in to macOS after explicitly enabling Launch at Login.\n'
printf '• Complete Google and Apple credential entry in ASWebAuthenticationSession.\n'
printf '• Exercise Touch ID success, cancellation, and password fallback.\n'
printf '• Delete only a disposable production account and verify it cannot sign in again.\n'

if [ "$FAILURES" -ne 0 ]; then
    printf '\nPreflight failed with %d issue(s).\n' "$FAILURES" >&2
    exit 1
fi

printf '\n✅ App Store preflight passed.\n'
