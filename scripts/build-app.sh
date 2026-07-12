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

codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with: open '$APP'"
