#!/usr/bin/env bash
# Resolve pid/window_id for the canonical LikemindedMac main window.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=macos_canonical_app.sh
source "$ROOT/script/macos_canonical_app.sh"

PID="$(macos_assert_single_instance)" || exit 1

python3 - "$PID" <<'PY'
import json, os, sys
import Quartz

pid = int(sys.argv[1])
target_x = float(os.environ.get("LIKEMINDED_MAC_WINDOW_X", "0"))
target_y = float(os.environ.get("LIKEMINDED_MAC_WINDOW_Y", "0"))

ws = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
    Quartz.kCGNullWindowID,
)
best = None
for w in ws:
    if w.get("kCGWindowOwnerPID") != pid:
        continue
    b = w.get("kCGWindowBounds") or {}
    width = float(b.get("Width", 0))
    height = float(b.get("Height", 0))
    area = width * height
    if area < 200_000:
        continue
    x = float(b.get("X", 0))
    y = float(b.get("Y", 0))
    dist = abs(x - target_x) + abs(y - target_y)
    score = (area, -dist)
    if best is None or score > best[0]:
        best = (score, int(w["kCGWindowNumber"]), {"x": x, "y": y, "width": width, "height": height})

if not best:
    sys.exit("no main window for canonical LikemindedMac")
_, wid, bounds = best
print(json.dumps({"pid": pid, "window_id": wid, "bounds": bounds}))
PY
