#!/usr/bin/env bash
# Installs the latest miniwatch release into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/Abhishek21k/miniwatch/main/scripts/install.sh | bash
#
# miniwatch isn't notarized, so a copy downloaded in a browser gets blocked by Gatekeeper.
# Fetching it with curl sidesteps that; this script also clears the quarantine flag to be sure.
set -euo pipefail

REPO="Abhishek21k/miniwatch"
URL="${MINIWATCH_URL:-https://github.com/$REPO/releases/latest/download/miniwatch.zip}"
DEST="/Applications"

fail() { echo "miniwatch: $*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || fail "this is a macOS app."
major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 14 ] || fail "needs macOS 14 (Sonoma) or later; this Mac has $(sw_vers -productVersion)."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading miniwatch…"
curl -fsSL "$URL" -o "$tmp/miniwatch.zip" || fail "download failed: $URL"
if curl -fsSL "$URL.sha256" -o "$tmp/miniwatch.zip.sha256" 2>/dev/null; then
    (cd "$tmp" && shasum -a 256 -c miniwatch.zip.sha256 >/dev/null) || fail "checksum mismatch; try again."
fi
ditto -x -k "$tmp/miniwatch.zip" "$tmp"
[ -d "$tmp/miniwatch.app" ] || fail "the download didn't contain miniwatch.app."

SUDO=""
if [ ! -w "$DEST" ] || { [ -e "$DEST/miniwatch.app" ] && [ ! -w "$DEST/miniwatch.app" ]; }; then
    echo "Installing into $DEST needs your password."
    SUDO="sudo"
fi

pkill -x miniwatch 2>/dev/null || true
$SUDO rm -rf "$DEST/miniwatch.app"
$SUDO ditto "$tmp/miniwatch.app" "$DEST/miniwatch.app"
$SUDO xattr -dr com.apple.quarantine "$DEST/miniwatch.app" 2>/dev/null || true

open "$DEST/miniwatch.app"
echo "Installed miniwatch to $DEST. Look for the stopwatch in your menu bar."
