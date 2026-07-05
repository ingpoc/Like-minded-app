#!/usr/bin/env bash
# Stable macOS CUA driver — wraps trycua/cua-driver via macos-cua skill (Cursor/Codex path).
set -euo pipefail

MACOS_CUA_PY="${MACOS_CUA_PY:-$HOME/.agents/skills/macos-cua/scripts/macos-cua.py}"
MACOS_CUA_APP="${MACOS_CUA_APP:-Likeminded}"
MACOS_CUA_SESSION="${MACOS_CUA_SESSION:-likeminded-validation}"
CUA="${CUA_DRIVER:-$HOME/.local/bin/cua-driver}"

cua_require_driver() {
  if [[ ! -x "$CUA" ]]; then
    echo "Install cua-driver: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/trycua/cua/main/libs/cua-driver/scripts/install.sh)\"" >&2
    exit 1
  fi
  if [[ ! -f "$MACOS_CUA_PY" ]]; then
    echo "Missing macos-cua skill: $MACOS_CUA_PY" >&2
    exit 1
  fi
}

cua_init_session() {
  cua_require_driver
  "$CUA" call start_session "{\"session\":\"$MACOS_CUA_SESSION\"}" >/dev/null 2>&1 || true
  python3 "$MACOS_CUA_PY" cursor show --session "$MACOS_CUA_SESSION" >/dev/null 2>&1 || true
}

# Prefer canonical focus (pid/window_id) — avoids list_windows timeouts in macos-cua.py.
cua_export_focus() {
  cua_bind
  export MACOS_CUA_PID="$PID"
  export MACOS_CUA_WID="$WID"
}

cua_snap_list() {
  python3 "$MACOS_CUA_PY" snap "$MACOS_CUA_APP" --max "${1:-50}"
}
