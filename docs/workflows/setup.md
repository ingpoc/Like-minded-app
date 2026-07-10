# Setup

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This workflow describes local setup only.

One-time setup for new agents working on this repo.

## Prerequisites

- macOS 15+
- Xcode 17+ (for iOS 18 SDK)
- XcodeGen (`brew install xcodegen`)
- Node.js 20+

## Environment

1. Create `.env.local` in repo root:

```
OPENAI_API_KEY=***
OPENAI_REALTIME_MODEL=gpt-realtime-1.5
OPENAI_REALTIME_VOICE=marin
SESSION_SECRET=replace-with-at-least-24-characters
APPLE_BUNDLE_ID=com.likeminded.app
APPLE_CLIENT_ID=com.likeminded.app
APPLE_MAC_BUNDLE_ID=com.likeminded.mac
APPLE_CLIENT_IDS=com.likeminded.app,com.likeminded.mac
APPLE_REQUIRE_NONCE=1
APPLE_AUTH_BYPASS=0
GOOGLE_CLIENT_ID_IOS=your-ios-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_ID_MAC=your-mac-client-id.apps.googleusercontent.com
GOOGLE_REVERSED_CLIENT_ID=com.googleusercontent.apps.your-ios-client-id
GOOGLE_CLIENT_IDS=your-ios-client-id.apps.googleusercontent.com
GOOGLE_AUTH_BYPASS=0
WALLETCONNECT_PROJECT_ID=your-walletconnect-cloud-project-id
WALLET_AUTH_BYPASS=0
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your-livekit-api-key
LIVEKIT_API_SECRET=your-livekit-api-secret
```

2. Source it before running the API server:
```sh
set -a && source .env.local && set +a
```

Copy from `.env.example` if starting fresh. `GET /health` reports `livekit`, `googleAuth`, and `walletAuth` booleans so you can confirm server-side config before testing native sign-in.

## Sign-in (iOS + macOS)

Both natives share auth providers (**Apple**, **Google**, **MetaMask**, **Solflare**) and `Sources/Shared/` (`ConvergenceFieldView`, `SocialAuthButtonsView`, wallet/Google helpers). UI: `AuthGateView` (iOS) and `MacScreens` welcome (macOS) — convergence field + aligned copy; reference `mockups/*/auth-login-convergence.png`.

| Provider | Native flow | API route |
|----------|-------------|-----------|
| Apple | `ASAuthorizationAppleID` / `SignInWithAppleButton` | `POST /v1/auth/apple` |
| Google | Google Sign-In SDK → ID token | `POST /v1/auth/google` |
| Wallet | `ASWebAuthenticationSession` → `/v1/auth/wallet/sign` page | `POST /v1/auth/wallet/challenge` + verify |

**API must be running** before sign-in (`./script/run_api.sh` or `npm run dev:api:validation`). Default DEBUG base URL is `http://127.0.0.1:8787`.

### Apple

- iOS entitlement: `Entitlements/Likeminded.entitlements`
- macOS entitlement: `Entitlements/LikemindedMac.entitlements`
- Server: set `APPLE_CLIENT_IDS=com.likeminded.app,com.likeminded.mac`, `APPLE_REQUIRE_NONCE=1`, `APPLE_AUTH_BYPASS=0` for real device/TestFlight.
- Local bypass (API only): `APPLE_AUTH_BYPASS=1` or app launch arg `--likeminded-dev-auth-bypass` with `npm run dev:api:local-auth`.

### Google

Set in `.env.local` (API) **and** pass into Xcode builds:

```
GOOGLE_CLIENT_ID_IOS=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_ID_MAC=your-mac-client-id.apps.googleusercontent.com   # optional; falls back to iOS client
GOOGLE_REVERSED_CLIENT_ID=com.googleusercontent.apps.your-client-id
GOOGLE_CLIENT_IDS=your-client-id.apps.googleusercontent.com
```

Native URL schemes and `GIDClientID` are in `Info/Likeminded-Info.plist` and `Info/LikemindedMac-Info.plist` (Google reversed client ID + bundle-id wallet callback). After editing `project.yml` or Info plists, run `cd apps/ios-macos && xcodegen generate`.

Google OAuth redirect must include both bundle IDs in the Google Cloud console.

### Wallet (MetaMask / Solflare)

- Server: `WALLETCONNECT_PROJECT_ID` (WalletConnect Cloud) for the hosted sign page; `WALLET_AUTH_BYPASS=1` for local API-only testing.
- Native callback scheme: `com.likeminded.app://auth/wallet` (iOS) and `com.likeminded.mac://auth/wallet` (macOS).
- iOS handles wallet callbacks in `LikemindedApp.onOpenURL`; macOS in `LikemindedMacApp.onOpenURL`.

## LiveKit (group video meets)

Set on the API server:

```
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your-livekit-api-key
LIVEKIT_API_SECRET=your-livekit-api-secret
```

Flow: signed-in user taps **Join meetup** → `POST /v1/meetings/:id/join` → participant token → `LiveKitMeetSession` in `Sources/Shared/LiveKitMeetSession.swift` connects the room (iOS `GroupVideoCallView`, macOS `meetVideoCall`).

If LiveKit env is missing or join fails, the UI falls back to **preview tiles** and shows the error — useful for layout validation without a LiveKit Cloud project.

Both `Likeminded` and `LikemindedMac` targets link the LiveKit SPM packages (`project.yml`).

## Common traps

### ATS blocks localhost HTTP

The app uses `http://127.0.0.1:8787` to reach the API. iOS App Transport Security blocks cleartext HTTP by default. The fix is in `apps/ios-macos/project.yml`:

