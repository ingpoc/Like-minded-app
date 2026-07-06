#!/usr/bin/env bash
# Shared macOS CUA harness helpers. Source after macos_canonical_app.sh (sets ROOT).
# Requires: MACOS_CUA_PY, CUA_APP (default Likeminded).

: "${MACOS_CUA_PY:=$HOME/.agents/skills/macos-cua/scripts/macos-cua.py}"
: "${CUA_APP:=Likeminded}"
: "${MACOS_CUA_MAX:=50}"
: "${MACOS_CUA_MAX_MODAL:=80}"

cua() { python3 "$MACOS_CUA_PY" "$@"; }

# App menu ⌘1-5 — cua key background delivery cannot verify menu shortcuts.
cua_menu_shortcut() {
  local digit="$1"
  if [[ "${MACOS_CUA_SKIP_OVERLAY:-}" == "1" ]]; then
    cua focus "$CUA_APP" >/dev/null 2>&1 || true
  else
    "$ROOT/script/macos_cua_focus_window.sh" >/dev/null
  fi
  osascript <<APPLESCRIPT >/dev/null
tell application "System Events"
  tell process "$MACOS_CANONICAL_EXEC"
    set frontmost to true
  end tell
  keystroke "$digit" using command down
end tell
APPLESCRIPT
}

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

# Align cua-driver overlay to the display hosting LikemindedMac (multi-monitor safe).
macos_cua_align_to_window() {
  local align_json token
  align_json="$(python3 "$ROOT/script/macos_cua_align_displays.py" 2>/dev/null)" || return 1
  token="$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(d.get('target_token') or '')
" <<<"$align_json")"
  [[ -n "$token" ]] || return 1
  export MACOS_CUA_DISPLAY="$token"
}

# Resolve display token for the parent shell (subprocess focus does not export env).
macos_cua_export_display_env() {
  local align_json token
  align_json="$(MACOS_CUA_SKIP_OVERLAY=1 python3 "$ROOT/script/macos_cua_align_displays.py" 2>/dev/null)" || return 1
  token="$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(d.get('target_token') or '')
" <<<"$align_json")"
  [[ -n "$token" ]] || return 1
  export MACOS_CUA_DISPLAY="$token"
}

