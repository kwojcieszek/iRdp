#!/bin/bash
# Builds iRdp.app (menu bar app + iRdpService LaunchAgent) into src/.build/app.
# Usage: Scripts/build-app.sh [--install]   (--install copies the app to /Applications)
# Set CODESIGN_IDENTITY to choose the signing identity; defaults to the first Apple Development / Developer ID identity, or ad-hoc.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
OUTPUT="$ROOT/.build/app"
# Assemble and sign outside of folders synced by File Provider (e.g. iCloud Desktop), which add Finder metadata that codesign rejects.
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/irdp-app.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/iRdp.app"

swift build -c "$CONFIGURATION" --package-path "$ROOT" --product iRdp
swift build -c "$CONFIGURATION" --package-path "$ROOT" --product iRdpService
BIN="$(swift build -c "$CONFIGURATION" --package-path "$ROOT" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Library/LaunchAgents" "$APP/Contents/Resources"
cp "$BIN/iRdp" "$BIN/iRdpService" "$APP/Contents/MacOS/"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/com.kwojcieszek.irdp.service.plist" "$APP/Contents/Library/LaunchAgents/"

IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development|Developer ID Application/ { print $2; exit }')}"
IDENTITY="${IDENTITY:--}"
xattr -cr "$APP"
echo "Signing with: $IDENTITY"
codesign --force --options runtime --timestamp=none --identifier com.kwojcieszek.irdp.service --sign "$IDENTITY" "$APP/Contents/MacOS/iRdpService"
codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

mkdir -p "$OUTPUT"
rm -rf "$OUTPUT/iRdp.app"
ditto "$APP" "$OUTPUT/iRdp.app"
echo "Built $OUTPUT/iRdp.app"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf /Applications/iRdp.app
    ditto "$APP" /Applications/iRdp.app
    echo "Installed /Applications/iRdp.app"
fi
