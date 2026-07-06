#!/usr/bin/env bash
# Likeminded macOS CUA end-to-end workflow test (optimized harness).
# CUA_CAPTURE=failures|all|none  CUA_TAB_NAV=1 to include tab navigation proof
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=macos_canonical_app.sh
source "$ROOT/script/macos_canonical_app.sh"
# shellcheck source=macos_cua_helpers.sh
source "$ROOT/script/macos_cua_helpers.sh"

OUT="${OUT:-$ROOT/output/cua-manual-test}"
SHOTS="$OUT/screenshots"
FLOW_TOKEN="${FLOW_TOKEN:-cua-manual-$(date +%s)}"
CUA_CAPTURE="${CUA_CAPTURE:-failures}"
STEP=0
PASS=0
FAIL=0

export MACOS_CUA_DISPLAY="${MACOS_CUA_DISPLAY:-DELL}"
export MACOS_CUA_LOCAL_COORDS="${MACOS_CUA_LOCAL_COORDS:-1}"
export MACOS_CUA_NO_FRAME="${MACOS_CUA_NO_FRAME:-1}"
export MACOS_CUA_CURSOR_ARROW="${MACOS_CUA_CURSOR_ARROW:-1}"
export LIKEMINDED_MAC_WINDOW_WIDTH="${LIKEMINDED_MAC_WINDOW_WIDTH:-1200}"
export LIKEMINDED_MAC_WINDOW_HEIGHT="${LIKEMINDED_MAC_WINDOW_HEIGHT:-760}"
export MACOS_CUA_FAST="${MACOS_CUA_FAST:-1}"
export MACOS_CUA_GLIDE_MS="${MACOS_CUA_GLIDE_MS:-300}"
export MACOS_CUA_DWELL_MS="${MACOS_CUA_DWELL_MS:-300}"

mkdir -p "$OUT" "$SHOTS"
log() { echo "[manual-cua] $*"; }

window_id() {
  "$ROOT/script/macos_cua_window.sh" | python3 -c "import json,sys; print(json.load(sys.stdin)['window_id'])"
}

capture() {
  [[ "$CUA_CAPTURE" == "none" ]] && return 0
  [[ "$CUA_CAPTURE" == "failures" && "${1:-}" != "fail" && "${1:-}" != "final" ]] && return 0
  local name="$2"
  [[ -z "$name" ]] && name="$1"
  local wid
  wid="$(window_id)" || return 1
  screencapture -x -l "$wid" "$SHOTS/${name}.png"
  log "screenshot $SHOTS/${name}.png"
}

click_label() {
  local needle="$1"
  local optional="${2:-}"
  local tag="$3"
  local max="${4:-$MACOS_CUA_MAX}"
  STEP=$((STEP + 1))
  local slug
  slug="$(printf '%02d' "$STEP")-${tag:-click}"
  local out ok coords
  out="$(cua click-label-pointer "$CUA_APP" "$needle" --max "$max" 2>&1)" || true
  ok="$(python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print('yes' if d.get('ok') else 'no')" <<<"$out" 2>/dev/null || echo no)"
  coords="$(python3 -c "import json,sys; d=json.loads(sys.stdin.read()); c=d.get('cursor_coords') or d.get('coords') or {}; print(c.get('x','?'), c.get('y','?'))" <<<"$out" 2>/dev/null || echo "? ?")"
  echo "$out" >"$SHOTS/${slug}.json"
  if [[ "$ok" == "yes" ]]; then
    log "PASS step $STEP click '$needle' @ $coords"
    PASS=$((PASS + 1))
    capture "$slug" "$slug"
    return 0
  fi
  capture fail "$slug"
  if [[ "$optional" == "optional" ]]; then
    log "SKIP step $STEP click '$needle' (optional)"
    return 1
  fi
  log "FAIL step $STEP click '$needle' — $out"
  FAIL=$((FAIL + 1))
  return 1
}

