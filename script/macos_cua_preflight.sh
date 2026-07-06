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
