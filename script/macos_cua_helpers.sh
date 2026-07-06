#!/usr/bin/env bash
# Shared macOS CUA harness helpers. Source after macos_canonical_app.sh (sets ROOT).
# Requires: MACOS_CUA_PY, CUA_APP (default Likeminded).

: "${MACOS_CUA_PY:=$HOME/.agents/skills/macos-cua/scripts/macos-cua.py}"
: "${CUA_APP:=Likeminded}"
: "${MACOS_CUA_MAX:=50}"
: "${MACOS_CUA_MAX_MODAL:=80}"

cua() { python3 "$MACOS_CUA_PY" "$@"; }

macos_wait_main_window() {
  local timeout="${1:-25}"
  local deadline=$((SECONDS + timeout))
  while (( SECONDS < deadline )); do
    if "$ROOT/script/macos_cua_window.sh" >/dev/null 2>&1; then
      sleep 0.25
      return 0
    fi
    sleep 0.35
  done
  echo "[cua] timeout waiting for main window (${timeout}s)" >&2
  return 1
}

macos_cua_session_start() {
  "$ROOT/script/macos_cua_focus_window.sh" >/dev/null
  export MACOS_CUA_SKIP_OVERLAY=1
  cua reset >/dev/null 2>&1 || true
  cua focus "$CUA_APP" >/dev/null 2>&1 || true
  cua cursor show >/dev/null 2>&1 || true
}

macos_cua_launch_dev() {
  local token="$1"
  local name="$2"
  macos_kill_all
  sleep 0.5
  open -F -n "$MACOS_CANONICAL_APP" --args \
    --likeminded-reset-auth-session \
    --likeminded-dev-auth-bypass \
    --likeminded-dev-auth-token "$token" \
    --likeminded-dev-auth-name "$name"
  macos_wait_main_window 25 || return 1
  macos_cua_session_start
}

ui_tree_contains() {
  local needle="$1"
  cua snap "$CUA_APP" --max 80 --mode ax 2>/dev/null | grep -qF "$needle"
}

# Wait until basics save succeeds (voice step visible, no error banner).
assert_basics_advanced() {
  local deadline=$((SECONDS + 18))
  while (( SECONDS < deadline )); do
    if assert_basics_saved_api; then
      return 0
    fi
    if ! ui_tree_contains "Profile could not be saved"; then
      if ui_tree_contains "Your answer" || ui_tree_contains "Record & analyze"; then
        return 0
      fi
    fi
    sleep 0.5
  done
  return 1
}

cua_session_token() {
  python3 -c "
import json,urllib.request,os
token=os.environ.get('FLOW_TOKEN','')
req=urllib.request.Request('http://127.0.0.1:${PORT:-8787}/v1/auth/apple',
  data=json.dumps({'identityToken':token,'fullName':'CUA Tester'}).encode(),
  headers={'content-type':'application/json'}, method='POST')
print(json.load(urllib.request.urlopen(req)).get('sessionToken',''))
" 2>/dev/null
}

assert_basics_saved_api() {
  local tok prof
  tok="$(cua_session_token)" || return 1
  [[ -n "$tok" ]] || return 1
  prof="$(curl -fsS -H "Authorization: Bearer $tok" "http://127.0.0.1:${PORT:-8787}/v1/me/profile" 2>/dev/null)" || return 1
  python3 -c "
import json,sys
d=json.load(sys.stdin)
b=(d.get('profile') or {}).get('basicInfo') or {}
sys.exit(0 if (b.get('name') or '').strip() and (b.get('city') or '').strip() else 1)
" <<<"$prof" 2>/dev/null
}

# Integration: basics PATCH persisted name, city, and selected interest labels.
assert_profile_basics_integration() {
  local tok prof
  local expect_name="${1:-CUA Tester}"
  local expect_city="${2:-San Francisco}"
  shift 2 2>/dev/null || true
  tok="$(cua_session_token)" || return 1
  [[ -n "$tok" ]] || return 1
  prof="$(curl -fsS -H "Authorization: Bearer $tok" "http://127.0.0.1:${PORT:-8787}/v1/me/profile" 2>/dev/null)" || return 1
  PROFILE_JSON="$prof" EXPECT_NAME="$expect_name" EXPECT_CITY="$expect_city" \
    python3 -c "
import json,os,sys
d=json.loads(os.environ['PROFILE_JSON'])
b=(d.get('profile') or {}).get('basicInfo') or {}
interests=[i.get('label','') for i in (d.get('profile') or {}).get('interests') or []]
if (b.get('name') or '').strip() != os.environ['EXPECT_NAME']:
    sys.exit(1)
if (b.get('city') or '').strip() != os.environ['EXPECT_CITY']:
    sys.exit(1)
for label in sys.argv[1:]:
    if label and label not in interests:
        sys.exit(1)
" "$@" 2>/dev/null
}

# Integration: voice reflection created a placement with a primary circle.
assert_placement_integration() {
  local tok body
  tok="$(cua_session_token)" || return 1
  [[ -n "$tok" ]] || return 1
  body="$(curl -fsS -H "Authorization: Bearer $tok" "http://127.0.0.1:${PORT:-8787}/v1/me/placement" 2>/dev/null)" || return 1
  python3 -c "
import json,sys
d=json.load(sys.stdin)
p=d.get('placement') or {}
sys.exit(0 if p.get('primaryCircle',{}).get('name') else 1)
" <<<"$body" 2>/dev/null
}

# Integration: account deletion removed profile (GET 404).
assert_account_deleted_api() {
  local tok
  tok="$(cua_session_token)" || return 0
  [[ -n "$tok" ]] || return 0
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $tok" "http://127.0.0.1:${PORT:-8787}/v1/me/profile" 2>/dev/null)" || return 1
  [[ "$code" == "404" ]]
}

# Dismiss a confirmation dialog without destructive action.
cua_dismiss_modal() {
  cua click-label-pointer "$CUA_APP" "Cancel" --max "$MACOS_CUA_MAX_MODAL" >/dev/null 2>&1 || true
}

# Click the last AX match (modal confirm over sidebar duplicate labels).
cua_click_last_label() {
  local needle="$1"
  local max="${2:-$MACOS_CUA_MAX_MODAL}"
  local idx
  idx="$(cua list-buttons "$CUA_APP" --max "$max" 2>/dev/null | python3 -c "
import json,sys
needle=sys.argv[1].lower()
matches=[]
for line in sys.stdin:
    line=line.strip()
    if not line:
        continue
    e=json.loads(line)
    if needle in (e.get('label') or '').lower():
        matches.append(int(e['index']))
print(matches[-1] if matches else '')
" "$needle")"
  [[ -n "$idx" ]] || return 1
  cua click "$CUA_APP" "$idx" >/dev/null 2>&1
}
