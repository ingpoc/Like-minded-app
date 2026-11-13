#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
app_path="${2:-}"
expected_team="9UPQL479Z5"
expected_bundle="com.gurusharan.likeminded"
expected_api="https://likeminded-api.onrender.com"

fail() {
  echo "Release candidate verification failed: $*" >&2
  exit 1
}

[[ "$platform" == "ios" || "$platform" == "macos" ]] || fail "usage: $0 ios|macos /path/to/App.app"
[[ -d "$app_path" ]] || fail "app bundle not found: $app_path"

if [[ "$platform" == "ios" ]]; then
  info_plist="$app_path/Info.plist"
  executable_root="$app_path"
  profile_path="$app_path/embedded.mobileprovision"
  privacy_manifest="$app_path/PrivacyInfo.xcprivacy"
else
  info_plist="$app_path/Contents/Info.plist"
  executable_root="$app_path/Contents/MacOS"
  profile_path="$app_path/Contents/embedded.provisionprofile"
  privacy_manifest="$app_path/Contents/Resources/PrivacyInfo.xcprivacy"
fi

[[ -f "$info_plist" ]] || fail "Info.plist missing"
[[ -f "$profile_path" ]] || fail "embedded App Store provisioning profile missing"
[[ -f "$privacy_manifest" ]] || fail "app privacy manifest missing"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
entitlements="$tmp_dir/entitlements.plist"
profile="$tmp_dir/profile.plist"
signature="$tmp_dir/signature.txt"

/usr/bin/codesign --verify --deep --strict "$app_path" 2>/dev/null || fail "code signature is invalid"
/usr/bin/codesign -d --entitlements :- "$app_path" >"$entitlements" 2>/dev/null || fail "signed entitlements unavailable"
/usr/bin/security cms -D -i "$profile_path" >"$profile" 2>/dev/null || fail "embedded provisioning profile is unreadable"
/usr/bin/plutil -lint "$entitlements" "$profile" "$privacy_manifest" >/dev/null || fail "release plist is invalid"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true
}

require_value() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  [[ "$actual" == "$expected" ]] || fail "$label expected '$expected', got '${actual:-missing}'"
}

bundle_id="$(plist_value "$info_plist" CFBundleIdentifier)"
build_number="$(plist_value "$info_plist" CFBundleVersion)"
marketing_version="$(plist_value "$info_plist" CFBundleShortVersionString)"
executable="$(plist_value "$info_plist" CFBundleExecutable)"
api_url="$(plist_value "$info_plist" LIKEMINDED_API_BASE_URL)"
google_client_id="$(plist_value "$info_plist" GIDClientID)"
google_scheme="$(plist_value "$info_plist" CFBundleURLTypes:0:CFBundleURLSchemes:0)"

require_value "$bundle_id" "$expected_bundle" "bundle id"
[[ -n "$build_number" ]] || fail "build number missing"
[[ -n "$marketing_version" ]] || fail "marketing version missing"
require_value "$api_url" "$expected_api" "production API URL"
[[ "$google_client_id" == *.apps.googleusercontent.com ]] || fail "Google client ID missing from built Info.plist"
require_value "$google_scheme" "com.googleusercontent.apps.${google_client_id%.apps.googleusercontent.com}" "Google callback URL scheme"
[[ -n "$(plist_value "$info_plist" NSMicrophoneUsageDescription)" ]] || fail "microphone usage description missing"
[[ -n "$(plist_value "$info_plist" NSCameraUsageDescription)" ]] || fail "camera usage description missing"

if [[ "$platform" == "ios" ]]; then
  require_value "$(plist_value "$info_plist" CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName)" "AppIcon" "iOS app icon name"
  [[ -f "$app_path/Assets.car" ]] || fail "iOS asset catalog missing"
  [[ -f "$app_path/AppIcon60x60@2x.png" ]] || fail "120x120 iPhone app icon missing"
  [[ -f "$app_path/AppIcon76x76@2x~ipad.png" ]] || fail "152x152 iPad app icon missing"
