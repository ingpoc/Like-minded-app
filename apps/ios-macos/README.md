# iOS + macOS Apps

SwiftUI source for the Likeminded TestFlight MVP placement loop.

## Current Status

- Auth gate supports **Sign in with Apple**, **Google**, **MetaMask**, and **Solflare** (iOS `AuthGateView`; macOS welcome screen).
- MVP tabs are `Meet`, `Circles`, `Communities`, and `Profile` (+ `Soulmate` when enabled).
- Voice interview lives on `Profile` via `RealtimeVoiceClient` and the authenticated Realtime broker.
- `Circles` shows the current placement and supports accept, swap, and defer actions.
- `Profile` supports onboarding, voice interview, profile review/edit, and tester feedback.
- `AuthSessionStore` / `MacAuthSessionStore` persist session tokens in Keychain.
- Group video meets use LiveKit via `Sources/Shared/LiveKitMeetSession.swift` (preview fallback when `LIVEKIT_*` is unset).

## Project Source Of Truth

`project.yml` is the source of truth for the native project. Run XcodeGen through the repo script:

```sh
cd apps/ios-macos && xcodegen generate
./script/build_and_run.sh --verify
```

| Target | Bundle ID | Entitlements | Info plist |
|--------|-----------|--------------|------------|
| `Likeminded` (iOS) | `com.gurusharan.likeminded` | `Entitlements/Likeminded.entitlements` | `Info/Likeminded-Info.plist` |
| `LikemindedMac` | `com.gurusharan.likeminded` | `Entitlements/LikemindedMac.entitlements` | `Info/LikemindedMac-Info.plist` |

Info plists hold Google `GIDClientID`, OAuth URL schemes, and wallet callback schemes. Other keys use `INFOPLIST_KEY_*` in `project.yml`.

## Auth + LiveKit setup

See `docs/workflows/setup.md` for `.env.local` variables (`APPLE_*`, `GOOGLE_*`, `WALLETCONNECT_*`, `LIVEKIT_*`) and the sign-in / join-meetup test flow.

Quick check before native testing:

```sh
curl -s http://127.0.0.1:8787/health
```

## Validation

Use:

```sh
npm run verify:release-config
./script/build_and_run.sh --verify
```

For visual validation, the first unauthenticated screen should be the auth gate (Apple + social/wallet buttons). After sign-in, `Meet`, `Circles`, `Communities`, and `Profile` tabs should be visible.
