#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8787}"
VALIDATION_DB_DIR="${LIKEMINDED_VALIDATION_DB_DIR:-$ROOT_DIR/data/validation-db}"

if lsof -ti :"$PORT" >/dev/null 2>&1; then
  kill "$(lsof -ti :"$PORT")" 2>/dev/null || true
  sleep 1
fi

cd "$ROOT_DIR"
if [[ -f "$ROOT_DIR/.env.local" ]]; then
  set -a && source "$ROOT_DIR/.env.local" && set +a
fi

export PORT
export LIKEMINDED_DB_DIR="$VALIDATION_DB_DIR"
export APPLE_AUTH_BYPASS=1
export SESSION_SECRET="${SESSION_SECRET:-validation-session-secret-32chars}"
export LIVEKIT_API_KEY="${LIVEKIT_API_KEY:-devkey}"
export LIVEKIT_API_SECRET="${LIVEKIT_API_SECRET:-devsecretdevsecretdevsecret}"
export LIVEKIT_URL="${LIVEKIT_URL:-ws://127.0.0.1:7880}"

echo "Starting validation API on http://127.0.0.1:$PORT"
echo "Validation DB: $LIKEMINDED_DB_DIR"
exec node services/api/src/server.js
