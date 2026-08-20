#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: package-macos-dmg.sh <app-path> <output-name>" >&2
  exit 2
fi

[[ "$(uname -s)" == "Darwin" ]] || {
  echo "This packaging script requires macOS." >&2
  exit 1
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
OUTPUT_NAME="$2"
OUTPUT_PATH="$ROOT/dist/$OUTPUT_NAME.dmg"
VOLUME_NAME="LogiPet Installer"

[[ -d "$APP_PATH" ]] || {
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/logipet-dmg.XXXXXX")"
MOUNT_DEVICE=""
cleanup() {
  if [[ -n "$MOUNT_DEVICE" ]]; then
    hdiutil detach "$MOUNT_DEVICE" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

STAGING_DIR="$WORK_DIR/volume"
READ_WRITE_DMG="$WORK_DIR/LogiPet-read-write.dmg"
mkdir -p "$STAGING_DIR" "$ROOT/dist"

ditto "$APP_PATH" "$STAGING_DIR/LogiPet.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$READ_WRITE_DMG" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$READ_WRITE_DMG")"
MOUNT_DEVICE="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS|Apple_APFS/ { print $1; exit }')"
[[ -n "$MOUNT_DEVICE" ]] || {
  echo "Could not determine the mounted DMG device." >&2
  exit 1
}

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set pathbar visible of container window to false
    set bounds of container window to {200, 200, 760, 560}
    set arrangement of icon view options of container window to not arranged
    set icon size of icon view options of container window to 96
    set text size of icon view options of container window to 13
    set position of item "LogiPet.app" of container window to {150, 175}
    set position of item "Applications" of container window to {410, 175}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

hdiutil detach "$MOUNT_DEVICE" >/dev/null
MOUNT_DEVICE=""

rm -f "$OUTPUT_PATH"
hdiutil convert "$READ_WRITE_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT_PATH" >/dev/null

hdiutil verify "$OUTPUT_PATH" >/dev/null
echo "Created $OUTPUT_PATH"
