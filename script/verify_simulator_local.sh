#!/usr/bin/env bash
# Quick local-auth smoke captures (auth gate + onboarding + tabs).
# NOT for ledger/mockup validation — uses booted simulator and no flock locks.
# For validation-db + deep links use: npm run validate:screen -- --screen <id> --platform ios
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="${BUNDLE_ID:-com.gurusharan.likeminded}"
OUT_DIR="$ROOT_DIR/output/validation"
API_LOG="$OUT_DIR/local-auth-api.log"
DEV_DB_DIR="$OUT_DIR/dev-empty-db"

mkdir -p "$OUT_DIR"
rm -rf "$DEV_DB_DIR"

"$ROOT_DIR/script/build_and_run.sh" --verify
sleep 4
xcrun simctl io booted screenshot "$OUT_DIR/fresh-auth-gate.png"

if curl -fsS http://127.0.0.1:8787/health >/dev/null 2>&1; then
  echo "Port 8787 occupied — killing existing API" >&2
  kill "$(lsof -ti :8787)" >/dev/null 2>&1 || true
  sleep 1
fi

(
  cd "$ROOT_DIR"
  LIKEMINDED_DB_DIR="$DEV_DB_DIR" exec npm run dev:api:local-auth
) >"$API_LOG" 2>&1 &
api_pid=$!
cleanup() {
  kill "$api_pid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for _ in {1..20}; do
  if ! kill -0 "$api_pid" >/dev/null 2>&1; then
    echo "Local auth API exited early. See $API_LOG" >&2
    exit 1
  fi
  if curl -fsS http://127.0.0.1:8787/health >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

curl -fsS http://127.0.0.1:8787/health >/dev/null
xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" --likeminded-reset-auth-session --likeminded-dev-auth-bypass --likeminded-start-profile >/dev/null
sleep 4
xcrun simctl io booted screenshot "$OUT_DIR/local-dev-empty-onboarding.png"
xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" --likeminded-reset-auth-session --likeminded-dev-auth-bypass --likeminded-dev-voice-placement >/dev/null
sleep 4
xcrun simctl io booted screenshot "$OUT_DIR/local-dev-auth-tabs.png"

# Validate screenshots
ok=0
for f in "$OUT_DIR"/fresh-auth-gate.png "$OUT_DIR"/local-dev-empty-onboarding.png "$OUT_DIR"/local-dev-auth-tabs.png; do
  size=$(stat -f%z "$f" 2>/dev/null || echo 0)
  if (( size < 10000 )); then
    echo "WARN: $f is ${size}B — likely blank" >&2
  else
    ok=$((ok + 1))
  fi
done

echo "Simulator captures: $ok/3 valid"
echo "  $OUT_DIR/fresh-auth-gate.png"
echo "  $OUT_DIR/local-dev-empty-onboarding.png"
echo "  $OUT_DIR/local-dev-auth-tabs.png"
