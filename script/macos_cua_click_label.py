#!/usr/bin/env python3
"""Stable label → click via cua-driver (session + fresh snap + element_token)."""
from __future__ import annotations

import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SESSION = os.environ.get("MACOS_CUA_SESSION", "likeminded-validation")
CUA = os.environ.get("CUA_DRIVER", os.path.expanduser("~/.local/bin/cua-driver"))
FOCUS_SCRIPT = os.path.join(ROOT, "script", "macos_cua_focus_window.sh")


def call_driver(tool: str, params: dict) -> dict:
    cmd = [CUA, "call", tool, json.dumps(params)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=45)
    if result.returncode != 0:
        return {"error": (result.stderr or result.stdout).strip()}
    raw = result.stdout.strip()
    start = raw.find("{")
    return json.loads(raw[start:]) if start >= 0 else {"raw": raw}


def resolve_window() -> tuple[int, int]:
    if os.environ.get("MACOS_CUA_PID") and os.environ.get("MACOS_CUA_WID"):
        return int(os.environ["MACOS_CUA_PID"]), int(os.environ["MACOS_CUA_WID"])
    raw = subprocess.check_output([FOCUS_SCRIPT], text=True, timeout=30)
    data = json.loads(raw)
    return int(data["pid"]), int(data["window_id"])


def find_element(elements: list[dict], needle: str) -> dict | None:
    n = needle.lower()
    roles = {
        "AXButton",
        "AXCheckBox",
        "AXRadioButton",
        "AXLink",
        "AXPopUpButton",
        "AXMenuButton",
        "AXTextField",
        "AXTextArea",
    }
    rows = [e for e in elements if e.get("role") in roles]
    exact = [e for e in rows if (e.get("label") or "").lower() == n]
    if exact:
        if len(exact) > 1:
            exact.sort(key=lambda e: (e.get("frame") or {}).get("y", 0))
        return exact[0]
    partial = [e for e in rows if n in (e.get("label") or "").lower()]
    if not partial:
        return None
    partial.sort(
        key=lambda e: ((e.get("frame") or {}).get("y", 0), len(e.get("label") or ""))
    )
    return partial[0]


def snap(pid: int, wid: int) -> dict:
    return call_driver(
        "get_window_state",
        {
            "pid": pid,
            "window_id": wid,
            "max_elements": 200,
            "session": SESSION,
            "include_screenshot": False,
        },
    )


def click_element(pid: int, wid: int, el: dict) -> dict:
    params: dict = {"pid": pid, "window_id": wid, "session": SESSION}
    token = el.get("element_token")
    if token:
        params["element_token"] = token
    else:
        params["element_index"] = el["element_index"]
    return call_driver("click", params)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: macos_cua_click_label.py <label> [--optional]", file=sys.stderr)
        return 2
    label = sys.argv[1]
    optional = len(sys.argv) > 2 and sys.argv[2] == "--optional"

    try:
        pid, wid = resolve_window()
    except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as exc:
        print(f"MISSING: {label} (focus: {exc})")
        return 0 if optional else 1

    snap_data = snap(pid, wid)
    if snap_data.get("error"):
        print(f"MISSING: {label} (snap: {snap_data['error']})")
        return 0 if optional else 1

    el = find_element(snap_data.get("elements") or [], label)
    if not el:
        print(f"MISSING: {label}")
        return 0 if optional else 1

    idx = el["element_index"]
    res = click_element(pid, wid, el)
    if res.get("error"):
        snap_data = snap(pid, wid)
        el = find_element(snap_data.get("elements") or [], label)
        if not el:
            print(f"MISSING: {label} (after retry)")
            return 0 if optional else 1
        idx = el["element_index"]
        res = click_element(pid, wid, el)
        if res.get("error"):
            print(f"MISSING: {label} ({res['error']})")
            return 0 if optional else 1

    print(f"OK click '{label}' idx={idx}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
