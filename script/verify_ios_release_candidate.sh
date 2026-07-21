#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "usage: $0 /absolute/path/to/Likeminded.app" >&2
  exit 2
fi

INFO_PLIST="$APP_PATH/Info.plist"
APP_BINARY="$APP_PATH/Likeminded"
PLIST_BUDDY=/usr/libexec/PlistBuddy
EXPECTED_BUNDLE_ID=com.gurusharan.likeminded
EXPECTED_TEAM_ID=9UPQL479Z5
EXPECTED_API_URL=https://likeminded-api.onrender.com

fail() {
  echo "iOS release candidate rejected: $1" >&2
  exit 1
}

plist_value() {
  "$PLIST_BUDDY" -c "Print :$1" "$INFO_PLIST" 2>/dev/null || true
}

[[ -f "$INFO_PLIST" ]] || fail "Info.plist is missing"
[[ -f "$APP_BINARY" ]] || fail "app binary is missing"
[[ -f "$APP_PATH/PrivacyInfo.xcprivacy" ]] || fail "app-owned PrivacyInfo.xcprivacy is missing"

[[ "$(plist_value CFBundleIdentifier)" == "$EXPECTED_BUNDLE_ID" ]] || fail "unexpected bundle identifier"
[[ "$(plist_value LIKEMINDED_API_BASE_URL)" == "$EXPECTED_API_URL" ]] || fail "production API URL is not selected"
[[ -n "$(plist_value NSCameraUsageDescription)" ]] || fail "camera usage description is missing"
[[ -n "$(plist_value NSMicrophoneUsageDescription)" ]] || fail "microphone usage description is missing"
[[ "$(plist_value ITSAppUsesNonExemptEncryption)" == "false" ]] || fail "export-compliance flag must be false"

BUILD_NUMBER="$(plist_value CFBundleVersion)"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || fail "CFBundleVersion must be a positive uploaded-build number"

GOOGLE_CLIENT_ID="$(plist_value GIDClientID)"
[[ "$GOOGLE_CLIENT_ID" =~ ^[A-Za-z0-9._-]+\.apps\.googleusercontent\.com$ ]] || fail "GIDClientID is empty or invalid"
URL_SCHEMES="$($PLIST_BUDDY -c 'Print :CFBundleURLTypes' "$INFO_PLIST" 2>/dev/null || true)"
[[ "$URL_SCHEMES" == *"com.googleusercontent.apps."* ]] || fail "Google reversed client URL scheme is missing"

ENTITLEMENTS_PATH="$(mktemp -t likeminded-entitlements).plist"
trap 'rm -f "$ENTITLEMENTS_PATH"' EXIT
codesign -d --entitlements :- "$APP_PATH" >"$ENTITLEMENTS_PATH" 2>/dev/null || fail "signed entitlements could not be read"
TEAM_ID="$($PLIST_BUDDY -c 'Print :com.apple.developer.team-identifier' "$ENTITLEMENTS_PATH" 2>/dev/null || true)"
[[ "$TEAM_ID" == "$EXPECTED_TEAM_ID" ]] || fail "unexpected signing team"
APPLE_SIGN_IN="$($PLIST_BUDDY -c 'Print :com.apple.developer.applesignin' "$ENTITLEMENTS_PATH" 2>/dev/null || true)"
[[ "$APPLE_SIGN_IN" == *"Default"* ]] || fail "Sign in with Apple entitlement is missing"
GET_TASK_ALLOW="$($PLIST_BUDDY -c 'Print :get-task-allow' "$ENTITLEMENTS_PATH" 2>/dev/null || true)"
[[ "$GET_TASK_ALLOW" != "true" ]] || fail "get-task-allow must be false for distribution"

if strings "$APP_BINARY" | rg -q 'LIKEMINDED_DEV_AUTH_BYPASS|--likeminded-dev-auth-bypass|APPLE_AUTH_BYPASS'; then
  fail "authentication bypass or debug route is present in the Release binary"
fi

echo "iOS release candidate verified (build $BUILD_NUMBER)"
