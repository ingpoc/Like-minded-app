#!/usr/bin/env bash
# CUA audit: find clickable-looking controls that do not navigate or mutate backend state.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=macos_canonical_app.sh
source "$ROOT/script/macos_canonical_app.sh"
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
  "$CUA" call get_window_state "{\"pid\":$PID,\"window_id\":$WID,\"max_elements\":${1:-80},\"mode\":\"som\"}" 2>/dev/null
}

click_idx() {
  local idx="$1"
  cua_bind
  "$CUA" call click "{\"pid\":$PID,\"window_id\":$WID,\"element_index\":$idx}" 2>/dev/null | head -1
  sleep 0.8
}

launch_screen() {
  local screen="$1"
  pkill -x LikemindedMac 2>/dev/null || true
  sleep 0.5
  LIKEMINDED_VALIDATION_USER="${LIKEMINDED_VALIDATION_USER:-validation-priya}" \
  LIKEMINDED_VALIDATION_NAME="${LIKEMINDED_VALIDATION_NAME:-Priya Shah}" \
    "$ROOT/script/run_macos_manual_validation.sh" "$screen" >/dev/null
  sleep 2
  cua_bind
}

echo "# macOS CUA static-control audit $(date -u +%Y-%m-%dT%H:%M:%SZ)"

SCREENS=(
  welcome meetOverview circlesRoom circleDetail profileEdit chat communitiesBrowse
  communityDetail communityMembers createEvent meetRecap meetVideoCall myProfile
  soulmateOverview soulmateDiscover soulmateDetail messages notifications
  profileOnboarding profileSignals settingsSoulmate createCommunity
)

for screen in "${SCREENS[@]}"; do
  echo ""
  echo "== screen=$screen =="
  launch_screen "$screen" || { echo "LAUNCH_FAIL $screen"; continue; }
  echo "pid=$PID wid=$WID"
  snap 90 | python3 -c "
import json,sys
els=json.load(sys.stdin).get('elements',[])
roles={'AXButton','AXCheckBox','AXTextField','AXStaticText','AXGroup'}
for e in els:
  role=e.get('role')
  if role not in roles: continue
  idx=e.get('element_index')
  if idx is None or idx>60: continue
  label=(e.get('label') or e.get('value') or '')[:80]
  low=label.lower()
  if any(k in low for k in ['planned','privacy','notification','connected','appearance','language','help','voice call','video call','conversation info','community options','guidelines','conversation prompts','essay thread','saved recommendation','sign in with apple','retake voice','resources','highlights']):
    print(f'SUSPECT {idx} {role} {label!r}')
for e in els:
  if e.get('role')=='AXButton' and (e.get('element_index') or 99)<35:
    print(f'BUTTON {e[\"element_index\"]} {e.get(\"label\")!r}')
" || echo "SNAP_FAIL $screen"
done

# Targeted click probes on known static suspects
echo ""
echo "== targeted probes =="

probe_no_nav() {
  local screen="$1" label_needle="$2" desc="$3"
  launch_screen "$screen"
  local idx before after
  before=$(snap 40 | python3 -c "import json,sys; print(json.load(sys.stdin).get('window_title',''))")
  idx=$(snap 80 | python3 -c "
import json,sys
n=sys.argv[1].lower()
els=[e for e in json.load(sys.stdin).get('elements',[]) if e.get('role')=='AXButton']
for e in els:
  lab=(e.get('label') or '').lower()
  if n in lab:
    print(e['element_index']); raise SystemExit
print('')
" "$label_needle")
  if [[ -z "$idx" ]]; then
    echo "PROBE $desc | MISSING_BUTTON | needle=$label_needle"
    return
  fi
  click_idx "$idx"
  after=$(snap 40 | python3 -c "import json,sys; print(json.load(sys.stdin).get('window_title',''))")
  echo "PROBE $desc | idx=$idx | before=$before | after=$after | needle=$label_needle"
}

launch_screen settingsSoulmate
for needle in "privacy" "notifications" "connected apps" "appearance" "language" "help"; do
  idx=$(snap 80 | python3 -c "
import json,sys
n=sys.argv[1].lower()
for e in json.load(sys.stdin).get('elements',[]):
  lab=(e.get('label') or '').lower()
  if e.get('role') in ('AXButton','AXStaticText','AXGroup') and n in lab:
    print(e.get('role'), e.get('element_index'), repr(e.get('label'))); break
" "$needle" || true)
  echo "SETTINGS_ROW $needle -> ${idx:-NOT_IN_AX_TREE}"
done

probe_no_nav communityDetail "community options" "community ellipsis"
probe_no_nav communityDetail "community guidelines" "resources row 1"
probe_no_nav communityDetail "conversation prompts" "resources row 2"
launch_screen communityDetail
click_idx $(snap 80 | python3 -c "
import json,sys
for e in json.load(sys.stdin).get('elements',[]):
  if e.get('role')=='AXButton' and (e.get('label') or '').lower()=='highlights':
    print(e['element_index']); break
" 2>/dev/null || echo "")
sleep 0.5
probe_no_nav communityDetail "best essay thread" "highlights row 1"

launch_screen chat
for needle in "voice call planned" "video call planned" "conversation info planned"; do
  idx=$(snap 80 | python3 -c "
import json,sys
n=sys.argv[1].lower()
for e in json.load(sys.stdin).get('elements',[]):
  if (e.get('label') or '').lower()==n:
    print(e.get('role'), e.get('element_index')); break
" "$needle" || true)
  echo "CHAT_ICON $needle -> ${idx:-NOT_BUTTON}"
done

echo ""
echo "AUDIT_DONE"
