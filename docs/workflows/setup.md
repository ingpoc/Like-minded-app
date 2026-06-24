# Setup

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
| `./script/test_profile.sh "transcript"` | Test personality extraction + circle matching without UI |
| `./script/build_and_run.sh` | Build, install, launch app in simulator |
| `./script/build_and_run.sh --logs` | Same + stream app logs |
| `./script/build_and_run.sh --verify` | Build + verify launch (no install) |

## Testing the full pipeline

1. Start API: `./script/run_api.sh`
2. Build + launch: `./script/build_and_run.sh`
3. In simulator: tap Talk → grant mic permission → speak to AI interviewer → stop
4. App sends transcript to `/v1/discover` → personality signals + circle placement appear

## Testing personality extraction (no UI)

```sh
./script/test_profile.sh "I love deep conversations about ideas..."
```

Or with a file:
```sh
./script/test_profile.sh --file /path/to/transcript.txt
```
