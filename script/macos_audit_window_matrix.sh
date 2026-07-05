#!/usr/bin/env bash
set -euo pipefail

STATE="${1:-default}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=macos_canonical_app.sh
source "$ROOT/script/macos_canonical_app.sh"

usage() {
  echo "Usage: $0 [default|small|large|maximized|all]" >&2
}

apply_state() {
  local state="$1"
  case "$state" in
    default) export LIKEMINDED_MAC_WINDOW_WIDTH=1200 LIKEMINDED_MAC_WINDOW_HEIGHT=760 ;;
    small) export LIKEMINDED_MAC_WINDOW_WIDTH=1120 LIKEMINDED_MAC_WINDOW_HEIGHT=901 ;;
    large) export LIKEMINDED_MAC_WINDOW_WIDTH=1440 LIKEMINDED_MAC_WINDOW_HEIGHT=900 ;;
    maximized)
      local bounds x y width height
      bounds="$(osascript -e 'tell application "Finder" to get bounds of window of desktop')"
      IFS=',' read -r x y width height <<<"$bounds"
      x="${x// /}"; y="${y// /}"; width="${width// /}"; height="${height// /}"
      y=$((y + 36))
      height=$((height - 72))
      export LIKEMINDED_MAC_WINDOW_X="$x"
      export LIKEMINDED_MAC_WINDOW_Y="$y"
      export LIKEMINDED_MAC_WINDOW_WIDTH="$width"
      export LIKEMINDED_MAC_WINDOW_HEIGHT="$height"
      ;;
    *) usage; exit 2 ;;
  esac

  "$ROOT/script/macos_cua_focus_window.sh" >/dev/null
  echo "LikemindedMac window=$state ${LIKEMINDED_MAC_WINDOW_WIDTH}x${LIKEMINDED_MAC_WINDOW_HEIGHT}"
}

case "$STATE" in
  all)
    for state in default small large maximized; do
      apply_state "$state"
      if [[ -t 0 ]]; then
        read -r -p "Inspect with Computer Use, then press Return for next size..."
      else
        sleep 5
      fi
    done
    ;;
  default|small|large|maximized)
    apply_state "$STATE"
    ;;
  *)
    usage
    exit 2
    ;;
esac
