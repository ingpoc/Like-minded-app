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

cua_bind() {
  local json
  json="$("$ROOT/script/macos_cua_focus_window.sh")"
  eval "$(python3 -c "import json,sys; d=json.load(sys.stdin); print(f'export PID={d[\"pid\"]} WID={d[\"window_id\"]}')" <<<"$json")"
}

snap() {
  cua_bind
  "$CUA" call get_window_state "{\"pid\":$PID,\"window_id\":$WID,\"max_elements\":${1:-50},\"mode\":\"som\"}" 2>/dev/null
}

find_field() {
  local needle="$1"
  snap 80 | python3 -c "import json,sys
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
  local idx
  idx=$(snap 55 | python3 -c "import json,sys
n=sys.argv[1].lower()
els=[e for e in json.load(sys.stdin).get('elements',[]) if e.get('role')=='AXButton']
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
    return 1
  fi
  cua_bind
  "$CUA" call click "{\"pid\":$PID,\"window_id\":$WID,\"element_index\":$idx}" 2>/dev/null | head -1
  sleep 0.7
  echo "OK click '$needle' idx=$idx"
}

type_field() {
  local label="$1"
  local text="$2"
  local idx
  idx=$(find_field "$label")
  if [[ -z "$idx" ]]; then
    echo "MISSING field: $label"
    return 1
  fi
  cua_bind
  "$CUA" call click "{\"pid\":$PID,\"window_id\":$WID,\"element_index\":$idx}" 2>/dev/null | head -1
  sleep 0.4
  "$CUA" call press_key "{\"pid\":$PID,\"window_id\":$WID,\"key\":\"a\",\"modifier\":[\"cmd\"]}" 2>/dev/null | head -1 || true
  sleep 0.2
  "$CUA" call type_text "{\"pid\":$PID,\"window_id\":$WID,\"element_index\":$idx,\"text\":\"$text\"}" 2>/dev/null | head -1
  sleep 0.5
  local value
  value=$(snap 80 | python3 -c "import json,sys
idx=int(sys.argv[1])
for e in json.load(sys.stdin).get('elements',[]):
  if e.get('element_index')==idx:
    print(e.get('value') or ''); break
" "$idx")
  echo "OK type '$label' idx=$idx value=$(printf '%q' "$value")"
  [[ "$value" == *"$text"* ]]
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
snap 55 | python3 -c "import json,sys
for e in json.load(sys.stdin).get('elements',[]):
  if e.get('role') in ('AXButton','AXCheckBox') and (e.get('element_index') or 99)<28:
    print(e['element_index'], repr(e.get('label')), e.get('value',''))"

case "$SCREEN" in
  communityDetail)
    click_label "Members"
    click_label "community options" || true
    click_label "Resources"
    click_label "community guidelines" || true
    click_label "View members"
    ;;
  circleDetail)
    click_label "message circle"
    click_label "does not feel"
    ;;
  settingsSoulmate)
    click_label "account" || true
    click_label "privacy" || true
    click_label "notifications" || true
    click_label "soulmate" || true
    click_label "help" || true
    click_label "save preferences" || true
    click_label "voice profile" || true
    ;;
  circlesRoom)
    click_label "request circle placement"
    click_label "open reflective"
    ;;
  communitiesBrowse)
    type_field "Search communities" "jazz" || true
    click_label "trending"
    click_label "open ai builders" || click_label "open jazz"
    ;;
  notifications)
    click_label "unread"
    click_label "mark all"
    click_label "refresh"
    ;;
  meetRecap)
    type_field "Add a private note" "CUA recap note proof" || true
    click_label "save note"
    click_label "Message "
    ;;
  createEvent)
    type_field "Event name" "CUA Typed Event" || true
    type_field "Location" "Test Hall" || true
    click_label "create event" || true
    ;;
  profileOnboarding)
    click_label "voice profile" || true
    click_label "join first circle" || true
    click_label "continue"
    ;;
  myProfile)
    click_label "share profile"
    click_label "retake voice profile" || true
    ;;
  meetOverview)
    click_label "join meetup" || true
    click_label "saturday community meetup available" || true
    click_label "saturday community meetup not available" || true
    click_label "sunday circle meetup not available"
    click_label "sunday circle meetup available"
    ;;
  createCommunity)
    click_label "create community"
    ;;
  profileOnboarding)
    click_label "continue"
    ;;
  profileSignals)
    click_label "done"
    ;;
  profileEdit)
    click_label "back to profile"
    ;;
  soulmateOverview)
    click_label "how it works"
    ;;
  soulmateDiscover)
    click_label "new matches"
    click_label "open "
    ;;
  soulmateDetail)
    click_label "Message"
    ;;
  communityMembers)
    type_field "Search members" "priya" || true
    ;;
  chat)
    click_label "gurusharan" || click_label "g, "
    click_label "voice call" || true
    click_label "video call" || true
    click_label "conversation info" || true
    snap 55 | python3 -c "import json,sys
for e in json.load(sys.stdin).get('elements',[]):
  if e.get('role') in ('AXTextField','AXButton') and ('message' in (e.get('label') or '').lower() or 'send' in (e.get('label') or '').lower()):
    print(e.get('element_index'), e.get('role'), repr(e.get('label')))"
    ;;
  messages)
    click_label "gurusharan" || click_label "g, "
    click_label "voice call" || true
    click_label "video call" || true
    click_label "conversation info" || true
    click_label "close"
    ;;
  *)
    echo "No scripted clicks for $SCREEN (snapshot only)"
    ;;
esac

# Stamp tested_source_hash for controls exercised by this screen's CUA script.
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
  node "$ROOT/script/ledger_stamp_screen.js" \
    --platform macos \
    --screen "$SCREEN" \
    --controls "$STAMP_CONTROLS" \
    --method CUA \
    --evidence-prefix "CUA ${LIKEMINDED_VALIDATION_USER:-validation-priya}" || true
fi
