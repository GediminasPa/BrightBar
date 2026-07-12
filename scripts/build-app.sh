#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building BrightBar..."
swift build -c release --product BrightBar

BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$ROOT/dist/BrightBar.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/BrightBar" "$APP/Contents/MacOS/BrightBar"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

RESOURCE_BUNDLE="$BIN_DIR/BrightBar_BrightBarApp.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  mkdir -p "$APP/Contents/Resources"
  cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
fi

codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with: open '$APP'"