type_label() {
  local label="$1"
  local text="$2"
  local tag="$3"
  local attempt=0
  while (( attempt < 3 )); do
    STEP=$((STEP + 1))
    local slug
    slug="$(printf '%02d' "$STEP")-${tag:-type}"
    local out ok
    out="$(cua type-label "$CUA_APP" "$label" "$text" --max "$MACOS_CUA_MAX" 2>&1)" || true
    ok="$(python3 -c "import json,sys; print('yes' if json.loads(sys.stdin.read()).get('ok') else 'no')" <<<"$out" 2>/dev/null || echo no)"
    echo "$out" >"$SHOTS/${slug}.json"
    sleep 0.25
    if [[ "$ok" == "yes" ]] && cua snap "$CUA_APP" --max "$MACOS_CUA_MAX" --mode ax 2>/dev/null | grep -qF "$text"; then
      log "PASS step $STEP type '$label' (verified)"
      PASS=$((PASS + 1))
      capture "$slug" "$slug"
      return 0
    fi
    attempt=$((attempt + 1))
    log "retry type '$label' attempt $attempt"
    sleep 0.35
  done
  capture fail "$slug"
  log "FAIL step $STEP type '$label' — $out"
  FAIL=$((FAIL + 1))
  return 1
}

curl -fsS "http://127.0.0.1:${PORT:-8787}/health" >/dev/null || {
  log "API not on :8787 — run: npm run dev:api:validation"
  exit 1
}

"$ROOT/script/macos_cua_preflight.sh"

log "=== launch + align (token=$FLOW_TOKEN capture=$CUA_CAPTURE) ==="
macos_cua_launch_dev "$FLOW_TOKEN" "CUA Tester" || { log "FAIL launch"; exit 1; }
capture final "00-launch"

if [[ "${CUA_TAB_NAV:-0}" == "1" ]]; then
  log "=== tab navigation (optional) ==="
  click_label "Meet" optional "meet-tab"
  click_label "Circles" "" "circles-tab"
  click_label "Communities" "" "communities-tab"
  click_label "Profile" "" "profile-tab"
fi

log "=== onboarding ==="
click_label "Profile" "" "profile-tab"
click_label "Start profile setup" "" "start-setup" || click_label "About you step" optional "about-step"
type_label "What should we call you?" "CUA Tester" "name-field" || type_label "Your name" "CUA Tester" "name-alt"
type_label "Where are you based?" "San Francisco" "city-field" || type_label "City" "San Francisco" "city-alt"
# Jazz + Books are pre-selected in draftOnboardingInterests — clicking toggles them OFF.
log "SKIP interest chips (defaults Jazz+Books already selected)"
click_label "Continue" "" "continue-basics"
export FLOW_TOKEN
# Wait for async PATCH + step advance (API is source of truth).
basics_ok=0
deadline=$((SECONDS + 20))
while (( SECONDS < deadline )); do
  if assert_profile_basics_integration "CUA Tester" "San Francisco" Jazz Books; then
    basics_ok=1
    break
  fi
  if assert_basics_saved_api && assert_basics_advanced && ! ui_tree_contains "Profile could not be saved"; then
    basics_ok=1
    break
  fi
  sleep 0.5
done
if (( basics_ok == 1 )); then
  log "PASS basics saved + integrated (name, city, interests on API)"
  PASS=$((PASS + 1))
else
  log "FAIL basics integration — profile PATCH did not persist expected fields"
  capture fail "basics-save-error"
  FAIL=$((FAIL + 1))
fi

log "=== voice reflection ==="
if (( FAIL > 0 )); then
  log "SKIP voice — prior step failures"
else
if ! ui_tree_contains "Your answer"; then
  click_label "Voice profile step" optional "voice-step"
fi
REFLECT=(
  "Hosting small dinner parties energizes me."
  "I open up by asking thoughtful questions."
  "I could talk for hours about jazz and books."
)
for i in "${!REFLECT[@]}"; do
  type_label "Your answer" "${REFLECT[$i]}" "reflect-$((i+1))"
  if [[ "$i" -lt 2 ]]; then
    click_label "Next prompt" "" "next-prompt-$((i+1))"
  else
    click_label "Save voice profile" "" "save-voice"
  fi
  sleep 0.6