else
  require_value "$(plist_value "$info_plist" CFBundleIconName)" "AppIcon" "macOS app icon name"
  [[ -f "$app_path/Contents/Resources/Assets.car" ]] || fail "macOS asset catalog missing"
  [[ -f "$app_path/Contents/Resources/AppIcon.icns" ]] || fail "macOS app icon missing"
fi

if [[ "$platform" == "macos" ]]; then
  app_identifier_key="com.apple.application-identifier"
  get_task_allow_key="com.apple.security.get-task-allow"
else
  app_identifier_key="application-identifier"
  get_task_allow_key="get-task-allow"
fi

require_value "$(plist_value "$entitlements" "$app_identifier_key")" "$expected_team.$expected_bundle" "signed application identifier"
require_value "$(plist_value "$entitlements" com.apple.developer.team-identifier)" "$expected_team" "signed team identifier"
/usr/bin/plutil -p "$entitlements" | /usr/bin/grep -F '"Default"' >/dev/null || fail "Sign in with Apple entitlement missing"
[[ "$(plist_value "$entitlements" "$get_task_allow_key")" != "true" ]] || fail "signed app has $get_task_allow_key=true"

require_value "$(plist_value "$profile" TeamIdentifier:0)" "$expected_team" "profile team identifier"
require_value "$(plist_value "$profile" "Entitlements:$app_identifier_key")" "$expected_team.$expected_bundle" "profile application identifier"
profile_get_task_allow="$(plist_value "$profile" "Entitlements:$get_task_allow_key")"
if [[ "$platform" == "ios" ]]; then
  require_value "$profile_get_task_allow" "false" "profile $get_task_allow_key"
  require_value "$(plist_value "$profile" Entitlements:beta-reports-active)" "true" "profile beta entitlement"
else
  [[ -z "$profile_get_task_allow" || "$profile_get_task_allow" == "false" ]] || fail "profile $get_task_allow_key must be false or absent"
fi

if [[ "$platform" == "macos" ]]; then
  require_value "$(plist_value "$entitlements" com.apple.security.app-sandbox)" "true" "macOS App Sandbox entitlement"
  require_value "$(plist_value "$entitlements" com.apple.security.network.client)" "true" "macOS outbound network entitlement"
  require_value "$(plist_value "$entitlements" com.apple.security.device.audio-input)" "true" "macOS microphone entitlement"
  /usr/bin/codesign -dv --verbose=4 "$app_path" 2>"$signature" || fail "macOS signature metadata unavailable"
  ! /usr/bin/grep -F 'Authority=Developer ID Application:' "$signature" >/dev/null || fail "macOS app uses Developer ID instead of App Store distribution signing"
  /usr/bin/grep -E '^Authority=(Apple Distribution:|3rd Party Mac Developer Application:|Mac App Distribution:)' "$signature" >/dev/null || fail "macOS App Store distribution authority missing"
  /usr/bin/grep -E 'flags=.*runtime' "$signature" >/dev/null || fail "macOS hardened runtime missing"
fi

executable_path="$executable_root/$executable"
[[ -x "$executable_path" ]] || fail "app executable missing"
if /usr/bin/strings "$executable_path" | /usr/bin/grep -F -- "--likeminded-dev-auth-bypass" >/dev/null; then
  fail "release executable contains debug auth bypass"
fi

require_value "$(plist_value "$privacy_manifest" NSPrivacyTracking)" "false" "privacy tracking declaration"
[[ -n "$(plist_value "$privacy_manifest" NSPrivacyCollectedDataTypes:0:NSPrivacyCollectedDataType)" ]] || fail "privacy data declarations missing"

echo "Release candidate verified: platform=$platform bundle=$bundle_id version=$marketing_version build=$build_number team=$expected_team get-task-allow=false"
