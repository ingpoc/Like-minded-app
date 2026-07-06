#!/usr/bin/env bash
# Ensure cua-driver daemon responds before CUA harness runs. Restarts LaunchAgent on wedge.
set -euo pipefail

CUA="${CUA_DRIVER:-$HOME/.local/bin/cua-driver}"

if [[ ! -x "$CUA" ]]; then
  echo "cua-driver missing at $CUA" >&2
  exit 1
fi

restart_daemon() {
  launchctl kickstart -k "gui/$(id -u)/com.trycua.driver" 2>/dev/null || true
  sleep 2
}

probe() {
  "$CUA" call check_permissions '{}' 2>/dev/null \
    | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('accessibility') and d.get('screen_recording') else 1)" 2>/dev/null
}

if ! "$CUA" status 2>/dev/null | grep -qi "daemon is running"; then
  restart_daemon
fi

if ! probe; then
  echo "cua-driver wedged; restarting daemon" >&2
  restart_daemon
  probe || {
    echo "cua-driver still not responding after restart" >&2
    exit 1
  }
fi

export MACOS_CUA_FOLLOW_WINDOW="${MACOS_CUA_FOLLOW_WINDOW:-1}"
# Overlay follows LikemindedMac window display unless MACOS_CUA_FORCE_DISPLAY=1.
export MACOS_CUA_APP_PROCESS="${MACOS_CUA_APP_PROCESS:-LikemindedMac}"
export MACOS_CUA_VIRTUAL_OVERLAY="${MACOS_CUA_VIRTUAL_OVERLAY:-1}"
export MACOS_CUA_LOCAL_COORDS="${MACOS_CUA_LOCAL_COORDS:-1}"
export MACOS_CUA_NO_FRAME="${MACOS_CUA_NO_FRAME:-1}"
export MACOS_CUA_CURSOR_ARROW="${MACOS_CUA_CURSOR_ARROW:-1}"
export MACOS_CUA_FAST="${MACOS_CUA_FAST:-1}"
export MACOS_CUA_GLIDE_MS="${MACOS_CUA_GLIDE_MS:-120}"
export MACOS_CUA_DWELL_MS="${MACOS_CUA_DWELL_MS:-80}"
export MACOS_CUA_MOVE_PAUSE_SEC="${MACOS_CUA_MOVE_PAUSE_SEC:-0.04}"
# Single pointer: glide via move_cursor (overlay-local), then AX element click
# (cursorless). PIXEL_CLICK=1 forces desktop pixel clicks — only for surfaces
# with no AX tree; it minted the sweeping/phantom cursor when tied to a session.
export MACOS_CUA_PIXEL_CLICK="${MACOS_CUA_PIXEL_CLICK:-0}"
export MACOS_CUA_MAX_MODAL="${MACOS_CUA_MAX_MODAL:-80}"
