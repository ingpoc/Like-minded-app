#!/usr/bin/env bash
# Single-pointer smoke: preflight → session → 3 tab clicks. Exit 0 when all ok.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=macos_canonical_app.sh
source "$ROOT/script/macos_canonical_app.sh"
# shellcheck source=macos_cua_helpers.sh
source "$ROOT/script/macos_cua_helpers.sh"

: "${CUA_APP:=Likeminded}"
LABELS=(Meet Circles Communities)
EXPECTS=(MEET CIRCLES COMMUNITIES)

echo "[pointer-smoke] preflight"
"$ROOT/script/macos_cua_preflight.sh" >/dev/null

if ! macos_running_pids | head -1 | grep -q .; then
  echo "[pointer-smoke] launching signed-in shell (meetOverview)" >&2
  macos_launch \
    --likeminded-reset-auth-session \
    --likeminded-dev-auth-bypass \
    --likeminded-dev-auth-token validation-gurusharan \
    --likeminded-dev-auth-name "Gurusharan Gupta" \
    --mac-screen meetOverview
  macos_wait_main_window 25
fi

echo "[pointer-smoke] session start (align once + export display)"
macos_cua_session_start
macos_wait_main_window 15 || {
  echo "[pointer-smoke] relaunch after lost window" >&2
  macos_launch \
    --likeminded-reset-auth-session \
    --likeminded-dev-auth-bypass \
    --likeminded-dev-auth-token validation-gurusharan \
    --likeminded-dev-auth-name "Gurusharan Gupta" \
    --mac-screen meetOverview
  macos_wait_main_window 25
  macos_cua_session_start
}

echo "[pointer-smoke] MACOS_CUA_DISPLAY=${MACOS_CUA_DISPLAY:-?} SKIP_OVERLAY=${MACOS_CUA_SKIP_OVERLAY:-?}"

fail=0
for i in "${!LABELS[@]}"; do
  label="${LABELS[$i]}"
  expect="${EXPECTS[$i]}"
  passed=0
  out=""
  method="?"
  for attempt in 1 2; do
    if ! macos_wait_main_window 2 >/dev/null 2>&1; then
      echo "[pointer-smoke] restoring app window before '$label' (attempt $attempt)" >&2
      macos_cua_session_start
    fi
    cua focus "$CUA_APP" >/dev/null 2>&1 || true
    out="$(cua click-label-pointer "$CUA_APP" "$label" --max "$MACOS_CUA_MAX" 2>&1)" || true
    ok="$(python3 -c "import json,sys; print('yes' if json.loads(sys.stdin.read()).get('ok') else 'no')" <<<"$out" 2>/dev/null || echo no)"
    method="$(python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('method','?'))" <<<"$out" 2>/dev/null || echo ?)"
    if [[ "$ok" == "yes" ]] && wait_ui_contains "$expect" 4 >/dev/null 2>&1; then
      echo "OK click '$label' method=$method verified='$expect'"
      passed=1
      break
    fi
    echo "[pointer-smoke] retry '$label' after failed verification (attempt $attempt)" >&2
    macos_cua_session_start || true
  done
  if (( ! passed )); then
      echo "FAIL click '$label' method=$method" >&2
      echo "$out" >&2
      echo "Expected screen text not visible: $expect" >&2
      fail=1
  fi
done

if (( fail )); then
  echo "[pointer-smoke] FAILED" >&2
  exit 1
fi
echo "[pointer-smoke] PASS (${#LABELS[@]} clicks, display=$MACOS_CUA_DISPLAY)"
