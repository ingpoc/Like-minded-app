#!/usr/bin/env bash
# Quick local-auth smoke captures. The API owner is explicit so nested callers
# can reuse their server without stopping it.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="${BUNDLE_ID:-com.gurusharan.likeminded}"
PORT="${PORT:-8794}"
API_OWNER="${LIKEMINDED_API_OWNER:-self}"
OUT_DIR="$ROOT_DIR/output/validation"
API_LOG="$OUT_DIR/local-auth-api.log"
DEV_DB_DIR="$OUT_DIR/dev-empty-db"
API_BASE_URL="http://127.0.0.1:$PORT"

mkdir -p "$OUT_DIR"
rm -rf "$DEV_DB_DIR"
api_pid=""
cleanup() {
  if [[ "$API_OWNER" == self && -n "$api_pid" ]] && kill -0 "$api_pid" >/dev/null 2>&1; then
    kill "$api_pid" >/dev/null 2>&1 || true
    wait "$api_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

api_alive() {
  [[ -z "$api_pid" ]] || kill -0 "$api_pid" >/dev/null 2>&1
}
api_health() {
  api_alive || { echo "Local auth API exited early. See $API_LOG" >&2; return 1; }
  curl -fsS "$API_BASE_URL/health" >/dev/null
}

if [[ "$API_OWNER" == parent ]]; then
  api_health || { echo "Parent-owned API is not healthy at $API_BASE_URL" >&2; exit 1; }
else
  if [[ "$API_OWNER" != self ]]; then
    echo "LIKEMINDED_API_OWNER must be self or parent" >&2
    exit 2
  fi
  if curl -fsS "$API_BASE_URL/health" >/dev/null 2>&1; then
    echo "API already occupies $API_BASE_URL; refusing to stop an unowned process" >&2
    exit 1
  fi
  (
    cd "$ROOT_DIR"
    PORT="$PORT" APPLE_AUTH_BYPASS=1 LIKEMINDED_DB_DIR="$DEV_DB_DIR" \
      SESSION_SECRET=local-session-secret-minimum-24-chars \
      exec node services/api/src/server.js
  ) >"$API_LOG" 2>&1 &
  api_pid=$!
  for _ in {1..40}; do
    api_health && break
    sleep 0.25
  done
  api_health || { echo "Local auth API failed to start at $API_BASE_URL" >&2; exit 1; }
fi

PORT="$PORT" "$ROOT_DIR/script/build_and_run.sh" --verify
api_health
xcrun simctl io booted screenshot "$OUT_DIR/fresh-auth-gate.png"

SIMCTL_CHILD_LIKEMINDED_API_BASE_URL="$API_BASE_URL" xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" --likeminded-reset-auth-session --likeminded-dev-auth-bypass --likeminded-start-profile >/dev/null
api_health
sleep 4
xcrun simctl io booted screenshot "$OUT_DIR/local-dev-empty-onboarding.png"
SIMCTL_CHILD_LIKEMINDED_API_BASE_URL="$API_BASE_URL" xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" --likeminded-reset-auth-session --likeminded-dev-auth-bypass --likeminded-dev-voice-placement >/dev/null
api_health
sleep 4
xcrun simctl io booted screenshot "$OUT_DIR/local-dev-auth-tabs.png"

ok=0
for f in "$OUT_DIR"/fresh-auth-gate.png "$OUT_DIR"/local-dev-empty-onboarding.png "$OUT_DIR"/local-dev-auth-tabs.png; do
  size=$(stat -f%z "$f" 2>/dev/null || echo 0)
  if (( size < 10000 )); then echo "WARN: $f is ${size}B — likely blank" >&2; else ok=$((ok + 1)); fi
done

echo "Simulator captures: $ok/3 valid"
echo "  $OUT_DIR/fresh-auth-gate.png"
echo "  $OUT_DIR/local-dev-empty-onboarding.png"
echo "  $OUT_DIR/local-dev-auth-tabs.png"
