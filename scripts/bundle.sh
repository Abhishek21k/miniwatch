#!/usr/bin/env bash
# Builds miniwatch.app with only the Command Line Tools (no Xcode needed).
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG" --product miniwatch
BIN="$(swift build -c "$CONFIG" --show-bin-path)/miniwatch"

APP="build/miniwatch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/miniwatch"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature: enough to run locally and to register as a login item.
codesign --force --sign - "$APP"
echo "Built $APP"
