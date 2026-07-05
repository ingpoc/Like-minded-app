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
APPLE_AUTH_BYPASS=0
```

2. Source it before running the API server:
```sh
set -a && source .env.local && set +a
```

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

1. Start API: `./script/run_api.sh`
2. Build + launch: `./script/build_and_run.sh`
3. Sign in with Apple
4. In simulator/device: tap Profile → grant mic permission → speak to AI interviewer → stop
5. App sends transcript to authenticated `/v1/discover` → personality signals + circle placement appear

For local API-only smoke checks without Apple services, `npm run smoke:mvp` uses `APPLE_AUTH_BYPASS=1` in an isolated child process. Do not enable `APPLE_AUTH_BYPASS` in TestFlight or production.

## Testing personality extraction (no UI)

```sh
./script/test_profile.sh "I love deep conversations about ideas..."
```

Or with a file:
```sh
./script/test_profile.sh --file /path/to/transcript.txt
```
