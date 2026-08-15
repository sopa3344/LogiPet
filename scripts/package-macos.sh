#!/bin/bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "usage: package-macos.sh <executable> <resource-bundle> <output-name> [signing-identity]" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXECUTABLE="$1"
RESOURCE_BUNDLE="$2"
OUTPUT_NAME="$3"
SIGNING_IDENTITY="${4:--}"
APP="$ROOT/dist/LogiPet-macOS.app"

rm -rf "$APP" "$ROOT/dist/$OUTPUT_NAME.zip"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXECUTABLE" "$APP/Contents/MacOS/LogiPetMac"
cp "$ROOT/LogiPetMac/Packaging/Info.plist" "$APP/Contents/Info.plist"
cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
chmod +x "$APP/Contents/MacOS/LogiPetMac"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP"
else
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$SIGNING_IDENTITY" \
    "$APP"
fi

codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/$OUTPUT_NAME.zip"
