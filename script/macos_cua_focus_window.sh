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

# Wait for a main content window (same threshold as screencapture in verify_macos_screens.sh).
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

sleep 0.25

osascript <<APPLESCRIPT >/dev/null 2>&1 || true
tell application "System Events"
  tell process "$MACOS_CANONICAL_EXEC"
    set frontmost to true
    if (count of windows) > 0 then
      set position of window 1 to {$X, $Y}
      set size of window 1 to {$W, $H}
      perform action "AXRaise" of window 1
    end if
  end tell
end tell
APPLESCRIPT

sleep 0.35
"$ROOT/script/macos_cua_window.sh"
