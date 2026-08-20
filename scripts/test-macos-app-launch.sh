#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: test-macos-app-launch.sh <app-path>" >&2
  exit 2
fi

APP_PATH="$1"
EXECUTABLE="$APP_PATH/Contents/MacOS/LogiPetMac"
LOG_FILE="$(mktemp "${TMPDIR:-/tmp}/logipet-launch.XXXXXX")"
PID=""

cleanup() {
  if [[ -n "$PID" ]] && kill -0 "$PID" >/dev/null 2>&1; then
    kill "$PID" >/dev/null 2>&1 || true
    wait "$PID" >/dev/null 2>&1 || true
  fi
  rm -f "$LOG_FILE"
}
trap cleanup EXIT

[[ -x "$EXECUTABLE" ]] || {
  echo "App executable not found: $EXECUTABLE" >&2
  exit 1
}

"$EXECUTABLE" >"$LOG_FILE" 2>&1 &
PID="$!"

for _ in {1..10}; do
  sleep 0.5
  if ! kill -0 "$PID" >/dev/null 2>&1; then
    echo "LogiPet exited during launch smoke test." >&2
    cat "$LOG_FILE" >&2
    wait "$PID" || true
    exit 1
  fi
done

echo "LogiPet stayed running for 5 seconds."
