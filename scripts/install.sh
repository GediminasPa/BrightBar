#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build-app.sh"

rm -rf "/Applications/BrightBar.app"
cp -R "$ROOT/dist/BrightBar.app" "/Applications/BrightBar.app"

echo "Installed /Applications/BrightBar.app"
echo "Open BrightBar from Applications, then use the sun icon in the menu bar."
