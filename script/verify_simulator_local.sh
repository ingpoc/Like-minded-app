#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="${BUNDLE_ID:-com.likeminded.app}"
OUT_DIR="$ROOT_DIR/output/validation"
API_LOG="$OUT_DIR/local-auth-api.log"

mkdir -p "$OUT_DIR"

"$ROOT_DIR/script/build_and_run.sh" --verify
xcrun simctl io booted screenshot "$OUT_DIR/fresh-auth-gate.png"

(
  cd "$ROOT_DIR"
  exec npm run dev:api:local-auth
) >"$API_LOG" 2>&1 &
api_pid=$!
cleanup() {
  kill "$api_pid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for _ in {1..20}; do
  if curl -fsS http://127.0.0.1:8787/health >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

curl -fsS http://127.0.0.1:8787/health >/dev/null
xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" --likeminded-reset-auth-session --likeminded-dev-auth-bypass --likeminded-dev-voice-placement >/dev/null
sleep 4
xcrun simctl io booted screenshot "$OUT_DIR/local-dev-auth-tabs.png"

echo "Local simulator validation screenshots:"
echo "  $OUT_DIR/fresh-auth-gate.png"
echo "  $OUT_DIR/local-dev-auth-tabs.png"
