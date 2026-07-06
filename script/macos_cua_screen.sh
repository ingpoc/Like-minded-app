#!/usr/bin/env bash
# Ledger CUA pass: launch screen → frame window → click/type via macos-cua.py.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=macos_canonical_app.sh
source "$ROOT/script/macos_canonical_app.sh"
# shellcheck source=macos_cua_helpers.sh
source "$ROOT/script/macos_cua_helpers.sh"

SCREEN="${1:?screen name, e.g. communityDetail}"
CLICK_OK=0
CLICK_MISS=0

click_label() {
  local needle="$1"
  local optional="${2:-}"
  local max="${3:-$MACOS_CUA_MAX}"
  local out ok
  out="$(cua click-label-pointer "$CUA_APP" "$needle" --max "$max" 2>&1)" || true
  ok="$(python3 -c "import json,sys; print('yes' if json.loads(sys.stdin.read()).get('ok') else 'no')" <<<"$out" 2>/dev/null || echo no)"
  if [[ "$ok" == "yes" ]]; then
    echo "OK click '$needle'"
    CLICK_OK=$((CLICK_OK + 1))
    return 0
  fi
  echo "MISSING: $needle"
  if [[ "$optional" != "optional" ]]; then
    CLICK_MISS=$((CLICK_MISS + 1))
  fi
}

type_field() {
  local label="$1"
  local text="$2"
  local optional="${3:-}"
  local out ok
  out="$(cua type-label "$CUA_APP" "$label" "$text" --max "$MACOS_CUA_MAX" 2>&1)" || true
  ok="$(python3 -c "import json,sys; print('yes' if json.loads(sys.stdin.read()).get('ok') else 'no')" <<<"$out" 2>/dev/null || echo no)"
  if [[ "$ok" == "yes" ]]; then
    echo "OK type '$label'"
    CLICK_OK=$((CLICK_OK + 1))
    return 0
  fi
  echo "MISSING field: $label"
  if [[ "$optional" != "optional" ]]; then
    CLICK_MISS=$((CLICK_MISS + 1))
  fi
}

curl -fsS "http://127.0.0.1:${PORT:-8787}/health" >/dev/null || {
  echo "Start: npm run dev:api:validation" >&2
  exit 1
}

"$ROOT/script/macos_cua_preflight.sh"

LIKEMINDED_VALIDATION_USER="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}" \
LIKEMINDED_VALIDATION_NAME="${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}" \
  "$ROOT/script/run_macos_manual_validation.sh" "$SCREEN" >/dev/null
macos_wait_main_window 25

macos_cua_session_start

echo "screen=$SCREEN app=$CUA_APP"
cua list-buttons "$CUA_APP" --max "$MACOS_CUA_MAX" | python3 -c "
import json,sys
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    e=json.loads(line)
    print(e['index'], repr(e.get('label')), e.get('value',''))
"

case "$SCREEN" in
  communityDetail)
    click_label "Community options" optional
    click_label "Members"
    click_label "View members"
    click_label "Resources"
    click_label "Community guidelines"
    click_label "Conversation prompts" optional
    click_label "Highlights" optional
    click_label "Best essay thread" optional
    ;;
  circleDetail)
    click_label "Message circle"
    LIKEMINDED_VALIDATION_USER="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}" \
    LIKEMINDED_VALIDATION_NAME="${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}" \
      "$ROOT/script/run_macos_manual_validation.sh" "$SCREEN" >/dev/null
    macos_wait_main_window 20
    macos_cua_session_start
    click_label "Circle options"
    click_label "This does not feel like my circle"
    click_label "Upcoming circle meet row" optional
    ;;
  settingsSoulmate)
    click_label "Soulmate" optional
    click_label "Account" optional
    click_label "Privacy & safety" optional
    click_label "Notifications" optional
    click_label "Help & support" optional
    click_label "Visible in discover" optional
    click_label "Visible only after both like" optional
    click_label "Save preferences" optional
    click_label "Log out" optional "$MACOS_CUA_MAX_MODAL"
    cua_dismiss_modal
    click_label "Delete account" optional "$MACOS_CUA_MAX_MODAL"
    cua_dismiss_modal
    ;;
  circlesRoom)
    click_label "Request circle placement refresh"
    click_label "Open Reflective Builders circle" optional || click_label "reflective builders" optional
    ;;
  communitiesBrowse)
    click_label "Trending communities filter" optional || click_label "Trending" optional
    click_label "Create a community"
    click_label "Open Design Circle community" optional || click_label "design circle" optional
    ;;
  notifications)
    click_label "Unread notifications filter" optional || click_label "Unread" optional
    click_label "Mark all notifications as read"
    click_label "Refresh notifications"
    ;;
  meetRecap)
    type_field "Add a private note" "CUA recap note proof" optional
    click_label "Save note"
    click_label "Message Gurusharan Gupta" optional || click_label "Message " optional
    ;;
  createEvent)
    click_label "Listening Session" optional
    click_label "Add cover" optional
    click_label "Create event"
    ;;
  profileOnboarding)
    click_label "Continue" optional
    click_label "Voice profile step" optional
    click_label "Join your first circle step" optional || click_label "Join first circle step" optional
    ;;
  myProfile)
    click_label "Share profile"
    click_label "Retake voice profile" optional
    ;;
  meetOverview)
    click_label "Join Reflective Builders meetup" optional || click_label "reflective builders meetup" optional
    click_label "Saturday Community meetup available"
    click_label "Saturday Community meetup not available"
    click_label "Sunday Circle meetup not available"
    click_label "Sunday Circle meetup available"
    ;;
  createCommunity)
    click_label "Create community"
    ;;
  profileSignals)
    click_label "Done"
    ;;
  profileEdit)
    click_label "Back to profile"
    ;;
  soulmateOverview)
    click_label "How it works"
    ;;
  soulmateDiscover)
    click_label "New matches"
    click_label "Open Gurusharan Gupta" optional || click_label "Open " optional
    ;;
  soulmateDetail)
    click_label "Message"
    ;;
  communityMembers)
    type_field "Search members" "priya" optional
    ;;
  chat)
    click_label "Open conversation with Arjun" || click_label "Open conversation with Meera"
    click_label "Voice call" optional
    click_label "Video call" optional
    click_label "Conversation info" optional
    ;;
  messages)
    click_label "Close" optional
    click_label "Open conversation with Ananya" || click_label "Open conversation with Meera"
    click_label "Voice call" optional
    click_label "Video call" optional
    click_label "Conversation info" optional
    ;;
  meetVideoCall)
    click_label "Mute microphone" "" "$MACOS_CUA_MAX_MODAL"
    click_label "Leave meetup" "" "$MACOS_CUA_MAX_MODAL"
    ;;
  *)
    echo "No scripted clicks for $SCREEN (snapshot only)"
    ;;
