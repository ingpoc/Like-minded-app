#!/usr/bin/env python3
"""Align LikemindedMac on MACOS_CUA_DISPLAY (default DELL) + cua-driver overlay.

Places the app and overlay on the same monitor. With MACOS_CUA_LOCAL_COORDS=1,
move_cursor uses overlay-local coordinates (required because get_screen_size is
primary-display only). Call once per session; set MACOS_CUA_SKIP_OVERLAY=1 before
batched clicks. See ~/.agents/skills/macos-cua/references/displays.md.
"""
from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys

SKILL_DISPLAYS = os.path.expanduser(
    "~/.agents/skills/macos-cua/scripts/displays.py"
)
DEFAULT_TOKEN = "DELL"
MACOS_CUA_PY = os.path.expanduser("~/.agents/skills/macos-cua/scripts/macos-cua.py")


def load_displays_module():
    path = os.environ.get("MACOS_CUA_DISPLAYS_PY", SKILL_DISPLAYS)
    if not os.path.isfile(path):
        raise SystemExit(f"displays.py not found at {path}")
    spec = importlib.util.spec_from_file_location("displays", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def resolve_target_token() -> str:
    return (os.environ.get("MACOS_CUA_DISPLAY") or DEFAULT_TOKEN).strip()


def show_agent_cursor() -> dict:
    if not os.path.isfile(MACOS_CUA_PY):
        return {"ok": False, "error": f"missing {MACOS_CUA_PY}"}
    proc = subprocess.run(
        [sys.executable, MACOS_CUA_PY, "cursor", "show"],
        capture_output=True,
        text=True,
        timeout=20,
    )
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        data = {"raw": (proc.stdout or proc.stderr or "").strip()}
    return {"ok": proc.returncode == 0, "result": data}


def main() -> int:
    disp = load_displays_module()
    target = resolve_target_token()
    app_process = os.environ.get("MACOS_CUA_APP_PROCESS", "LikemindedMac")
    app_quartz = os.environ.get("MACOS_CUA_APP_QUARTZ", "Likeminded")
    width = int(os.environ.get("LIKEMINDED_MAC_WINDOW_WIDTH", "1200"))
    height = int(os.environ.get("LIKEMINDED_MAC_WINDOW_HEIGHT", "760"))
    margin = int(os.environ.get("MACOS_CUA_DISPLAY_MARGIN", "80"))

    matched = disp.find_display(target)
    if not matched:
        print(
            json.dumps(
                {
                    "ok": False,
                    "error": f"display not found for token {target!r}",
                    "displays": disp.list_displays(),
                }
            ),
            file=sys.stderr,
        )
        return 1

    before = disp.window_on_display(app_quartz)
    on_target = (
        before
        and before.get("display")
        and target.lower() in before["display"]["name"].lower()
    )

    app_result = disp.ensure_on_test_display(
        app_process,
        target,
        width=width,
        height=height,
        margin=margin,
    )

    bounds = disp.window_bounds_for_process(app_quartz) or {}
    cursor_result = show_agent_cursor()

    # Place overlay on test display (cua-driver get_screen_size is primary-only).
    overlay_result = disp.ensure_overlay_on_display(target)

    out = {
        "ok": bool(app_result.get("ok")),
        "target_token": target,
        "display": matched["name"],
        "was_on_target": on_target,
        "moved": bool(app_result.get("moved")),
        "app": app_result,
        "cua_overlay": overlay_result,
        "cursor": cursor_result,
        "bounds": bounds,
        "virtual_screen": disp.virtual_screen_quartz(),
    }
    print(json.dumps(out, indent=2))
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
