#!/bin/bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: package-macos.sh <executable> <resource-bundle> <output-name>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXECUTABLE="$1"
RESOURCE_BUNDLE="$2"
OUTPUT_NAME="$3"
APP="$ROOT/dist/LogiPet-macOS.app"

rm -rf "$APP" "$ROOT/dist/$OUTPUT_NAME.zip"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXECUTABLE" "$APP/Contents/MacOS/LogiPetMac"
cp "$ROOT/LogiPetMac/Packaging/Info.plist" "$APP/Contents/Info.plist"
cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
chmod +x "$APP/Contents/MacOS/LogiPetMac"
codesign --force --deep --sign - "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/$OUTPUT_NAME.zip"
