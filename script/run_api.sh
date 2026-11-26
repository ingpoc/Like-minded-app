#!/usr/bin/env bash
# Run the likeminded-api server with env loaded from .env.local
# Usage: ./script/run_api.sh [PORT]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Preserve the caller's port across .env.local, whose contents are trusted only
# for application settings and must never redirect this process.
REQUESTED_PORT="${1:-${PORT:-8794}}"
PORT="$REQUESTED_PORT"
REQUESTED_APPLE_AUTH_BYPASS="${APPLE_AUTH_BYPASS:-}"
REQUESTED_DB_DIR="${LIKEMINDED_DB_DIR:-}"
API_SCRIPT="$ROOT_DIR/services/api/src/server.js"

if [[ ! -f "$ROOT_DIR/.env.local" ]]; then
  echo "ERROR: .env.local not found in $ROOT_DIR" >&2
  echo "Create it with: OPENAI_API_KEY=sk-... OPENAI_REALTIME_MODEL=gpt-realtime-mini OPENAI_REALTIME_VOICE=marin" >&2
  exit 1
fi

# Kill existing process on the port
if lsof -ti :"$PORT" >/dev/null 2>&1; then
  echo "Killing existing process on port $PORT..."
  kill "$(lsof -ti :"$PORT")" 2>/dev/null || true
  sleep 1
fi

cd "$ROOT_DIR"
set -a && source .env.local && set +a
export PORT="$REQUESTED_PORT"
if [[ -n "$REQUESTED_APPLE_AUTH_BYPASS" ]]; then export APPLE_AUTH_BYPASS="$REQUESTED_APPLE_AUTH_BYPASS"; fi
if [[ -n "$REQUESTED_DB_DIR" ]]; then export LIKEMINDED_DB_DIR="$REQUESTED_DB_DIR"; fi

echo "Starting likeminded-api on port $PORT..."
echo "Health: http://127.0.0.1:$PORT/health"
exec env PORT="$PORT" node "$API_SCRIPT"
