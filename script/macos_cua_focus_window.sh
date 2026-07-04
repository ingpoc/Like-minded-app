#!/usr/bin/env bash
# Center the canonical LikemindedMac window on the primary display; print pid/window_id JSON.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=macos_canonical_app.sh
source "$ROOT/script/macos_canonical_app.sh"

W="${LIKEMINDED_MAC_WINDOW_WIDTH:-1200}"
H="${LIKEMINDED_MAC_WINDOW_HEIGHT:-760}"

PID="$(macos_assert_single_instance)" || exit 1

read -r X Y <<<"$(python3 -c "
import Quartz
main = Quartz.CGDisplayBounds(Quartz.CGMainDisplayID())
w, h = int('$W'), int('$H')
x = int(main.origin.x + (main.size.width - w) / 2)
y = int(main.origin.y + (main.size.height - h) / 2)
print(x, y)
")"

export LIKEMINDED_MAC_WINDOW_X="$X"
export LIKEMINDED_MAC_WINDOW_Y="$Y"
export LIKEMINDED_MAC_WINDOW_WIDTH="$W"
export LIKEMINDED_MAC_WINDOW_HEIGHT="$H"

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

sleep 0.25

osascript <<APPLESCRIPT >/dev/null
tell application "System Events"
  tell process "$MACOS_CANONICAL_EXEC"
    set frontmost to true
    if (count of windows) is 0 then error "no window"
    set position of window 1 to {$X, $Y}
    set size of window 1 to {$W, $H}
    perform action "AXRaise" of window 1
  end tell
end tell
APPLESCRIPT

sleep 0.35
"$ROOT/script/macos_cua_window.sh"
