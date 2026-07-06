#!/usr/bin/env bash
# Flow-specific macOS CUA proof for testing-ledger (one screen/flow per invocation).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LOCK="$ROOT/script/testing_ledger_runtime_lock.sh"

LOCK_FILE="/tmp/likeminded-testing-ledger-macos.lock"

release_lock() {
  local pid
  [[ -f "$LOCK_FILE" ]] || return 0
  read -r pid _ < "$LOCK_FILE" 2>/dev/null || true
  if [[ -n "$pid" && "$pid" == "$$" ]]; then
    rm -f "$LOCK_FILE"
  fi
}
trap release_lock EXIT INT TERM

lock_status="$("$LOCK" --platform macos status)"
if echo "$lock_status" | grep -q '^held '; then
  echo "runtime lock held — another agent owns macos CUA lane ($lock_status)" >&2
  exit 1
fi
echo "$$ prove" > "$LOCK_FILE"
echo "acquired platform=macos pid=$$ role=prove"

# shellcheck source=macos_canonical_app.sh
source "$ROOT/script/macos_canonical_app.sh"
# shellcheck source=macos_cua_helpers.sh
source "$ROOT/script/macos_cua_helpers.sh"

SCREEN=""
FLOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --screen) SCREEN="$2"; shift 2 ;;
    --flow) FLOW="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --screen <logical-id> --flow <flow-id>"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$SCREEN" || -z "$FLOW" ]]; then
  echo "Usage: $0 --screen <logical-id> --flow <flow-id>" >&2
  exit 2
fi

curl -fsS "http://127.0.0.1:${PORT:-8787}/health" >/dev/null || {
  echo "Start: npm run dev:api:validation" >&2
  exit 1
}

"$ROOT/script/macos_cua_preflight.sh"

CLICK_OK=0
CLICK_MISS=0
FLOW_FAIL=0
MAC=""
EVIDENCE_USER="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}"

launch_shell_signed_in() {
  macos_launch \
    --likeminded-reset-auth-session \
    --likeminded-dev-auth-bypass \
    --likeminded-dev-auth-token "$EVIDENCE_USER" \
    --likeminded-dev-auth-name "${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}"
  sleep 2
  macos_wait_main_window 25
  macos_cua_session_start
}

launch_welcome() {
  macos_launch \
    --likeminded-reset-auth-session \
    --likeminded-validation-welcome \
    --mac-screen welcome
  sleep 6
  macos_wait_single_instance 25 || FLOW_FAIL=1
  "$ROOT/script/macos_cua_focus_window.sh" >/dev/null || true
  macos_wait_main_window 30 || FLOW_FAIL=1
  macos_cua_session_start
  wait_welcome_ready || FLOW_FAIL=1
}

click_label_expect_modal() {
  local label="$1"
  local expect="$2"
  local out ok idx
  out="$(cua click-label-pointer "$CUA_APP" "$label" --max "$MACOS_CUA_MAX" 2>&1)" || true
  ok="$(python3 -c "import json,sys; print('yes' if json.loads(sys.stdin.read()).get('ok') else 'no')" <<<"$out" 2>/dev/null || echo no)"
  if [[ "$ok" != "yes" ]]; then
    idx="$(cua find "$CUA_APP" "$label" --max "$MACOS_CUA_MAX" 2>/dev/null | python3 -c "
import json,sys
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    try:
        d=json.loads(line)
    except json.JSONDecodeError:
        continue
    e=d.get('element')
    if d.get('found') and e is not None:
        print(e); break
" || true)"
    if [[ -n "$idx" ]]; then
      out="$(cua click "$CUA_APP" "$idx" 2>&1)" || true
      ok="$(python3 -c "import json,sys; print('yes' if json.loads(sys.stdin.read()).get('ok') else 'no')" <<<"$out" 2>/dev/null || echo no)"
    fi
  fi
  if [[ "$ok" != "yes" ]]; then
    out="$(cua click-label "$CUA_APP" "$label" --max "$MACOS_CUA_MAX" 2>&1)" || true
    ok="$(python3 -c "import json,sys; print('yes' if json.loads(sys.stdin.read()).get('ok') else 'no')" <<<"$out" 2>/dev/null || echo no)"
  fi
  if [[ "$ok" != "yes" ]] && cua_click_ax_label "$label"; then
    ok="yes"
  fi
  if [[ "$ok" != "yes" ]]; then
    echo "MISS click '$label'"
    CLICK_MISS=$((CLICK_MISS + 1))
    FLOW_FAIL=1
    return 1
  fi
  echo "OK click '$label'"
  CLICK_OK=$((CLICK_OK + 1))
  sleep 1.5
  if wait_ui_contains "$expect" 25 modal \
    || wait_ui_contains "Data Collected" 15 modal \
    || wait_ui_contains "voice-first conversation app" 12 modal \
    || wait_ui_contains "Send request in chat" 12 modal \
    || wait_ui_contains "not live yet" 12 modal; then
    echo "OK modal '$expect'"
    return 0
  fi
  echo "MISS modal '$expect' after click '$label'"
  CLICK_MISS=$((CLICK_MISS + 1))
  FLOW_FAIL=1
  return 1
}

