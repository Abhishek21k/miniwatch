#!/usr/bin/env bash
# Builds miniwatch.app with only the Command Line Tools (no Xcode needed).
#
#   scripts/bundle.sh            # release build, universal (Apple Silicon + Intel)
#   scripts/bundle.sh debug      # debug build for this Mac only
#   ARCHS=arm64 scripts/bundle.sh
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
if [ "$CONFIG" = release ]; then
    ARCHS="${ARCHS:-arm64 x86_64}"
else
    ARCHS="${ARCHS:-$(uname -m)}"
fi

BINARIES=()
for arch in $ARCHS; do
    triple="$arch-apple-macosx14.0"
    swift build -c "$CONFIG" --product miniwatch --triple "$triple"
    BINARIES+=("$(swift build -c "$CONFIG" --triple "$triple" --show-bin-path)/miniwatch")
done

APP="build/miniwatch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/miniwatch"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature: enough to run locally and to register as a login item.
codesign --force --sign - "$APP"
echo "Built $APP ($ARCHS)"
