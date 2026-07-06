#!/usr/bin/env bash
# Post-parallel macOS validation: sole API on :8787, one seed, full captures, sequential CUA.
# Use after parallel UI workers finish — never run CUA/capture in parallel with other Mac launches.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8787}"
API_LOG="/tmp/likeminded-validation-batch-api.log"
api_pid=""
mode="both" # capture | cua | both

SCREENS=(
  meetOverview
  circlesRoom
  circleDetail
  profileEdit
  communitiesBrowse
  communityDetail
  communityMembers
  createEvent
  meetRecap
  meetVideoCall
  myProfile
  soulmateOverview
  soulmateDiscover
  soulmateDetail
  notifications
  profileOnboarding
  profileSignals
  settingsSoulmate
  createCommunity
  chat
  messages
)

usage() {
  cat <<EOF
Usage: $0 [options] [screen ...]

Runs macOS validation with a single validation API owner and sequential CUA (no port/instance fights).

Options:
  --capture-only   Run verify_macos_screens.sh only (no CUA)
  --cua-only       Sequential macos_cua_screen.sh only (API must be up; skips capture)
  --keep-api       Do not stop validation API on exit
  -h, --help       Show this help

Default (no screen args): all prototype screens in the batch list.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --capture-only) mode="capture"; shift ;;
    --cua-only) mode="cua"; shift ;;
    --keep-api) export MACOS_BATCH_KEEP_API=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) break ;;
  esac
done

if (($# > 0)); then
  SCREENS=("$@")
fi

cleanup() {
  # shellcheck source=macos_canonical_app.sh
  source "$ROOT/script/macos_canonical_app.sh"
  macos_kill_if_lock_holder
  if [[ -n "$api_pid" ]] && [[ -z "${MACOS_BATCH_KEEP_API:-}" ]]; then
    kill "$api_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

wait_for_api() {
  local deadline=$((SECONDS + 15))
  while (( SECONDS < deadline )); do
    if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  echo "validation API did not become healthy; log:" >&2
  tail -30 "$API_LOG" >&2 || true
  exit 1
}

ensure_api() {
  if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    echo "Reusing validation API on :$PORT"
    return 0
  fi
  if lsof -ti ":$PORT" >/dev/null 2>&1; then
    echo "Freeing port $PORT for validation API..."
    kill "$(lsof -ti ":$PORT")" >/dev/null 2>&1 || true
    sleep 1
  fi
  "$ROOT/script/run_validation_api.sh" >"$API_LOG" 2>&1 &
  api_pid="$!"
  wait_for_api
  echo "Validation API started (pid $api_pid)"
}

if [[ "$mode" != "cua" ]]; then
  ensure_api
  (cd "$ROOT" && npm run reset:validation-data >/tmp/likeminded-validation-batch-seed.log)
  echo "== capture all macOS screens =="
  "$ROOT/script/verify_macos_screens.sh"
else
  curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null || {
    echo "Start validation API first: npm run dev:api:validation" >&2
    exit 1
  }
fi

if [[ "$mode" != "capture" ]]; then
  if [[ ! -x "${CUA_DRIVER:-$HOME/.local/bin/cua-driver}" ]] && [[ -z "${CUA_DRIVER:-}" ]]; then
    echo "cua-driver not found; skipping CUA (set CUA_DRIVER or install ~/.local/bin/cua-driver)" >&2
    exit 1
  fi
  ensure_api
  cua_ok=0
  cua_fail=0
  cua_failed=""
  echo "== sequential CUA (${#SCREENS[@]} screens) =="
  for screen in "${SCREENS[@]}"; do
    echo ""
    echo "-- CUA $screen --"
    if LIKEMINDED_VALIDATION_USER="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}" \
       LIKEMINDED_VALIDATION_NAME="${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}" \
       "$ROOT/script/macos_cua_screen.sh" "$screen"; then
      cua_ok=$((cua_ok + 1))
    else
      cua_fail=$((cua_fail + 1))
      cua_failed="$cua_failed $screen"
    fi
  done
  echo ""
  echo "CUA batch: $cua_ok ok, $cua_fail failed${cua_failed:+ ($cua_failed)}"
  if (( cua_fail > 0 )); then
    exit 1
  fi
fi

echo "== ledger stale check =="
(cd "$ROOT" && npm run ledger:stale 2>/dev/null | head -20) || true
echo "macOS validation batch complete."
