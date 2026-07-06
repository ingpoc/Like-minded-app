#!/usr/bin/env bash
# Prove local iOS simulator + macOS bypass product loop (Phase 1).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

source "$ROOT/script/macos_canonical_app.sh"

echo "=== Phase 1: local product loop ==="

if curl -fsS http://127.0.0.1:8787/health >/dev/null 2>&1; then
  echo "OK: API already running on :8787"
else
  echo "Starting API with .env.local ..."
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env.local"
  set +a
  "$ROOT/script/run_api.sh" &
  api_pid=$!
  trap 'kill "$api_pid" >/dev/null 2>&1 || true' EXIT
  for _ in {1..30}; do
    curl -fsS http://127.0.0.1:8787/health >/dev/null 2>&1 && break
    sleep 0.5
  done
fi

health="$(curl -fsS http://127.0.0.1:8787/health)"
echo "Health: $health"

echo "Running verify:simulator-local ..."
npm run verify:simulator-local

echo "Building macOS app ..."
xcodebuild -project apps/ios-macos/Likeminded.xcodeproj \
  -scheme LikemindedMac \
  -destination 'platform=macOS' \
  -derivedDataPath .build/macos \
  build >/dev/null

macos_kill_all
open -F -n "$MACOS_CANONICAL_APP" --args --likeminded-dev-auth-bypass --mac-screen meet
sleep 5

if pgrep -x LikemindedMac >/dev/null; then
  echo "OK: LikemindedMac running with dev-auth bypass on meet screen"
else
  echo "FAIL: LikemindedMac did not stay running" >&2
  exit 1
fi

echo "Phase 1 local loop verification passed."