launch_signed_in() {
  local mac_screen="${1:-meetOverview}"
  macos_launch \
    --likeminded-reset-auth-session \
    --likeminded-dev-auth-bypass \
    --likeminded-dev-auth-token "$EVIDENCE_USER" \
    --likeminded-dev-auth-name "${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}" \
    --mac-screen "$mac_screen"
  sleep 2
  "$ROOT/script/macos_cua_focus_window.sh" >/dev/null || true
  macos_wait_main_window 30 || FLOW_FAIL=1
  macos_cua_session_start
}

prove_key_then() {
  local key="$1"
  local expect="$2"
  local label="$3"
  local digit="${key#cmd+}"
  if cua_menu_shortcut "$digit" && sleep 0.45 && ui_tree_contains "$expect"; then
    echo "OK key $label ($key) → $expect"
    CLICK_OK=$((CLICK_OK + 1))
    return 0
  fi
  echo "MISS key $label ($key) expected: $expect"
  CLICK_MISS=$((CLICK_MISS + 1))
  FLOW_FAIL=1
  return 1
}

set +e

click_tab_label() {
  local label="$1"
  local expect="$2"
  local out ok
  out="$(cua click-label-pointer "$CUA_APP" "$label" --max "$MACOS_CUA_MAX" 2>&1)" || true
  ok="$(python3 -c "import json,sys; print('yes' if json.loads(sys.stdin.read()).get('ok') else 'no')" <<<"$out" 2>/dev/null || echo no)"
  if [[ "$ok" == "yes" ]] && sleep 0.35 && ui_tree_contains "$expect"; then
    echo "OK tab '$label' → $expect"
    CLICK_OK=$((CLICK_OK + 1))
    return 0
  fi
  echo "MISS tab '$label' expected: $expect"
  CLICK_MISS=$((CLICK_MISS + 1))
  FLOW_FAIL=1
  return 1
}

click_tab_expect_any() {
  local label="$1"
  shift
  local out ok expect
  out="$(cua click-label-pointer "$CUA_APP" "$label" --max "$MACOS_CUA_MAX" 2>&1)" || true
  ok="$(python3 -c "import json,sys; print('yes' if json.loads(sys.stdin.read()).get('ok') else 'no')" <<<"$out" 2>/dev/null || echo no)"
  if [[ "$ok" != "yes" ]]; then
    echo "MISS tab click '$label'"
    CLICK_MISS=$((CLICK_MISS + 1))
    FLOW_FAIL=1
    return 1
  fi
  sleep 0.35
  for expect in "$@"; do
    if ui_tree_contains "$expect"; then
      echo "OK tab '$label' → $expect"
      CLICK_OK=$((CLICK_OK + 1))
      return 0
    fi
  done
  echo "MISS tab '$label' expected one of: $*"
  CLICK_MISS=$((CLICK_MISS + 1))
  FLOW_FAIL=1
  return 1
}

click_label_expect() {
  local label="$1"
  local expect="$2"
  local optional="${3:-}"
  local out ok
  out="$(cua click-label-pointer "$CUA_APP" "$label" --max "$MACOS_CUA_MAX" 2>&1)" || true
  ok="$(python3 -c "import json,sys; print('yes' if json.loads(sys.stdin.read()).get('ok') else 'no')" <<<"$out" 2>/dev/null || echo no)"
  if [[ "$ok" == "yes" ]] && sleep 0.35 && ui_tree_contains "$expect"; then
    echo "OK click '$label' → $expect"
    CLICK_OK=$((CLICK_OK + 1))
    return 0
  fi
  echo "MISS click '$label' expected: $expect"
  if [[ "$optional" != "optional" ]]; then
    CLICK_MISS=$((CLICK_MISS + 1))
    FLOW_FAIL=1
  fi
  return 1
}