done
placement_ok=0
deadline=$((SECONDS + 30))
while (( SECONDS < deadline )); do
  if assert_placement_integration; then
    placement_ok=1
    break
  fi
  sleep 0.75
done
if (( placement_ok == 1 )); then
  log "PASS voice profile created placement on API"
  PASS=$((PASS + 1))
else
  log "FAIL placement missing after voice profile save"
  capture fail "placement-missing"
  FAIL=$((FAIL + 1))
fi
fi

log "=== post-onboarding tabs ==="
if (( FAIL == 0 )); then
click_label "Circles" "" "circles-post"
click_label "Communities" "" "communities-post"
click_label "Meet" "" "meet-post"
greeting_ok=0
deadline=$((SECONDS + 20))
while (( SECONDS < deadline )); do
  if ui_tree_contains "Good evening, CUA"; then
    greeting_ok=1
    break
  fi
  sleep 0.5
done
if (( greeting_ok == 1 )); then
  log "PASS meet greeting uses saved profile name (CUA Tester)"
  PASS=$((PASS + 1))
else
  log "FAIL meet greeting missing saved profile name"
  capture fail "meet-greeting"
  FAIL=$((FAIL + 1))
fi
click_label "Profile" "" "profile-post"
profile_name_ok=0
deadline=$((SECONDS + 15))
while (( SECONDS < deadline )); do
  if ui_tree_contains "CUA Tester"; then
    profile_name_ok=1
    break
  fi
  sleep 0.5
done
if (( profile_name_ok == 1 )); then
  log "PASS profile tab shows saved display name"
  PASS=$((PASS + 1))
else
  log "FAIL profile tab missing CUA Tester"
  capture fail "profile-name"
  FAIL=$((FAIL + 1))
fi

PLACEMENT_TOKEN="$(cua_session_token)"
if [[ -n "$PLACEMENT_TOKEN" ]] && assert_placement_integration; then
  log "PASS placement on API before sign-out"
  PASS=$((PASS + 1))
else
  log "FAIL placement missing before sign-out"
  FAIL=$((FAIL + 1))
fi

log "=== sign out ==="
click_label "Settings" optional "settings-gear" "$MACOS_CUA_MAX"
click_label "Log out" "" "logout-menu" "$MACOS_CUA_MAX_MODAL"
click_label "Sign out" "" "signout-confirm" "$MACOS_CUA_MAX_MODAL"
capture final "99-signed-out"

log "=== re-auth + delete account ==="
macos_cua_launch_dev "$FLOW_TOKEN" "CUA Tester" || { log "FAIL re-auth launch"; FAIL=$((FAIL + 1)); }
click_label "Profile" optional "profile-reauth"
click_label "Settings" optional "settings-reauth" "$MACOS_CUA_MAX"
click_label "Delete account" "" "delete-menu" "$MACOS_CUA_MAX_MODAL"
sleep 0.4
cua_click_last_label "Delete account" "$MACOS_CUA_MAX_MODAL" || click_label "Delete account" "" "delete-confirm" "$MACOS_CUA_MAX_MODAL"
sleep 1
capture final "99-deleted"
DELETE_RAN=1
fi

log "=== API / UI checks ==="
if [[ "${DELETE_RAN:-0}" == "1" ]]; then
if ui_tree_contains "Sign in with Apple" || ui_tree_contains "Continue with Google"; then
  log "PASS welcome screen after delete"
  PASS=$((PASS + 1))
else
  log "FAIL expected welcome screen after delete"
  FAIL=$((FAIL + 1))
fi
if assert_account_deleted_api; then
  log "PASS account deleted on API (profile 404)"
  PASS=$((PASS + 1))
else
  log "FAIL account still reachable on API after delete"
  FAIL=$((FAIL + 1))
fi
fi

SUMMARY="pass=$PASS fail=$FAIL token=$FLOW_TOKEN shots=$SHOTS capture=$CUA_CAPTURE"
log "=== SUMMARY $SUMMARY ==="
echo "$SUMMARY" >"$OUT/summary.txt"
exit $(( FAIL > 0 ? 1 : 0 ))
