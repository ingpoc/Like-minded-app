# Google Sign-In setup (Phase 2)

## Control Owner

This workflow owns the repository setup steps for Google OAuth; provider credentials and console state remain externally owned.

Complete before disabling `APPLE_AUTH_BYPASS` for real auth testing.

## 1. Google Cloud Console

1. Create a project at [Google Cloud Console](https://console.cloud.google.com/).
2. Enable **Google Sign-In API** / configure OAuth consent screen (External, test users).
3. Create OAuth client IDs:
   - **iOS** — bundle id `com.gurusharan.likeminded`
   - **macOS** — bundle id `com.gurusharan.likeminded` (shared universal app record)

## 2. Repo configuration

Add to `.env.local`:

```sh
GOOGLE_CLIENT_ID_IOS=your-id.apps.googleusercontent.com
GOOGLE_CLIENT_ID_MAC=your-mac-id.apps.googleusercontent.com
GOOGLE_REVERSED_CLIENT_ID_IOS=com.googleusercontent.apps.your-id
GOOGLE_REVERSED_CLIENT_ID_MAC=com.googleusercontent.apps.your-mac-id
GOOGLE_CLIENT_IDS=your-id.apps.googleusercontent.com,your-mac-id.apps.googleusercontent.com
GOOGLE_AUTH_BYPASS=0
APPLE_AUTH_BYPASS=0
```

Set the matching iOS/macOS client IDs and reversed client IDs in `apps/ios-macos/project.yml`, then:

```sh
cd apps/ios-macos && xcodegen generate
```

## 3. Verify

```sh
set -a && source .env.local && set +a
./script/run_api.sh
curl -s http://127.0.0.1:8787/health   # googleAuth: true
```

Sign in with Google on iOS simulator and macOS app. Session should persist across tabs.