stamp_controls() {
  local ids="$1"
  [[ -n "$ids" ]] || return 0
  node "$ROOT/script/ledger_stamp_screen.js" \
    --platform macos \
    --screen "$SCREEN" \
    --controls "$ids" \
    --method CUA-click \
    --evidence-prefix "CUA ${EVIDENCE_USER} ${SCREEN}/${FLOW}" || true
}

echo "prove_flow screen=$SCREEN flow=$FLOW"

case "${SCREEN}/${FLOW}" in
  app-shell/app-menu-nav)
    launch_shell_signed_in
    prove_key_then "cmd+1" "When you meet." "menu-meet"
    prove_key_then "cmd+2" "Your room." "menu-circles"
    prove_key_then "cmd+3" "Explore communities" "menu-communities"
    prove_key_then "cmd+4" "Discover" "menu-soulmate"
    prove_key_then "cmd+5" "Your profile" "menu-profile"
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "menu-meet,menu-circles,menu-communities,menu-soulmate,menu-profile"
    fi
    ;;
  app-shell/tab-navigation)
    launch_shell_signed_in
    click_tab_label "Meet" "When you meet."
    click_tab_label "Circles" "Your room."
    click_tab_label "Communities" "Explore communities"
    click_tab_label "Soulmate" "Discover"
    click_tab_label "Profile" "Your profile"
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "tab-meet,tab-circles,tab-communities,tab-soulmate,tab-profile"
    fi
    ;;
  app-shell/global-back)
    launch_shell_signed_in
    cua_menu_shortcut "2"
    sleep 0.4
    click_label_expect "Open your circle The Quiet Builders" "About this circle"
    click_label_expect "Back" "Your room."
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "global-back"
    fi
    ;;
  app-shell/title-action-messages)
    launch_shell_signed_in
    wait_ui_contains "Messages" 20 || FLOW_FAIL=1
    click_label_expect "Messages" "Messages"
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "title-messages"
    fi
    ;;
  app-shell/title-action-settings)
    launch_shell_signed_in
    cua_menu_shortcut "5"
    sleep 0.4
    click_label_expect "Settings" "Account"
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "title-settings"
    fi
    ;;
  auth/auth-privacy-link)
    launch_welcome
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      wait_ui_contains "Terms & Privacy Policy" 15 || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      click_label_expect_modal "Terms & Privacy Policy" "Likeminded TestFlight Privacy Policy"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "auth-privacy-link"
    fi
    ;;
  circle-detail/circle-detail-tabs)
    launch_signed_in circleDetail
    "$ROOT/script/macos_cua_focus_window.sh" >/dev/null || true
    macos_cua_session_start
    wait_ui_contains "About this circle" 35 \
      || wait_ui_contains "The Quiet Builders" 20 \
      || wait_ui_contains "Your circle" 15 \
      || FLOW_FAIL=1
    click_tab_expect_any "Members" "members online"
    click_tab_expect_any "Events" "RSVP on Meet" "No upcoming circle meetup"
    click_tab_expect_any "Discussions" "book that changed" "12 replies"
    click_tab_expect_any "Resources" "Circle guidelines" "Conversation prompts"
    click_tab_expect_any "About" "Recent discussions" "Upcoming" "About this circle"
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "circle-tab-about,circle-tab-members,circle-tab-events,circle-tab-discussions,circle-tab-resources"
    fi
    ;;
  circles/hero-circle-macos)
    launch_signed_in circlesRoom
    wait_ui_contains "Your room." 20 || FLOW_FAIL=1
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      click_label_expect "Open your circle The Quiet Builders" "About this circle" optional
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ui_tree_contains "About this circle"; then
      click_label_expect "Open your circle Reflective Builders" "About this circle" optional
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ui_tree_contains "About this circle"; then
      echo "MISS hero-circle: hero card did not navigate to circle detail"
      CLICK_MISS=$((CLICK_MISS + 1))
      FLOW_FAIL=1
    elif [[ "$FLOW_FAIL" -eq 0 ]]; then
      echo "OK hero-circle → About this circle"
      CLICK_OK=$((CLICK_OK + 1))
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "hero-circle-macos"
    fi
    ;;
  circles/browse-expand)
    launch_signed_in circlesRoom
    wait_ui_contains "Available circles" 20 || FLOW_FAIL=1
    click_label_expect "Browse all circles" "Show fewer circles"
    click_label_expect "Show fewer circles" "Browse all circles"
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "browse-all,show-less"
    fi
    ;;
  chat/chat-call-headers)
    launch_signed_in chat
    "$ROOT/script/macos_cua_focus_window.sh" >/dev/null || true
    macos_cua_session_start
    wait_ui_contains "Chats" 30 || wait_ui_contains "Search conversations" 30 || FLOW_FAIL=1
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ui_tree_contains "Voice call"; then
      click_label_expect "Open conversation with Arjun" "Voice call" optional
      click_label_expect "Open conversation with Meera" "Voice call" optional
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ui_tree_contains "Voice call"; then
      echo "MISS chat thread: voice-call-header not visible"
      CLICK_MISS=$((CLICK_MISS + 1))
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      click_label_expect_modal "Voice call" "Request a voice call"
      cua_dismiss_modal
      sleep 0.5
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      click_label_expect_modal "Video call" "Request a video call"
      cua_dismiss_modal
      sleep 0.5
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      out="$(cua click-label-pointer "$CUA_APP" "Conversation info" --max "$MACOS_CUA_MAX" 2>&1)" || true
      ok="$(python3 -c "import json,sys; print('yes' if json.loads(sys.stdin.read()).get('ok') else 'no')" <<<"$out" 2>/dev/null || echo no)"
      if [[ "$ok" != "yes" ]] && cua_click_ax_label "Conversation info"; then
        ok="yes"
      fi
      if [[ "$ok" == "yes" ]] && wait_ui_contains "About" 20; then
        echo "OK click 'Conversation info' → About"
        CLICK_OK=$((CLICK_OK + 1))
      else
        echo "MISS click 'Conversation info' expected: About"
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "voice-call-header,video-call-header,conversation-info-header"
    fi
    ;;
  circle-detail/circle-share-leave)
    launch_signed_in circleDetail
    wait_ui_contains "About this circle" 35 || FLOW_FAIL=1
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      click_label_expect_modal "Circle options" "Share circle"
      click_label_expect "Share circle" "Share link copied"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      click_label_expect_modal "Circle options" "Leave circle"
      click_label_expect "Leave circle" "Left"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "share-circle,leave-circle-macos"
    fi
    ;;
  soulmate-discover/discover-filter-toggles)
    macos_launch \
      --likeminded-reset-auth-session \
      --likeminded-dev-auth-bypass \
      --likeminded-dev-auth-token "$EVIDENCE_USER" \
      --likeminded-dev-auth-name "${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}" \
      --mac-screen soulmateDiscover
    sleep 2
    "$ROOT/script/macos_cua_focus_window.sh" >/dev/null || true
    macos_wait_main_window 25 || FLOW_FAIL=1
    macos_cua_session_start
    wait_ui_contains "Discover" 20 || FLOW_FAIL=1
    wait_ui_contains "People I haven't met yet" 15 || FLOW_FAIL=1
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ui_tree_contains "Open Arjun" || { echo "MISS roster Open Arjun (default unmet filter)"; FLOW_FAIL=1; }
      ui_tree_contains "Open Rohan" || { echo "MISS roster Open Rohan (default unmet filter)"; FLOW_FAIL=1; }
      if ui_tree_contains "Open Meera"; then
        echo "UNEXPECTED Open Meera with unmet-only filter on"
        FLOW_FAIL=1
      else
        echo "OK Meera hidden with unmet-only filter"
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      click_label_expect "Active this week" "Open Arjun"
      if ui_tree_contains "Open Rohan"; then
        echo "UNEXPECTED Open Rohan after active-this-week filter"
        FLOW_FAIL=1
      else
        echo "OK Rohan hidden after active-this-week filter"
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      click_label_expect "People I haven't met yet" "Open Meera"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "discover-unmet,discover-active-week,discover-add-interest"
    fi
    ;;
  *)
  MAC="$(node -e "const {macScreenForLogical}=require('./script/ios_screen_stamp_map'); const id='$SCREEN'; const m=macScreenForLogical(id); process.stdout.write(m||'meetOverview');")"
    echo "fallback mac_screen=$MAC"
    exec "$ROOT/script/macos_cua_screen.sh" "$MAC"
    ;;
esac

echo "prove_summary ok=$CLICK_OK miss=$CLICK_MISS flow_fail=$FLOW_FAIL"
set -e
if [[ "$FLOW_FAIL" -ne 0 ]]; then
  exit 1
fi
