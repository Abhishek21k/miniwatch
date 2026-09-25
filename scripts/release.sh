#!/usr/bin/env bash
# Builds a universal miniwatch.app and zips it for a GitHub release.
#
#   scripts/release.sh
#   gh release create "v$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)" dist/*
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/bundle.sh release

rm -rf dist
mkdir -p dist
# The installer downloads this exact name from the latest release.
ditto -c -k --sequesterRsrc --keepParent build/miniwatch.app dist/miniwatch.zip
(cd dist && shasum -a 256 miniwatch.zip > miniwatch.zip.sha256)

VERSION="$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)"
echo "miniwatch $VERSION → dist/miniwatch.zip"
cat dist/miniwatch.zip.sha256
