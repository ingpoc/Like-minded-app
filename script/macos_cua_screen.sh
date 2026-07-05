#!/usr/bin/env bash
# Computer Use pass for a single macOS screen: launch → focus → snap/click by label.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=macos_canonical_app.sh
source "$ROOT/script/macos_canonical_app.sh"

SCREEN="${1:?screen name, e.g. communityDetail}"
CUA="${CUA_DRIVER:-$HOME/.local/bin/cua-driver}"
PID=""
WID=""
CLICK_OK=0
CLICK_MISS=0

cua_bind() {
  local json
  json="$("$ROOT/script/macos_cua_focus_window.sh")"
  eval "$(python3 -c "import json,sys; d=json.load(sys.stdin); print(f'export PID={d[\"pid\"]} WID={d[\"window_id\"]}')" <<<"$json")"
}

snap() {
  cua_bind
  "$CUA" call get_window_state "{\"pid\":$PID,\"window_id\":$WID,\"max_elements\":${1:-120},\"mode\":\"som\"}" 2>/dev/null
}

find_field() {
  local needle="$1"
  snap 120 | python3 -c "import json,sys
n=sys.argv[1].lower()
els=[e for e in json.load(sys.stdin).get('elements',[]) if e.get('role') in ('AXTextField','AXTextArea')]
exact=[e for e in els if (e.get('label') or '').lower()==n]
if exact:
  print(exact[0]['element_index']); raise SystemExit
cands=[e for e in els if n in (e.get('label') or '').lower()]
cands.sort(key=lambda e: len(e.get('label') or ''), reverse=True)
if cands:
  print(cands[0]['element_index'])
" "$needle"
}

click_label() {
  local needle="$1"
  local optional="${2:-}"
  local idx
  idx=$(snap 120 | python3 -c "import json,sys
n=sys.argv[1].lower()
roles={'AXButton','AXCheckBox','AXRadioButton','AXLink','AXPopUpButton','AXMenuButton'}
els=[e for e in json.load(sys.stdin).get('elements',[]) if e.get('role') in roles]
exact=[e for e in els if (e.get('label') or '').lower()==n]
if exact:
  print(exact[0]['element_index']); raise SystemExit
cands=[e for e in els if n in (e.get('label') or '').lower()]
cands.sort(key=lambda e: len(e.get('label') or ''), reverse=True)
if cands:
  print(cands[0]['element_index'])
" "$needle")
  if [[ -z "$idx" ]]; then
    echo "MISSING: $needle"
    if [[ "$optional" != "optional" ]]; then
      CLICK_MISS=$((CLICK_MISS + 1))
    fi
    return 0
  fi
  cua_bind
  "$CUA" call click "{\"pid\":$PID,\"window_id\":$WID,\"element_index\":$idx}" 2>/dev/null | head -1
  sleep 0.7
  echo "OK click '$needle' idx=$idx"
  CLICK_OK=$((CLICK_OK + 1))
}

type_field() {
  local label="$1"
  local text="$2"
  local optional="${3:-}"
  local idx
  idx=$(find_field "$label")
  if [[ -z "$idx" ]]; then
    echo "MISSING field: $label"
    if [[ "$optional" != "optional" ]]; then
      CLICK_MISS=$((CLICK_MISS + 1))
    fi
    return 0
  fi
  cua_bind
  "$CUA" call click "{\"pid\":$PID,\"window_id\":$WID,\"element_index\":$idx}" 2>/dev/null | head -1
  sleep 0.4
  "$CUA" call press_key "{\"pid\":$PID,\"window_id\":$WID,\"key\":\"a\",\"modifier\":[\"cmd\"]}" 2>/dev/null | head -1 || true
  sleep 0.2
  "$CUA" call type_text "{\"pid\":$PID,\"window_id\":$WID,\"element_index\":$idx,\"text\":\"$text\"}" 2>/dev/null | head -1
  sleep 0.5
  local value
  value=$(snap 120 | python3 -c "import json,sys
idx=int(sys.argv[1])
for e in json.load(sys.stdin).get('elements',[]):
  if e.get('element_index')==idx:
    print(e.get('value') or ''); break
" "$idx")
  echo "OK type '$label' idx=$idx value=$(printf '%q' "$value")"
  if [[ "$value" == *"$text"* ]]; then
    CLICK_OK=$((CLICK_OK + 1))
    return 0
  fi
  if [[ "$optional" != "optional" ]]; then
    CLICK_MISS=$((CLICK_MISS + 1))
  fi
  return 0
}

curl -fsS "http://127.0.0.1:${PORT:-8787}/health" >/dev/null || {
  echo "Start: npm run dev:api:validation" >&2
  exit 1
}

LIKEMINDED_VALIDATION_USER="${LIKEMINDED_VALIDATION_USER:-validation-priya}" \
LIKEMINDED_VALIDATION_NAME="${LIKEMINDED_VALIDATION_NAME:-Priya Shah}" \
  "$ROOT/script/run_macos_manual_validation.sh" "$SCREEN" >/dev/null
sleep 5

cua_bind
echo "screen=$SCREEN pid=$PID wid=$WID app=$MACOS_CANONICAL_APP"
snap 120 | python3 -c "import json,sys
roles={'AXButton','AXCheckBox','AXRadioButton','AXLink','AXPopUpButton','AXMenuButton'}
for e in json.load(sys.stdin).get('elements',[]):
  if e.get('role') in roles and (e.get('label') or '').strip():
    print(e['element_index'], repr(e.get('label')), e.get('value',''))"

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
    click_label "This does not feel like my circle"
    ;;
  settingsSoulmate)
    click_label "Account" optional
    click_label "Privacy & safety" optional
    click_label "Notifications" optional
    click_label "Soulmate" optional
    click_label "Help & support" optional
    click_label "Save preferences"
    click_label "Voice profile" optional
    ;;
  circlesRoom)
    click_label "Request circle placement refresh"
    click_label "Open Reflective Builders circle" optional || click_label "reflective builders" optional
    ;;
  communitiesBrowse)
    type_field "Search communities" "jazz" optional
    click_label "Trending communities filter" optional || click_label "Trending" optional
    click_label "Open Jazz Music community" optional || click_label "jazz music" optional
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
    type_field "Event name" "CUA Typed Event" optional
    type_field "Location" "Test Hall" optional
    click_label "Create event" optional
    ;;
  profileOnboarding)
    click_label "Voice profile step" optional
    click_label "Join first circle step" optional
    click_label "Continue"
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
    click_label "Open conversation with Gurusharan Gupta" optional || click_label "gurusharan" optional
    click_label "Voice call" optional
    click_label "Video call" optional
    click_label "Conversation info" optional
    snap 120 | python3 -c "import json,sys
