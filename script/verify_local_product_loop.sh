#!/usr/bin/env bash
# Prove local iOS simulator + macOS bypass product loop (Phase 1).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

source "$ROOT/script/macos_canonical_app.sh"
REQUESTED_PORT="${PORT:-8794}"
PORT="$REQUESTED_PORT"
API_BASE_URL="http://127.0.0.1:$PORT"
API_DB_DIR="$ROOT/output/validation/local-product-loop-db"
api_pid=""
api_owner="parent"
cleanup() {
  if [[ -n "$api_pid" ]] && kill -0 "$api_pid" >/dev/null 2>&1; then
    kill "$api_pid" >/dev/null 2>&1 || true
    wait "$api_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "=== Phase 1: local product loop ==="

if curl -fsS "$API_BASE_URL/health" >/dev/null 2>&1; then
  echo "OK: API already running on :$PORT"
else
  echo "Starting API with .env.local ..."
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env.local"
  set +a
  export PORT="$REQUESTED_PORT"
  export APPLE_AUTH_BYPASS=1
  export LIKEMINDED_DB_DIR="$API_DB_DIR"
  mkdir -p "$API_DB_DIR"
  "$ROOT/script/run_api.sh" "$PORT" &
  api_pid=$!
  api_owner="self"
  for _ in {1..40}; do
    if ! kill -0 "$api_pid" >/dev/null 2>&1; then
      echo "API process exited before becoming healthy" >&2
      exit 1
    fi
    curl -fsS "$API_BASE_URL/health" >/dev/null 2>&1 && break
    sleep 0.5
  done
fi

if [[ -n "$api_pid" ]] && ! kill -0 "$api_pid" >/dev/null 2>&1; then
  echo "API process exited before health readback" >&2
  exit 1
fi
health="$(curl -fsS "$API_BASE_URL/health")"
echo "Health: $health"

echo "Running verify:simulator-local ..."
PORT="$PORT" LIKEMINDED_API_OWNER=parent npm run verify:simulator-local

echo "Building macOS app ..."
xcodebuild -project apps/ios-macos/Likeminded.xcodeproj \
  -scheme LikemindedMac \
  -destination 'platform=macOS' \
  -derivedDataPath .build/macos \
  build >/dev/null

macos_kill_all
open -F -n "$MACOS_CANONICAL_APP" --env "LIKEMINDED_API_BASE_URL=$API_BASE_URL" --args --likeminded-dev-auth-bypass --mac-screen meet
sleep 5

if [[ -n "$api_pid" ]] && ! kill -0 "$api_pid" >/dev/null 2>&1; then
  echo "API process exited during simulator/macOS validation" >&2
  exit 1
fi
curl -fsS "$API_BASE_URL/health" >/dev/null

if pgrep -x LikemindedMac >/dev/null; then
  echo "OK: LikemindedMac running with dev-auth bypass on meet screen"
else
  echo "FAIL: LikemindedMac did not stay running" >&2
  exit 1
fi

echo "Phase 1 local loop verification passed."
