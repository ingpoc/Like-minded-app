#!/usr/bin/env bash
# Annotate CUA click targets on a window screenshot (red crosshair, no click).
# Usage: ./script/macos_cua_preclick.sh <screen> <label> [label...]
# Output: output/validation/cua-preclick/<screen>-<slug>-crosshair.png
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=macos_canonical_app.sh
source "$ROOT/script/macos_canonical_app.sh"
# shellcheck source=macos_cua_driver.sh
source "$ROOT/script/macos_cua_driver.sh"

SCREEN="${1:?screen name, e.g. settingsSoulmate}"
shift
(( $# > 0 )) || {
  echo "usage: $0 <screen> <label> [label...]" >&2
  exit 1
}
LABELS=("$@")

PRECLICK_OUT="$ROOT/output/validation/cua-preclick"
mkdir -p "$PRECLICK_OUT"
export CUA_DRIVER="$CUA"

curl -fsS "http://127.0.0.1:${PORT:-8787}/health" >/dev/null || {
  echo "Start: npm run dev:api:validation" >&2
  exit 1
}

LIKEMINDED_VALIDATION_USER="${LIKEMINDED_VALIDATION_USER:-validation-priya}" \
LIKEMINDED_VALIDATION_NAME="${LIKEMINDED_VALIDATION_NAME:-Priya Shah}" \
  "$ROOT/script/run_macos_manual_validation.sh" "$SCREEN" >/dev/null
sleep 5
FOCUS_JSON="$("$ROOT/script/macos_cua_focus_window.sh")"
export FOCUS_JSON
cua_init_session

python3 - "$SCREEN" "$PRECLICK_OUT" "${LABELS[@]}" <<'PY'
import json, os, re, subprocess, sys
from pathlib import Path

screen, out_dir, *labels = sys.argv[1:]
out = Path(out_dir)
cua = os.environ["CUA_DRIVER"]
focus = json.loads(os.environ["FOCUS_JSON"])
pid = focus["pid"]
wid = focus["window_id"]
wx = focus["bounds"]["x"]
wy = focus["bounds"]["y"]

base_png = out / f"{screen}-base.png"
raw = subprocess.check_output([
    cua, "call", "get_window_state",
    json.dumps({
        "pid": pid,
        "window_id": wid,
        "max_elements": 200,
        "screenshot_out_file": str(base_png),
    }),
], text=True)
start = raw.find("{")
data = json.loads(raw[start:])
roles = {"AXButton", "AXCheckBox", "AXRadioButton", "AXLink", "AXPopUpButton", "AXMenuButton"}
elements = [e for e in data.get("elements", []) if e.get("role") in roles and (e.get("label") or "").strip()]

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow required: pip install pillow")

img = Image.open(base_png).convert("RGBA")

def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")

def find_label(needle: str):
    n = needle.lower()
    exact = [e for e in elements if (e.get("label") or "").lower() == n]
    if exact:
        return exact[0]
    partial = [e for e in elements if n in (e.get("label") or "").lower()]
    partial.sort(key=lambda e: len(e.get("label") or ""))
    return partial[0] if partial else None

def crosshair(draw_obj, x, y, size=14, color=(255, 0, 0, 255), width=3):
    draw_obj.line([(x - size, y), (x + size, y)], fill=color, width=width)
    draw_obj.line([(x, y - size), (x, y + size)], fill=color, width=width)
    r = 4
    draw_obj.ellipse([(x - r, y - r), (x + r, y + r)], outline=color, width=width)

for label in labels:
    el = find_label(label)
    if not el:
        print(f"MISSING: {label}")
        continue
    f = el.get("frame") or {}
    lx = f["x"] - wx + f["w"] / 2
    ly = f["y"] - wy + f["h"] / 2
    annotated = img.copy()
    ad = ImageDraw.Draw(annotated)
    crosshair(ad, lx, ly)
    path = out / f"{screen}-{slug(label)}-crosshair.png"
    annotated.convert("RGB").save(path)
    print(
        f"OK {label}: idx={el['element_index']} "
        f"local=({lx:.1f},{ly:.1f}) -> {path}"
    )
PY

echo "Pre-click previews: $PRECLICK_OUT"