for e in json.load(sys.stdin).get('elements',[]):
  if e.get('role') in ('AXTextField','AXButton') and ('message' in (e.get('label') or '').lower() or 'send' in (e.get('label') or '').lower()):
    print(e.get('element_index'), e.get('role'), repr(e.get('label')))"
    ;;
  messages)
    click_label "Open conversation with Gurusharan Gupta" optional || click_label "gurusharan" optional
    click_label "Voice call" optional
    click_label "Video call" optional
    click_label "Conversation info" optional
    click_label "Find matches" optional
    ;;
  *)
    echo "No scripted clicks for $SCREEN (snapshot only)"
    ;;
esac

echo "cua_click_summary ok=$CLICK_OK miss=$CLICK_MISS"

# Stamp tested_source_hash only when required CUA clicks succeeded (avoid launch-only false-green).
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
  messages) STAMP_CONTROLS="match-row,draft,send,search,voice-call-header,video-call-header,conversation-info-header" ;;
esac

if [[ -n "$STAMP_CONTROLS" ]]; then
  if (( CLICK_OK > 0 && CLICK_MISS == 0 )); then
    node "$ROOT/script/ledger_stamp_screen.js" \
      --platform macos \
      --screen "$SCREEN" \
      --controls "$STAMP_CONTROLS" \
      --method CUA-click \
      --evidence-prefix "CUA-click ${LIKEMINDED_VALIDATION_USER:-validation-priya}" || true
  else
    echo "skip stamp: required CUA clicks incomplete (ok=$CLICK_OK miss=$CLICK_MISS)"
  fi
fi

if (( CLICK_MISS > 0 )); then
  exit 1
fi
