#!/usr/bin/env bash
set -euo pipefail

STATE="${1:-default}"

usage() {
  echo "Usage: $0 [default|small|large|maximized|all]" >&2
}

apply_state() {
  local state="$1"
  local x=80 y=80 width=1200 height=760

  case "$state" in
    default) width=1200; height=760 ;;
    small) width=1120; height=752 ;;
    large) width=1440; height=900 ;;
    maximized)
      local bounds
      bounds="$(osascript -e 'tell application "Finder" to get bounds of window of desktop')"
      IFS=',' read -r x y width height <<<"$bounds"
      x="${x// /}"
      y="${y// /}"
      width="${width// /}"
      height="${height// /}"
      y=$((y + 36))
      height=$((height - 72))
      ;;
    *) usage; exit 2 ;;
  esac

  osascript <<APPLESCRIPT >/dev/null
tell application "LikemindedMac" to activate
tell application "System Events"
  tell process "LikemindedMac"
    set frontmost to true
    if (count of windows) > 0 then
      set position of window 1 to {$x, $y}
      set size of window 1 to {$width, $height}
    end if
  end tell
end tell
APPLESCRIPT
  echo "LikemindedMac window=$state ${width}x${height}+${x}+${y}"
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

