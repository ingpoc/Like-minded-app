#!/usr/bin/env bash
# Focus LikemindedMac + align cua-driver overlay on the window's display (multi-monitor).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=macos_canonical_app.sh
source "$ROOT/script/macos_canonical_app.sh"

export MACOS_CUA_FOLLOW_WINDOW="${MACOS_CUA_FOLLOW_WINDOW:-1}"
# Pin with MACOS_CUA_FORCE_DISPLAY=1 MACOS_CUA_DISPLAY=DELL (otherwise follow window).
export MACOS_CUA_APP_PROCESS="${MACOS_CUA_APP_PROCESS:-LikemindedMac}"
export MACOS_CUA_APP_QUARTZ="${MACOS_CUA_APP_QUARTZ:-Likeminded}"
export MACOS_CUA_VIRTUAL_OVERLAY="${MACOS_CUA_VIRTUAL_OVERLAY:-1}"
export MACOS_CUA_NO_FRAME="${MACOS_CUA_NO_FRAME:-1}"
export MACOS_CUA_LOCAL_COORDS="${MACOS_CUA_LOCAL_COORDS:-1}"
W="${LIKEMINDED_MAC_WINDOW_WIDTH:-1200}"
H="${LIKEMINDED_MAC_WINDOW_HEIGHT:-760}"
export LIKEMINDED_MAC_WINDOW_WIDTH="$W"
export LIKEMINDED_MAC_WINDOW_HEIGHT="$H"

PID="$(macos_assert_single_instance)" || exit 1

python3 -c "
from AppKit import NSWorkspace, NSApplicationActivateIgnoringOtherApps
ws = NSWorkspace.sharedWorkspace()
apps = [a for a in ws.runningApplications() if a.bundleIdentifier() == '$MACOS_CANONICAL_BUNDLE_ID']
if not apps:
    raise SystemExit('bundle $MACOS_CANONICAL_BUNDLE_ID not running')
app = apps[0]
app.activateWithOptions_(NSApplicationActivateIgnoringOtherApps)
app.unhide()
" >/dev/null

deadline=$((SECONDS + 12))
while (( SECONDS < deadline )); do
  if python3 -c "
import Quartz, sys
pid = int('$PID')
ws = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
    Quartz.kCGNullWindowID,
)
for w in ws:
    if w.get('kCGWindowOwnerPID') != pid:
        continue
    b = w.get('kCGWindowBounds') or {}
    if float(b.get('Width', 0)) > 400 and float(b.get('Height', 0)) > 300:
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    break
  fi
  sleep 0.5
done

align_json="$(python3 "$ROOT/script/macos_cua_align_displays.py")" || {
  echo "$align_json" >&2
  exit 1
}

export MACOS_CUA_DISPLAY="$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(d.get('target_token') or d.get('display') or 'DELL')
" <<<"$align_json")"

read -r X Y BW BH <<<"$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
b = d.get('bounds') or {}
print(b.get('x', 0), b.get('y', 0), b.get('width', $W), b.get('height', $H))
" <<<"$align_json")"

export LIKEMINDED_MAC_WINDOW_X="$X"
export LIKEMINDED_MAC_WINDOW_Y="$Y"
export LIKEMINDED_MAC_WINDOW_WIDTH="$BW"
export LIKEMINDED_MAC_WINDOW_HEIGHT="$BH"

osascript <<APPLESCRIPT >/dev/null 2>&1 || true
tell application "System Events"
  tell process "$MACOS_CANONICAL_EXEC"
    set frontmost to true
    if (count of windows) > 0 then
      perform action "AXRaise" of window 1
    end if
  end tell
end tell
APPLESCRIPT

sleep 0.35
"$ROOT/script/macos_cua_window.sh"

# Batch clicks after this entry point must not re-spawn overlay/cursor per click.
export MACOS_CUA_SKIP_OVERLAY=1
