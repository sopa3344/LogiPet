#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: test-macos-app-launch.sh <app-path> [full|resources]" >&2
  exit 2
fi

APP_PATH="$1"
MODE="${2:-full}"
PID=""

cleanup() {
  if [[ -n "$PID" ]] && kill -0 "$PID" >/dev/null 2>&1; then
    kill "$PID" >/dev/null 2>&1 || true
    wait "$PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

EXECUTABLE="$APP_PATH/Contents/MacOS/LogiPetMac"
[[ -x "$EXECUTABLE" ]] || {
  echo "App executable not found: $EXECUTABLE" >&2
  exit 1
}

if [[ "$MODE" == "resources" ]]; then
  LOGIPET_RESOURCE_SMOKE_TEST=1 "$EXECUTABLE" >/dev/null 2>&1 &
  PID="$!"
elif [[ "$MODE" == "full" ]]; then
  /usr/bin/open -n "$APP_PATH"
else
  echo "Unknown smoke-test mode: $MODE" >&2
  exit 2
fi

if [[ "$MODE" == "full" ]]; then
  for _ in {1..10}; do
    sleep 0.5
    PID="$(pgrep -x LogiPetMac | head -1 || true)"
    [[ -n "$PID" ]] && break
  done
fi

if [[ -z "$PID" ]]; then
  echo "LogiPet did not start through LaunchServices." >&2
  /usr/bin/log show --last 1m --style compact --predicate 'process == "LogiPetMac"' >&2 || true
  exit 1
fi

sleep 5
if ! kill -0 "$PID" >/dev/null 2>&1; then
  echo "LogiPet exited during launch smoke test." >&2
  /usr/bin/log show --last 1m --style compact --predicate 'process == "LogiPetMac"' >&2 || true
  exit 1
fi

echo "LogiPet stayed running for 5 seconds."
