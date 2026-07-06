#!/usr/bin/env bash
# Operator preflight for Render free tier + Neon before TestFlight.
# Usage: set -a && source .env.local && set +a && ./script/deploy_render_preflight.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/.env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env.local"
  set +a
fi

failures=0

check() {
  local label="$1"
  local value="$2"
  if [[ -z "${value// }" ]]; then
    echo "MISSING: $label" >&2
    failures=$((failures + 1))
  else
    echo "OK: $label"
  fi
}

echo "=== Render / Neon preflight ==="
check "DATABASE_URL" "${DATABASE_URL:-}"
check "SESSION_SECRET" "${SESSION_SECRET:-}"
check "OPENAI_API_KEY" "${OPENAI_API_KEY:-}"

if [[ -n "${RENDER_SERVICE_URL:-}" ]]; then
  echo "Checking Render health at $RENDER_SERVICE_URL/health ..."
  if curl -fsS "${RENDER_SERVICE_URL%/}/health" | grep -q '"status":"ok"'; then
    echo "OK: Render /health"
  else
    echo "FAIL: Render /health not ok" >&2
    failures=$((failures + 1))
  fi
else
  echo "SKIP: RENDER_SERVICE_URL unset (set to https://likeminded-api.onrender.com after deploy)"
fi

if [[ -n "${DATABASE_URL:-}" ]]; then
  echo "Running migrate:api against DATABASE_URL ..."
  npm run migrate:api
  echo "OK: migrate:api"
fi

if (( failures > 0 )); then
  echo "Preflight failed ($failures missing required values)." >&2
  exit 1
fi

echo "Preflight passed."
