#!/usr/bin/env bash
# Regenerate AppIcon.appiconset PNGs + Resources/DockIcon.icns from scripts/appicon.svg
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/scripts/appicon.svg"
SET="$ROOT/VaultBreak/Assets.xcassets/AppIcon.appiconset"
RES="$ROOT/VaultBreak/Resources"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert required (brew install librsvg)" >&2
  exit 1
fi

render() {
  local px="$1" name="$2"
  rsvg-convert -w "$px" -h "$px" "$SVG" -o "$TMP/$name"
  sips -s format png "$TMP/$name" --out "$SET/$name" >/dev/null
}

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
render 1024 icon_512x512@2x.png

mkdir -p "$TMP/iconset.iconset" "$RES"
cp "$SET"/icon_*.png "$TMP/iconset.iconset/"
iconutil -c icns "$TMP/iconset.iconset" -o "$RES/DockIcon.icns"
echo "Wrote $SET and $RES/DockIcon.icns"