```yaml
INFOPLIST_KEY_NSAppTransportSecurity_NSAllowsLocalNetworking: YES
```

If you add a new HTTP endpoint and the app can't reach it, check this first.

### Simulator name vs ID

`build_and_run.sh` resolves simulator by name to UUID. If multiple simulators share a name, use `SIMULATOR_NAME=` env var or edit the script to hardcode the ID.

### Realtime output modalities

OpenAI Realtime API rejects `["text", "audio"]` as output_modalities. Use either `["text"]` or `["audio"]`, not both. Current app uses `["audio"]` so the AI speaks back and text is extracted from `response.output_audio_transcript.delta` events.

### XcodeGen regenerates project

After editing `project.yml`, run `cd apps/ios-macos && xcodegen generate` to regenerate the `.xcodeproj`. The `.xcodeproj` is gitignored — only `project.yml` is source of truth.

## Scripts

| Script | Purpose |
|---|---|
| `./script/run_api.sh [PORT]` | Start API server with env loaded, handles port conflicts |
| `npm run migrate:api` | Create MVP API tables/store for the configured backend |
| `npm run smoke:mvp` | Zero-token MVP backend smoke grader |
| `npm run verify:release-config` | Zero-token TestFlight static config grader |
| `npm run verify:goal` | Zero-token per-session goal contract grader |
| `npm run verify:simulator-local` | Build simulator app, prove fresh auth gate, and prove DEBUG local auth plus deterministic transcript-to-placement |
| `npm run verify:local-product-loop` | Phase 1 — iOS simulator + macOS bypass launch proof |
| `npm run verify:google-auth-config` | Phase 2 — Google OAuth env + plist readiness |
| `npm run deploy:render-preflight` | Phase 3 — Neon/Render env + optional `/health` check |
| `./script/test_profile.sh "transcript"` | Test personality extraction + circle matching without UI |
| `./script/build_and_run.sh` | Build, install, launch app in simulator |
| `./script/build_and_run.sh --logs` | Same + stream app logs |
| `./script/build_and_run.sh --verify` | Build + verify launch (no install) |

## Cursor Cloud (Linux, no Xcode)

Cloud agents run on **Linux with no Swift/Xcode**. Only the Node API (`services/api/src/server.js`, Node 20+) is runnable; it defaults to **local JSON storage** under `./data/` (git-ignored) — no Postgres/`DATABASE_URL` needed. Update script on VM startup is `npm install`.

### Can / cannot

- **Can**: develop/run/test the backend (`services/api`) and Node graders under `script/`; drive the placement loop over HTTP; statically edit SwiftUI sources + `project.yml` (no compile/launch here).
- **Cannot**: build, launch, or screenshot the iOS/macOS native apps. Leave iOS/macOS UI validation-ledger rows to a macOS environment; prove behavior via the API + smoke test instead.

### Run the API (auth bypass, no real Sign in with Apple)

```sh
SESSION_SECRET=local-session-secret-minimum-24-chars APPLE_AUTH_BYPASS=1 node services/api/src/server.js
# or: npm run dev:api:local-auth   (host/port 127.0.0.1:8787; GET /health shows storage mode)
```

Placement loop: `POST /v1/auth/apple` (any body under bypass) → `sessionToken` → send as `Authorization: Bearer <token>` → `/v1/discover` → `/v1/me/placement` → `/v1/me/placement/actions` → `/v1/me/circles` → `/v1/feedback`.

### Scripts to USE (Linux-safe, zero-token)

`npm run check` (lint/syntax gate) · `npm run smoke:mvp` (primary end-to-end backend test) · `dev:api*` runners · `migrate:api` · `seed:test-profiles` / `seed|remove|reset:validation-data` · `replay:latest-profile` · `goal:next` / `phase:preflight -- <N>` · `ledger:open` / `ledger:stale` / `verify:ledger-progress` / `verify:goal` / `verify:release-config` / `verify:external-preflight`.

### Scripts to AVOID (macOS/Xcode-only — fail on Linux)

`verify:simulator-local` · `verify:macos-screens` · `dev:macos:validation` · `audit:macos:*` · `./script/build_and_run.sh` · any `script/macos_*.sh` (all use `xcodebuild`/`simctl`/`xcodegen`/`osascript`).

Notes: `run_api.sh`/`run_validation_api.sh` use `lsof` (present on VM). `OPENAI_API_KEY`/`LIVEKIT_*` are only needed for live voice/video; the placement loop works without them.

## Testing the full pipeline

1. Start API: `./script/run_api.sh` (confirm `curl -s http://127.0.0.1:8787/health` shows `"livekit":true` when video meets are needed)
2. Build + launch: `./script/build_and_run.sh` (iOS) or build `LikemindedMac` scheme (macOS)
3. Sign in with Apple, Google, or wallet on the auth gate
4. In simulator/device: tap Profile → grant mic permission → speak to AI interviewer → stop
5. App sends transcript to authenticated `/v1/discover` → personality signals + circle placement appear
6. Optional: RSVP for a meetup, then **Join meetup** when LiveKit is configured

For local API-only smoke checks without Apple services, `npm run smoke:mvp` uses `APPLE_AUTH_BYPASS=1` in an isolated child process. Do not enable `APPLE_AUTH_BYPASS` in TestFlight or production.

## Testing personality extraction (no UI)

```sh
./script/test_profile.sh "I love deep conversations about ideas..."
```

Or with a file:
```sh
./script/test_profile.sh --file /path/to/transcript.txt
```
