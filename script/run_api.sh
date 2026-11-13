#!/usr/bin/env bash
# Run the likeminded-api server with env loaded from .env.local
# Usage: ./script/run_api.sh [PORT]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8787}"
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

echo "Starting likeminded-api on port $PORT..."
echo "Health: http://127.0.0.1:$PORT/health"
exec node "$API_SCRIPT"
