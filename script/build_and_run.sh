#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/apps/ios-macos"
PROJECT_FILE="$IOS_DIR/Likeminded.xcodeproj"
SCHEME="Likeminded"
APP_NAME="Likeminded"
BUNDLE_ID="com.likeminded.prototype"
DERIVED_DATA="$ROOT_DIR/.build/ios-simulator"

resolve_simulator() {
  local preferred="${SIMULATOR_NAME:-iPhone 16 Pro}"
  local id
  id=$(xcrun simctl list devices available 2>/dev/null | grep -F "$preferred " | head -1 | grep -oE '\([A-F0-9-]+\)' | tr -d '()')
  if [[ -z "$id" ]]; then
    echo "Simulator '$preferred' not found. Available:" >&2
    xcrun simctl list devices available 2>/dev/null | grep "iPhone" | sed 's/^/  /' >&2
    exit 1
  fi
  echo "$id"
}

SIMULATOR_ID="$(resolve_simulator)"
DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/$APP_NAME.app"

generate_project() {
  (cd "$IOS_DIR" && xcodegen generate)
}

boot_simulator() {
  if ! xcrun simctl list devices available | grep -F "$SIMULATOR_ID" >/dev/null 2>&1; then
    echo "Simulator '$SIMULATOR_NAME' is not available." >&2
    exit 1
  fi

  xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
  open -a Simulator >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SIMULATOR_ID" -b
}

build_app() {
  xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    build
}

install_and_launch() {
  xcrun simctl uninstall booted "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install booted "$APP_PATH"
  xcrun simctl launch booted "$BUNDLE_ID"
}

stream_logs() {
  xcrun simctl spawn booted log stream --level debug --style compact --predicate "process == \"$APP_NAME\""
}

verify_launch() {
  local launch_output
  xcrun simctl uninstall booted "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install booted "$APP_PATH"
  launch_output="$(xcrun simctl launch booted "$BUNDLE_ID")"
  echo "$launch_output"
}

generate_project
boot_simulator

case "$MODE" in
  run)
    build_app
    install_and_launch
    ;;
  --debug|debug)
    build_app
    lldb -- "$APP_PATH/$APP_NAME"
    ;;
  --logs|logs)
    build_app
    install_and_launch
    stream_logs
    ;;
  --telemetry|telemetry)
    build_app
    install_and_launch
    stream_logs
    ;;
  --verify|verify)
    build_app
    verify_launch
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