esac

echo "cua_click_summary ok=$CLICK_OK miss=$CLICK_MISS"

STAMP_CONTROLS=""
case "$SCREEN" in
  meetOverview) STAMP_CONTROLS="join-meetup,rsvp-sat-yes,rsvp-sat-no,rsvp-sun-yes,rsvp-sun-no,past-row" ;;
  communityDetail) STAMP_CONTROLS="view-members,event-rows,join-leave,community-options,resources-guidelines,resources-prompts,highlights-essay,highlights-recommendation" ;;
  circleDetail) STAMP_CONTROLS="message-circle,placement-concern,upcoming-meet" ;;
  circlesRoom) STAMP_CONTROLS="concern-btn,circle-card" ;;
  communitiesBrowse) STAMP_CONTROLS="search,filter-pills,create-card,community-card" ;;
  communityMembers) STAMP_CONTROLS="sidebar-nav,search,filter-pills,member-rows" ;;
  notifications) STAMP_CONTROLS="notif-filter-pills,mark-all-read,activity-filter-pills,refresh,rows" ;;
  meetRecap) STAMP_CONTROLS="recap-note,save-note,message-match" ;;
  createEvent) STAMP_CONTROLS="event-type-meetup,event-type-listening-session,event-type-jam-session,event-fields,add-cover,add-tags,create-event,bottom-nav,traffic-lights" ;;
  profileOnboarding) STAMP_CONTROLS="step-rows,form-lines,continue,voice-profile-step,join-circle-step" ;;
  profileEdit) STAMP_CONTROLS="comm-pills,trait-sliders,save" ;;
  soulmateOverview) STAMP_CONTROLS="enable-toggle,how-it-works" ;;
  soulmateDiscover) STAMP_CONTROLS="distance-slider,filter-pills,new-matches,match-card" ;;
  soulmateDetail) STAMP_CONTROLS="message,about-panels" ;;
  settingsSoulmate) STAMP_CONTROLS="sidebar-honesty,account-settings,privacy-safety,notifications-settings,connected-apps,appearance,language,help-support,log-out,delete-account,soulmate-toggle,view-profile,voice-profile,discovery-preference,age-range,visibility" ;;
  meetVideoCall) STAMP_CONTROLS="tiles,mute,leave" ;;
  myProfile) STAMP_CONTROLS="share-profile,edit-profile,retake-voice,signal-cards,interest-tags" ;;
  createCommunity) STAMP_CONTROLS="name,summary,themes,submit" ;;
  profileSignals) STAMP_CONTROLS="share-profile" ;;
  chat) STAMP_CONTROLS="match-row,draft,send,search,voice-call-header,video-call-header,conversation-info-header" ;;
  messages) STAMP_CONTROLS="match-row,draft,send,close,voice-call-header,video-call-header,conversation-info-header" ;;
esac

if [[ -n "$STAMP_CONTROLS" ]]; then
  if (( CLICK_OK > 0 && CLICK_MISS == 0 )); then
    node "$ROOT/script/ledger_stamp_screen.js" \
      --platform macos \
      --screen "$SCREEN" \
      --controls "$STAMP_CONTROLS" \
      --method CUA-click \
      --evidence-prefix "CUA-click ${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}" || true
  else
    echo "skip stamp: required CUA clicks incomplete (ok=$CLICK_OK miss=$CLICK_MISS)"
  fi
fi

if (( CLICK_MISS > 0 )); then
  exit 1
fi