macos_cua_session_start() {
  "$ROOT/script/macos_cua_focus_window.sh" >/dev/null || return 1
  export MACOS_CUA_SKIP_OVERLAY=1
  macos_cua_export_display_env || return 1
  cua reset >/dev/null 2>&1 || true
  cua focus "$CUA_APP" >/dev/null 2>&1 || true
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

ui_ax_contains() {
  local needle="$1"
  local proc="${MACOS_CANONICAL_EXEC:-LikemindedMac}"
  osascript - "$proc" "$needle" <<'APPLESCRIPT' 2>/dev/null | grep -q '^true$'
on run argv
  set procName to item 1 of argv
  set needle to item 2 of argv
  tell application "System Events"
    if not (exists process procName) then return "false"
    tell process procName
      set frontmost to true
      try
        repeat with el in (entire contents as list)
          try
            if (value of el as text) contains needle then return "true"
          end try
          try
            if (title of el as text) contains needle then return "true"
          end try
          try
            if (description of el as text) contains needle then return "true"
          end try
        end repeat
      end try
    end tell
  end tell
  return "false"
end run
APPLESCRIPT
}

ui_tree_contains() {
  local needle="$1"
  local max="${2:-80}"
  local skip_focus="${3:-}"
  if [[ "$skip_focus" != "no-focus" ]]; then
    cua focus "$CUA_APP" >/dev/null 2>&1 || true
  fi
  if cua snap "$CUA_APP" --max "$max" --mode som 2>/dev/null | grep -qF "$needle"; then
    return 0
  fi
  if cua snap "$CUA_APP" --max "$max" --mode ax 2>/dev/null | grep -qF "$needle"; then
    return 0
  fi
  if [[ "$skip_focus" == "no-focus" ]]; then
    return 1
  fi
  ui_ax_contains "$needle"
}

ui_tree_contains_modal() {
  if ui_tree_contains "$1" "$MACOS_CUA_MAX_MODAL" no-focus; then
    return 0
  fi
  ui_ax_contains "$1"
}

wait_ui_contains() {
  local needle="$1"
  local timeout="${2:-20}"
  local modal="${3:-}"
  local deadline=$((SECONDS + timeout))
  local pass=0
  if [[ "$modal" == "modal" ]]; then
    wait_ui_contains_modal "$needle" "$timeout"
    return $?
  fi
  cua focus "$CUA_APP" >/dev/null 2>&1 || true
  while (( SECONDS < deadline )); do
    if ui_tree_contains "$needle"; then
      return 0
    fi
    if (( pass % 4 == 3 )) && [[ "${MACOS_CUA_SKIP_OVERLAY:-}" != "1" ]]; then
      macos_cua_align_to_window >/dev/null 2>&1 || true
    fi
    pass=$((pass + 1))
    sleep 0.5
  done
  echo "[cua] timeout waiting for UI: $needle" >&2
  return 1
}

wait_ui_contains_modal() {
  local needle="$1"
  local timeout="${2:-20}"
  local deadline=$((SECONDS + timeout))
  while (( SECONDS < deadline )); do
    ui_tree_contains_modal "$needle" && return 0
    sleep 0.5
  done
  echo "[cua] timeout waiting for UI: $needle" >&2
  return 1
}

macos_wait_single_instance() {
  local timeout="${1:-20}"
  local deadline=$((SECONDS + timeout))
  while (( SECONDS < deadline )); do
    local -a pids=()
    while IFS= read -r pid; do
      [[ -n "$pid" ]] && pids+=("$pid")
    done < <(macos_running_pids)
    if (( ${#pids[@]} == 1 )); then
      return 0
    fi
    if (( ${#pids[@]} > 1 )); then
      local keep="${pids[-1]}"
      local pid
      for pid in "${pids[@]}"; do
        [[ "$pid" == "$keep" ]] || kill -9 "$pid" 2>/dev/null || true
      done
      sleep 0.5
      continue
    fi
    sleep 0.35
  done
  echo "[cua] timeout waiting for single LikemindedMac instance (${timeout}s)" >&2
  return 1
}

cua_click_ax_label() {
  local label="$1"
  local proc="${MACOS_CANONICAL_EXEC:-LikemindedMac}"
  osascript - "$proc" "$label" <<'APPLESCRIPT' 2>/dev/null | grep -q '^ok$'
on run argv
  set procName to item 1 of argv
  set needle to item 2 of argv
  tell application "System Events"
    if not (exists process procName) then return "miss"
    tell process procName
      set frontmost to true
      repeat with el in (entire contents as list)
        try
          set t to (description of el as text)
          if t is needle then
            perform action "AXPress" of el
            return "ok"
          end if
        end try
        try
          set t to (title of el as text)
          if t is needle then
            perform action "AXPress" of el
            return "ok"
          end if
        end try
        try
          set t to (value of el as text)
          if t is needle then
            perform action "AXPress" of el
            return "ok"
          end if
        end try
      end repeat
    end tell
  end tell
  return "miss"
end run
APPLESCRIPT
}

cua_scroll_until() {
  local needle="$1"
  local attempts="${2:-6}"
  local i
  for (( i=0; i<attempts; i++ )); do
    ui_tree_contains "$needle" && return 0
    cua scroll "$CUA_APP" down --amount 4 >/dev/null 2>&1 || true
    sleep 0.45
  done
  ui_tree_contains "$needle"
}

wait_welcome_ready() {
  wait_ui_contains "Terms & Privacy Policy" 20 \
    || wait_ui_contains "Sign in with Apple" 15 \
    || wait_ui_contains "Continue with Google" 15 \
    || wait_ui_contains "When you meet, it matters." 10
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
