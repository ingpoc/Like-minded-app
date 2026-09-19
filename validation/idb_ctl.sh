#!/usr/bin/env bash
# idb_ctl.sh — thin wrapper around idb for validation testing.
# Usage:
#   ./validation/idb_ctl.sh <command> [args...]
# Commands:
#   describe                 — full AX tree as compact JSON
#   buttons                  — just button labels + frames
#   tap "<label>"            — tap a button by AX label
#   point-id "<identifier>" [center|top] [viewport] — print tap point (+ viewport bounds)
#   tap-id "<identifier>" [center|top] — tap by accessibility identifier (prefers Button)
#   tap-point <x> <y>        — tap raw coordinates
#   type "<text>"            — type into focused field
#   screenshot <out.png>     — screenshot to path
#   swipe-up / swipe-up-short / swipe-down — standard swipes
#   wait <secs>              — sleep
#   home                     — press home button
# Requires: IDB_UDID env (auto-resolves to first booted iPhone if unset)

set -euo pipefail
UDID="${IDB_UDID:-$(xcrun simctl list devices booted 2>/dev/null | grep -oE '\([A-F0-9-]+\)' | head -1 | tr -d '()')}"
export IDB_UDID="$UDID"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

resolve_id_point() {
  local identifier="$1"
  local anchor="${2:-center}"
  local include_viewport="${3:-point}"
  if [[ "$anchor" != "center" && "$anchor" != "top" ]]; then
    echo "identifier anchor must be center or top" >&2
    return 2
  fi
  idb ui describe-all --json 2>/dev/null \
    | python3 -c "
import json,sys,unicodedata

def normalized(value):
    return ' '.join(unicodedata.normalize('NFKC', str(value or '')).split())

identifier = normalized(sys.argv[1])
anchor = sys.argv[2]
include_viewport = sys.argv[3] == 'viewport'
data = json.load(sys.stdin)
application = next((e for e in data if e.get('type') == 'Application'), None)
app_frame = (application or {}).get('frame') or {}
required = ('x', 'y', 'width', 'height')
if not all(isinstance(app_frame.get(key), (int, float)) for key in required):
    sys.exit(1)
left = float(app_frame['x'])
top = float(app_frame['y'])
right = left + float(app_frame['width'])
bottom = top + float(app_frame['height'])
matches = [
    e for e in data
    if any(
        normalized(e.get(key)) == identifier
        for key in ('AXIdentifier', 'AXUniqueId')
    )
]
buttons = [e for e in matches if e.get('type') == 'Button']
points = []
for e in buttons or matches:
    f=e.get('frame') or {}
    if f.get('width', 0) <= 0 or f.get('height', 0) <= 0:
        continue
    tap_x = f['x'] + f['width'] / 2
    tap_y = f['y'] + f['height'] / 2
    if anchor == 'top':
        tap_y = f['y'] + min(f['height'] / 2, 24)
    if left <= tap_x <= right and tap_y >= top:
        points.append((tap_y > bottom, tap_y, tap_x))
if not points:
    sys.exit(1)
_, tap_y, tap_x = min(points)
fields = [tap_x, tap_y]
if include_viewport:
    fields.extend((left, top, right, bottom))
print(' '.join(f'{value:.0f}' for value in fields))
sys.exit(0)
sys.exit(1)
" "$identifier" "$anchor" "$include_viewport"
}

cmd="${1:-describe}"
shift || true

case "$cmd" in
  describe)
    idb ui describe-all --json 2>/dev/null
    ;;
  buttons)
    idb ui describe-all --json 2>/dev/null \
      | python3 -c "import json,sys; data=json.load(sys.stdin); [print(f\"{e['AXLabel']!r:50} type={e['type']} frame=({e['frame']['x']:.0f},{e['frame']['y']:.0f}) {e['frame']['width']:.0f}x{e['frame']['height']:.0f}\") for e in data if e.get('type')=='Button']"
    ;;
  controls)
    idb ui describe-all --json 2>/dev/null \
      | python3 -c "import json,sys; data=json.load(sys.stdin); [print(f\"{e['AXLabel'] or e.get('AXValue') or ''!r:50} type={e['type']:12} frame=({e['frame']['x']:.0f},{e['frame']['y']:.0f}) {e['frame']['width']:.0f}x{e['frame']['height']:.0f}\") for e in data if e.get('type') in ('Button','TextField','TextView','Switch','Slider','StaticText','Image')]"
    ;;
  tap)
    label="$1"
    idb ui describe-all --json 2>/dev/null \
      | python3 -c "
import json,sys
label = sys.argv[1]
data = json.load(sys.stdin)
for e in data:
    if e.get('AXLabel') != label:
        continue
    if e.get('type') in ('Button', 'Link', 'Image', 'Other'):
        f=e['frame']
        print(f\"{f['x']+f['width']/2:.0f} {f['y']+f['height']/2:.0f}\")
        sys.exit(0)
sys.exit(1)
" "$label" \
      | { read x y; echo "→ tap '$label' at ($x,$y)" >&2; idb ui tap "$x" "$y" >/dev/null 2>&1; }
    ;;
  point-id)
    identifier="$1"
    anchor="${2:-center}"
    include_viewport="${3:-point}"
    resolve_id_point "$identifier" "$anchor" "$include_viewport"
    ;;
  tap-id)
    identifier="$1"
    anchor="${2:-center}"
    if ! point="$(resolve_id_point "$identifier" "$anchor")"; then
      echo "tap-id '$identifier' not found in normalized AX inventory" >&2
      exit 1
    fi
    read -r x y <<< "$point"
    echo "→ tap-id '$identifier' anchor=$anchor at ($x,$y)" >&2
    idb ui tap "$x" "$y" >/dev/null 2>&1
    ;;
  tap-point)
    idb ui tap "$1" "$2" >/dev/null 2>&1
    echo "→ tap ($1,$2)" >&2
    ;;
  type)
    idb ui text "$1" >/dev/null 2>&1
    echo "→ typed '$1'" >&2
    ;;
  screenshot)
    out="$1"
    mkdir -p "$(dirname "$out")"
    idb screenshot --mode ui "$out" >/dev/null 2>&1 || xcrun simctl io "$UDID" screenshot "$out" 2>/dev/null
    echo "→ screenshot saved $out" >&2
    ;;
  swipe-up)
    idb ui swipe --duration 0.6 --delta 10 390 700 390 100 >/dev/null 2>&1
    echo "→ swipe up" >&2
    ;;
  swipe-up-short)
    idb ui swipe --duration 0.45 --delta 10 390 700 390 500 >/dev/null 2>&1
    echo "→ short swipe up" >&2
    ;;
  swipe-down)
    idb ui swipe --duration 0.6 --delta 10 390 100 390 700 >/dev/null 2>&1
    echo "→ swipe down" >&2
    ;;
  wait)
    sleep "${1:-1}"
    ;;
  home)
    idb ui button home >/dev/null 2>&1
    ;;
  *)
    echo "Unknown command: $cmd" >&2; exit 1
    ;;
esac
