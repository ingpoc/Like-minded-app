#!/usr/bin/env bash
# idb_ctl.sh — thin wrapper around idb for validation testing.
# Usage:
#   ./validation/idb_ctl.sh <command> [args...]
# Commands:
#   describe                 — full AX tree as compact JSON
#   buttons                  — just button labels + frames
#   tap "<label>"            — tap a button by AX label
#   tap-id "<identifier>"    — tap by accessibility identifier (prefers Button)
#   tap-point <x> <y>        — tap raw coordinates
#   type "<text>"            — type into focused field
#   screenshot <out.png>     — screenshot to path
#   swipe-up / swipe-down    — standard swipes
#   wait <secs>              — sleep
#   home                     — press home button
# Requires: IDB_UDID env (auto-resolves to first booted iPhone if unset)

set -euo pipefail
UDID="${IDB_UDID:-$(xcrun simctl list devices booted 2>/dev/null | grep -oE '\([A-F0-9-]+\)' | head -1 | tr -d '()')}"
export IDB_UDID="$UDID"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
      | { read x y; echo "→ tap '$label' at ($x,$y)" >&2; idb ui tap --duration 0.05 "$x" "$y" >/dev/null 2>&1; }
    ;;
  tap-id)
    identifier="$1"
    idb ui describe-all --json 2>/dev/null \
      | python3 -c "
import json,sys
identifier = sys.argv[1]
data = json.load(sys.stdin)
buttons = [e for e in data if e.get('type') == 'Button' and e.get('AXIdentifier') == identifier]
candidates = buttons or [e for e in data if e.get('AXIdentifier') == identifier]
for e in candidates:
    f=e['frame']
    print(f\"{f['x']+f['width']/2:.0f} {f['y']+f['height']/2:.0f}\")
    sys.exit(0)
sys.exit(1)
" "$identifier" \
      | { read x y; echo "→ tap-id '$identifier' at ($x,$y)" >&2; idb ui tap --duration 0.05 "$x" "$y" >/dev/null 2>&1; }
    ;;
  tap-point)
    idb ui tap --duration 0.05 "$1" "$2" >/dev/null 2>&1
    echo "→ tap ($1,$2)" >&2
    ;;
  type)
    idb ui text "$1" >/dev/null 2>&1
    echo "→ typed '$1'" >&2
    ;;
  screenshot)
    out="$1"
    mkdir -p "$(dirname "$out")"
    idb screenshot --mode ui "$out" >/dev/null 2>&1 || xcrun simctl io booted screenshot "$out" 2>/dev/null
    echo "→ screenshot saved $out" >&2
    ;;
  swipe-up)
    idb ui swipe 200 700 200 100 >/dev/null 2>&1
    echo "→ swipe up" >&2
    ;;
  swipe-down)
    idb ui swipe 200 100 200 700 >/dev/null 2>&1
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
