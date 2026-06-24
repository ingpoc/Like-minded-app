# Validation

Validation contract for Like-minded-app.

## Current State

Repo-local validation starts with dependency-free Node syntax checks:

```sh
npm run check
```

The API health endpoint can be checked manually after starting `npm run dev:api`:

```sh
curl http://127.0.0.1:8787/health
curl http://127.0.0.1:8787/v1/system/architecture
curl http://127.0.0.1:8787/v1/recommendations/communities/mock
curl -X POST http://127.0.0.1:8787/v1/realtime/session -H 'content-type: application/json' -d '{"safetyIdentifier":"dev-preview-user"}'
curl -X POST http://127.0.0.1:8787/v1/profiles/synthesize -H 'content-type: application/json' -d '{"promptSummary":"User wants deep conversation and emotionally honest friendships."}'
curl -X POST http://127.0.0.1:8787/v1/mvp/reflect-place-connect -H 'content-type: application/json' -d '{"reflectionAnswers":["I want warmer conversations","I prefer small honest circles"]}'
```

The realtime session check returns `openai_api_key_missing` until `OPENAI_API_KEY` is configured on the API server. With a key, it should return an OpenAI Realtime client secret. Production defaults to `gpt-realtime-2`; local cost-sensitive testing should start the API with `npm run dev:api:realtime-test`, which uses `gpt-realtime-1.5`.

The SwiftUI prototype source can be typechecked against the local macOS SDK:

```sh
xcrun --sdk macosx swiftc -typecheck $(find apps/ios-macos/Sources/LikemindedApp -name '*.swift' | sort)
```

The iOS simulator prototype can be built and launched with:

```sh
./script/build_and_run.sh --verify
```

For the Talk voice loop, run the API with `npm run dev:api:realtime-test`, launch the app, open Talk, and tap `Start voice profile`. Expected simulator evidence:
- the microphone permission prompt uses the project-specific purpose string,
- the Talk card reaches `Listening` with `Realtime session ready`,
- tapping `Stop and extract signals` returns the card to `Captured` without crashing.

Simulator validation proves the Realtime credential, WebSocket session, microphone permission, and UI state path. It does not prove real spoken signal quality unless the simulator/device receives audible input and returns transcript/signals.

No full build, lint, or test suite exists yet for the native app or backend framework.

## Before Claiming Readiness

1. Re-inventory the repo with `rg --files`.
2. For non-trivial work, confirm `./script/project_context.sh query --task "<current task>"` was run before acting and that applicable returned decisions were used.
3. If a manifest exists, use the package manager or toolchain declared by the repo.
4. If tests, lint, typecheck, or build scripts exist, run the narrowest command that proves the change.
5. Run `npm run check` for current JavaScript syntax validation.
6. If native SwiftUI files changed, run `xcrun --sdk macosx swiftc -typecheck $(find apps/ios-macos/Sources/LikemindedApp -name '*.swift' | sort)`.
7. If the iOS project spec or simulator script changed, run `./script/build_and_run.sh --verify`.
8. If no deeper validation command exists for a touched surface, report that clearly and provide deterministic evidence such as file inventory, syntax checks, or generated artifact inspection.

## Update Triggers

Update this workflow when:
- a package manager is selected
- build, lint, typecheck, or test scripts are added
- CI configuration appears
- browser verification becomes required
- the default simulator device or iOS project shape changes

## Output Contract

Report:
- commands run
- pass/fail result
- relevant failure lines
- any validation gaps that remain
