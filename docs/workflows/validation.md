# Validation

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This workflow describes validation commands only.

Validation contract for Like-minded-app.

## Current State

Repo-local validation starts with Node syntax checks and the MVP smoke grader:

```sh
npm run check
npm run smoke:mvp
npm run verify:release-config
npm run verify:goal
npm run verify:simulator-local
```

`npm run smoke:mvp` starts the API on a temporary localhost port with `APPLE_AUTH_BYPASS=1`, uses a temporary local JSON data directory, and verifies:
- unauthenticated MVP write/read routes return `401`,
- dev Apple auth returns a session token,
- authenticated Realtime SDP reaches the backend and reports `openai_api_key_missing` when no local OpenAI key is configured,
- authenticated discovery creates a profile and placement,
- authenticated Realtime `submit_profile_placement` payloads create and resume a persisted profile and placement,
- resume endpoints return the signed-in user's data,
- placement defer, swap, and accept persist,
- feedback stores,
- a second tester cannot read the first tester's placement.

`npm run verify:release-config` verifies TestFlight-critical static configuration:
- bundle id is `com.likeminded.app`, not the old prototype id,
- Sign in with Apple entitlement exists,
- microphone purpose and API base URL config exist,
- Realtime calls use the authenticated API client path instead of hardcoded localhost,
- Render env placeholders include database, session, OpenAI, and Apple settings with `APPLE_AUTH_BYPASS=0`,
- the TestFlight privacy policy draft exists.

`npm run verify:external-preflight` verifies real external proof has been recorded in `release/testflight-evidence.json`. It should fail before Render, Neon, Apple Developer, App Store Connect, signed TestFlight, and real spoken-audio proof are complete.

`npm run verify:goal` verifies the per-session goal contract:
- `goal.json` and `goal.template.json` exist and point to `GOAL.md` plus `PROGRESS.md`,
- deterministic grader commands are current,
- simulator validation is assigned to `validation-release`,
- validation-release is pinned to `gpt-5.4-mini` at `medium` effort,
- completion requires a commit that includes the session's `goal.json` before marking the goal complete,
- rubric weights are valid.

The API health endpoint can be checked manually after setting a 24+ character `SESSION_SECRET` in `.env.local` and starting `npm run dev:api`. For local signed-in simulator validation without editing `.env.local`, use `npm run dev:api:local-auth`:

```sh
curl http://127.0.0.1:8787/health
curl http://127.0.0.1:8787/v1/system/architecture
curl http://127.0.0.1:8787/v1/recommendations/communities/mock
curl -X POST http://127.0.0.1:8787/v1/realtime/session -H 'content-type: application/json' -H 'authorization: Bearer <session-token>' -d '{"safetyIdentifier":"dev-preview-user"}'
curl -X POST http://127.0.0.1:8787/v1/profiles/synthesize -H 'content-type: application/json' -d '{"promptSummary":"User wants deep conversation and emotionally honest friendships."}'
curl -X POST http://127.0.0.1:8787/v1/mvp/reflect-place-connect -H 'content-type: application/json' -d '{"reflectionAnswers":["I want warmer conversations","I prefer small honest circles"]}'
```

The realtime session check returns `401` without an app session and `openai_api_key_missing` until `OPENAI_API_KEY` is configured on the API server. With a valid session and key, it should return an OpenAI Realtime client secret. Production defaults to `gpt-realtime-2`; local cost-sensitive testing should start the API with `npm run dev:api:realtime-test`, which uses `gpt-realtime-1.5`.

The standalone Swift typecheck does not resolve the `LiveKitWebRTC` Swift package. Use the XcodeGen build path for native validation:

```sh
./script/build_and_run.sh --verify
```

Expected first-run simulator evidence:
- the app launches as bundle id `com.likeminded.app`,
- the first screen is the Sign in with Apple gate,
- prototype tabs are hidden before auth,
- the Sign in with Apple entitlement is present,
- the microphone purpose string is present.

After a real Apple sign-in and API configuration, validate the placement loop on simulator or device:
- Talk starts Realtime voice,
- stopping voice creates a persisted profile and circle placement,
- relaunch restores the latest placement,
- Circles accept/swap/defer updates through the backend,
- Profile edits and feedback submit without mock fallback data.

Simulator validation proves the app shell, entitlement, launch, and UI state path. Real spoken profile-signal quality still needs device or simulator audio-input testing with an audible utterance.

## Before Claiming Readiness

1. Re-inventory the repo with `rg --files`.
2. For non-trivial work, confirm `./script/project_context.sh query --task "<current task>"` was run before acting and that applicable returned decisions were used.
3. If a manifest exists, use the package manager or toolchain declared by the repo.
4. If tests, lint, typecheck, or build scripts exist, run the narrowest command that proves the change.
5. Run `npm run check` for JavaScript syntax validation.
6. Run `npm run smoke:mvp` for the zero-token backend MVP contract.
7. Run `npm run verify:release-config` for static TestFlight config invariants.
8. Run `npm run verify:goal` after changing goal, progress, validation, grader, or agent-routing files.
9. If native SwiftUI files, project spec, entitlements, or simulator script changed, run `npm run verify:simulator-local`.
10. Capture or inspect a simulator screenshot when UI gating/navigation changed.
11. For local signed-in simulator navigation without Apple account UI, run `npm run verify:simulator-local`; this proves local app/auth routing and deterministic transcript-to-placement persistence, not real Apple sign-in or spoken audio quality.
12. After validation passes and before marking the goal complete, commit the validated session changes, including that session's `goal.json`.
13. Before marking the full TestFlight goal complete, run `npm run verify:external-preflight`.
14. If no deeper validation command exists for a touched surface, report that clearly and provide deterministic evidence such as file inventory, syntax checks, or generated artifact inspection.

## Delegated Verification

Use the project `validation-release` agent pinned to `gpt-5.4-mini` with `medium` effort when validation is read-heavy, repeatable, screenshot-based, or likely to produce long logs. Keep product and architecture decisions in the main thread.

Allowed delegated work:
- run `npm run check`, `npm run smoke:mvp`, `npm run verify:release-config`, `npm run verify:goal`, `npm run verify:simulator-local`, `npm run migrate:api`, and `workflow lint`;
- inspect simulator screenshots for first-run gate, visible tabs, obvious blank screens, and launch state;
- summarize failures with exact command, failing assertion, likely owner file, and the smallest suggested fix.

Forbidden delegated work:
- change product scope, API contracts, auth policy, persistence strategy, model choice, bundle id, deployment provider, or TestFlight criteria;
- weaken or delete deterministic assertions to make a check pass;
- enable `APPLE_AUTH_BYPASS=1` outside isolated local API smoke tests;
- touch secrets, external accounts, Render, Neon, Apple Developer, App Store Connect, or production data;
- edit files unless the main thread explicitly assigns a bounded fix.

Default main-thread rule: first make the path work, then verify and validate, then remove stale confusing artifacts, then simplify, then automate. If the validation agent finds an issue, the main thread owns whether to fix it directly or delegate a bounded file-level patch.

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
