#!/usr/bin/env bash
# Snap → click by element index → snap (cua-driver requires fresh get_window_state before each click).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CUA="${CUA_DRIVER:-$HOME/.local/bin/cua-driver}"
chmod +x "$ROOT/script/macos_cua_window.sh" 2>/dev/null || true

win_json="$("$ROOT/script/macos_cua_window.sh")"
PID="$(echo "$win_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["pid"])')"
WID="$(echo "$win_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["window_id"])')"

snap() {
  "$CUA" call get_window_state "{\"pid\":$PID,\"window_id\":$WID,\"max_elements\":${1:-40},\"mode\":\"som\"}" 2>/dev/null
}

click_idx() {
  snap 40 >/dev/null
  "$CUA" call click "{\"pid\":$PID,\"window_id\":$WID,\"element_index\":$1}" 2>/dev/null
  sleep 0.6
}

find_idx() {
  local needle="$1"
  snap 40 | python3 -c "
import json,sys
needle=sys.argv[1].lower()
for e in json.load(sys.stdin).get('elements',[]):
    lab=(e.get('label') or '').lower()
    if needle in lab and e.get('role')=='AXButton':
        print(e['element_index']); break
" "$needle"
}

echo "pid=$PID window_id=$WID"
echo "--- RSVP Saturday Not ---"
idx="$(find_idx 'saturday community meetup not')"
echo "index=$idx"
click_idx "$idx"
snap 40 | python3 -c "
import json,sys
d=json.load(sys.stdin)
for e in d.get('elements',[]):
    if 'saturday community' in (e.get('label') or '').lower():
        print(e.get('label'), '->', e.get('value',''))
"

echo "--- RSVP Sunday Available ---"
idx="$(find_idx 'sunday circle meetup available')"
click_idx "$idx"
snap 40 | python3 -c "
import json,sys
d=json.load(sys.stdin)
for e in d.get('elements',[]):
    if 'sunday circle' in (e.get('label') or '').lower():
        print(e.get('label'), '->', e.get('value',''))
"

echo "--- Join meetup ---"
idx="$(find_idx 'join')"
echo "join index=$idx"
click_idx "$idx"
snap 50 | python3 -c "
import json,sys
d=json.load(sys.stdin)
labels=[(e.get('element_index'), e.get('label')) for e in d.get('elements',[]) if e.get('role')=='AXButton' and e.get('element_index',99)<20]
print('buttons:', labels[:12])
"
