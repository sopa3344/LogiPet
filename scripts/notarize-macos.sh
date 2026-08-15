#!/bin/bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: notarize-macos.sh <app> <archive> <private-key> <key-id> <issuer-id>" >&2
  exit 2
fi

APP="$1"
ARCHIVE="$2"
PRIVATE_KEY="$3"
KEY_ID="$4"
ISSUER_ID="$5"

xcrun notarytool submit "$ARCHIVE" \
  --key "$PRIVATE_KEY" \
  --key-id "$KEY_ID" \
  --issuer "$ISSUER_ID" \
  --wait

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"

spctl --assess --type execute --verbose=4 "$APP"
