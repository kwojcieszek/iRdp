#!/bin/bash
# Builds iRdp.app (menu bar app + iRdpService LaunchAgent) from iRdp.xcworkspace into src/.build/app.
# Usage: Scripts/build-app.sh [--install]   (--install copies the app to /Applications)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Release}"
OUTPUT="$ROOT/.build/app"
# Build outside of folders synced by File Provider (e.g. iCloud Desktop), which add Finder metadata that codesign rejects.
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/irdp-app.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

xcodebuild -workspace "$ROOT/iRdp.xcworkspace" -scheme iRdp -configuration "$CONFIGURATION" \
    -derivedDataPath "$STAGING/DerivedData" -quiet build
APP="$STAGING/DerivedData/Build/Products/$CONFIGURATION/iRdp.app"
codesign --verify --deep --strict "$APP"

mkdir -p "$OUTPUT"
rm -rf "$OUTPUT/iRdp.app"
ditto "$APP" "$OUTPUT/iRdp.app"
echo "Built $OUTPUT/iRdp.app"

if [[ "${1:-}" == "--install" ]]; then
    /Applications/iRdp.app/Contents/MacOS/iRdp --stop-service 2>/dev/null || true
    pkill -x iRdp 2>/dev/null || true
    rm -rf /Applications/iRdp.app
    ditto "$APP" /Applications/iRdp.app
    echo "Installed /Applications/iRdp.app"
fi
