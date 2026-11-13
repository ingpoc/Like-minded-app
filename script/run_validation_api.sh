#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8787}"
VALIDATION_DB_DIR="${LIKEMINDED_VALIDATION_DB_DIR:-$ROOT_DIR/data/validation-db}"
FORCE_RESTART="${LIKEMINDED_FORCE_API_RESTART:-0}"

validation_api_healthy() {
  local body
  body="$(curl -sf "http://127.0.0.1:${PORT}/health" 2>/dev/null || true)"
  [[ -n "$body" ]] || return 1
  printf '%s' "$body" | python3 -c '
import json, sys
d = json.load(sys.stdin)
sys.exit(0 if d.get("status") == "ok" and "validation-db" in (d.get("dbPath") or "") else 1)
' 2>/dev/null
}

# Parallel iOS/macOS drains used to kill a healthy :8787 on every restart, which
# surfaces as iOS auth "Could not connect to the server." Reuse when already good.
if [[ "$FORCE_RESTART" != "1" ]] && validation_api_healthy; then
  echo "Validation API already healthy on http://127.0.0.1:$PORT (validation-db); reuse"
  echo "Validation DB: $VALIDATION_DB_DIR"
  exit 0
fi

if lsof -ti :"$PORT" >/dev/null 2>&1; then
  # Wrong DB or unhealthy listener — replace. Kill each PID (lsof can return many).
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    kill "$pid" 2>/dev/null || true
  done < <(lsof -ti :"$PORT" 2>/dev/null || true)
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
