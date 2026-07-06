#!/usr/bin/env python3
"""Align LikemindedMac + cua-driver overlay on the same monitor.

With MACOS_CUA_NO_FRAME=1 (default), follows the app window's display instead of
forcing MACOS_CUA_DISPLAY=DELL. Overlay must match the window monitor or
click-label-pointer coords miss (multi-monitor).

Set MACOS_CUA_FORCE_DISPLAY=1 + MACOS_CUA_DISPLAY=<token> to pin a monitor.
Call once per session; set MACOS_CUA_SKIP_OVERLAY=1 before batched clicks.
See ~/.agents/skills/macos-cua/references/displays.md.
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
KNOWN_DISPLAY_PREFIXES = (
    "DELL",
    "LG",
    "SAMSUNG",
    "HP",
    "ASUS",
    "BENQ",
    "VIEWSONIC",
    "ACER",
)


def load_displays_module():
    path = os.environ.get("MACOS_CUA_DISPLAYS_PY", SKILL_DISPLAYS)
    if not os.path.isfile(path):
        raise SystemExit(f"displays.py not found at {path}")
    spec = importlib.util.spec_from_file_location("displays", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def token_from_display_name(name: str) -> str:
    """Derive MACOS_CUA_DISPLAY substring token from NSScreen localizedName."""
    upper = (name or "").upper()
    for prefix in KNOWN_DISPLAY_PREFIXES:
        if prefix in upper:
            return prefix
    part = (name or "").split()[0]
    return part or DEFAULT_TOKEN


def should_follow_window() -> bool:
    follow = (os.environ.get("MACOS_CUA_FOLLOW_WINDOW") or "").strip()
    if follow == "1":
        return True
    if follow == "0":
        return False
    return os.environ.get("MACOS_CUA_NO_FRAME", "1").strip() == "1"


def usable_window(info: dict | None) -> bool:
    bounds = (info or {}).get("bounds") or {}
    return float(bounds.get("width", 0) or 0) >= 400 and float(bounds.get("height", 0) or 0) >= 300


def resolve_target_token(disp, app_quartz: str) -> tuple[str, dict | None]:
    """Return (display token, window_on_display info)."""
    explicit = (os.environ.get("MACOS_CUA_DISPLAY") or "").strip()
    force = os.environ.get("MACOS_CUA_FORCE_DISPLAY", "").strip() == "1"
    on_disp = disp.window_on_display(app_quartz)

    if force and explicit:
        return explicit, on_disp

    if should_follow_window() and usable_window(on_disp) and on_disp and on_disp.get("display"):
        name = on_disp["display"]["name"]
        return token_from_display_name(name), on_disp

    if explicit:
        return explicit, on_disp

    if usable_window(on_disp) and on_disp and on_disp.get("display"):
        return token_from_display_name(on_disp["display"]["name"]), on_disp

    return DEFAULT_TOKEN, on_disp


def _cursor_action(action: str) -> dict:
    if not os.path.isfile(MACOS_CUA_PY):
        return {"ok": False, "error": f"missing {MACOS_CUA_PY}"}
    proc = subprocess.run(
        [sys.executable, MACOS_CUA_PY, "cursor", action],
        capture_output=True,
        text=True,
        timeout=20,
    )
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        data = {"raw": (proc.stdout or proc.stderr or "").strip()}
    return {"ok": proc.returncode == 0, "result": data}


def hide_agent_cursor() -> dict:
    return _cursor_action("hide")


def show_agent_cursor() -> dict:
    return _cursor_action("show")


def needs_overlay_align(prev_token: str, target: str) -> bool:
    """Idempotent align: skip overlay/cursor when batched clicks and monitor unchanged."""
    if os.environ.get("MACOS_CUA_FORCE_ALIGN", "").strip() == "1":
        return True
    # focus_window.sh + session_start align once; batched clicks must not respawn pointer.
    if os.environ.get("MACOS_CUA_SKIP_OVERLAY", "").strip() == "1":
        return False
    if prev_token and prev_token.upper() == target.upper():
        return False
    return True


def main() -> int:
    disp = load_displays_module()
    app_process = os.environ.get("MACOS_CUA_APP_PROCESS", "LikemindedMac")
    app_quartz = os.environ.get("MACOS_CUA_APP_QUARTZ", "Likeminded")
    width = int(os.environ.get("LIKEMINDED_MAC_WINDOW_WIDTH", "1200"))
    height = int(os.environ.get("LIKEMINDED_MAC_WINDOW_HEIGHT", "760"))
    margin = int(os.environ.get("MACOS_CUA_DISPLAY_MARGIN", "80"))

    prev_token = (os.environ.get("MACOS_CUA_DISPLAY") or "").strip()
    target, window_info = resolve_target_token(disp, app_quartz)
    os.environ["MACOS_CUA_DISPLAY"] = target
    align_overlay = needs_overlay_align(prev_token, target)

    matched = disp.find_display(target)
    if not matched:
        print(
            json.dumps(
                {
                    "ok": False,
                    "error": f"display not found for token {target!r}",
                    "displays": disp.list_displays(),
                    "window": window_info,
                }
            ),
            file=sys.stderr,
        )
        return 1

    before = window_info or disp.window_on_display(app_quartz)
    on_target = (
        before
        and before.get("display")
        and target.lower() in before["display"]["name"].lower()
    )

    force = os.environ.get("MACOS_CUA_FORCE_DISPLAY", "").strip() == "1"
    follow = should_follow_window() and not force

    if follow and usable_window(before):
        bounds = disp.window_bounds_for_process(app_quartz) or (before or {}).get("bounds") or {}
        app_result = {
            "ok": bool(bounds),
            "moved": False,
            "display": (before or {}).get("display", {}).get("name"),
            "bounds": bounds,
            "mode": "follow-window",
        }
    else:
        app_result = disp.ensure_on_test_display(
            app_process,
            target,
            width=width,
            height=height,
            margin=margin,
        )

    bounds = disp.window_bounds_for_process(app_quartz) or app_result.get("bounds") or {}

    # Overlay before cursor show — showing on the wrong monitor leaves a ghost pointer.
    if align_overlay:
        hide_agent_cursor()
        overlay_result = disp.ensure_overlay_on_display(target)
        cursor_result = show_agent_cursor()
    else:
        overlay_result = {"skipped": True, "reason": "MACOS_CUA_SKIP_OVERLAY"}
        cursor_result = {"skipped": True, "reason": "MACOS_CUA_SKIP_OVERLAY"}

    out = {
        "ok": bool(app_result.get("ok")),
        "target_token": target,
        "follow_window": follow,
        "align_overlay": align_overlay,
        "display": matched["name"],
        "was_on_target": on_target,
        "moved": bool(app_result.get("moved")),
        "window_display": (before or {}).get("display"),
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
