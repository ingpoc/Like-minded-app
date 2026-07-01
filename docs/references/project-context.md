# Project Context

Reference for stable Like-minded-app repo facts. This doc owns current repo evidence, boundaries, and command reminders. It does not own context-graph workflow or beta-trust procedure.

## Current Evidence

- Workspace path: `/Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app`
- The checkout now has a TestFlight MVP placement-loop spine: `apps/ios-macos`, `services/api`, `services/ai-orchestrator`, `packages/shared-schemas`, `infra`, deployment config, graders, and docs.
- Root `package.json` owns deterministic checks, MVP smoke validation, release-config validation, and goal-contract validation.
- `npm run phase:preflight -- <phase-number>` owns phase-scoped pre-edit checklist extraction from `PROGRESS.md`, stale-name gates, doc-lint risk surfacing, validation order, and the canonical XcodeGen reminder.
- The Node API now has an authenticated MVP placement path: `POST /v1/auth/apple`, protected `POST /v1/discover`, `GET/PATCH /v1/me/profile`, `GET /v1/me/placement`, `POST /v1/me/placement/actions`, and `POST /v1/feedback`.
- Production persistence target is Neon/Postgres through `DATABASE_URL`; local development and smoke grading use JSON files under `data/` or `LIKEMINDED_DB_DIR`.
- Mock/profile/recommendation routes still exist for development, but TestFlight placement should use the authenticated `/v1/*` MVP path.
- `POST /v1/realtime/session` and `POST /v1/realtime/calls` require an app session and broker OpenAI Realtime access when `OPENAI_API_KEY` is configured server-side. Production defaults to `gpt-realtime-2`; local testing uses `OPENAI_REALTIME_MODEL=gpt-realtime-1.5`.
- The iOS SwiftUI app is now auth-gated with Sign in with Apple, has MVP tabs `Talk`, `Circles`, `Communities`, and `Profile`, and uses bundle id `com.likeminded.app`.
- The macOS SwiftUI target lives in `apps/ios-macos/Sources/LikemindedMac`, uses bundle id `com.likeminded.mac`, and shares the `LIKEMINDED_API_BASE_URL` backend contract with the iOS app.
- UI information architecture and copy density are owned by `docs/references/app-design-language.md`.
- The Talk surface uses `RealtimeVoiceClient` to connect to OpenAI Realtime over WebRTC through the backend, request microphone permission, stream PCM audio chunks, and commit voice input for signal extraction
- The iOS native run surface is `./script/build_and_run.sh`, which generates the Xcode project, builds the `Likeminded` iOS target, and launches it in the simulator
- The macOS native validation surface is `(cd apps/ios-macos && xcodegen generate)` followed by `xcodebuild -project Likeminded.xcodeproj -scheme LikemindedMac -destination 'platform=macOS' build`.
- `GOAL.md` owns the ultimate product goal; `goal.json` owns the current per-session goal, deterministic graders, simulator validation, rubric, and subagent model/effort routing.
- Deterministic MVP validation is `npm run phase:preflight -- <phase-number>` before phase edits, then `npm run check`, `npm run smoke:mvp`, `npm run verify:release-config`, `npm run verify:goal`, `npm run verify:simulator-local`, `npm run migrate:api`, and `workflow --docs-dir ... lint`.
- External TestFlight completion proof is `npm run verify:external-preflight` after filling ignored `release/testflight-evidence.json` from the template.

## Boundaries

- Do not assume a frontend framework beyond SwiftUI or a backend framework beyond the current Node HTTP service
- Do not confuse mock routes with production integrations; the authenticated MVP path is the TestFlight path
- Do not replace the current Node HTTP API, Render target, or Neon/Postgres production persistence without explicit acceptance.
- Do not replace XcodeGen or the current iOS simulator workflow without explicit acceptance.
- Regenerate Xcode projects only with `(cd apps/ios-macos && xcodegen generate)`.
- Do not enable `APPLE_AUTH_BYPASS=1` outside local API-only tests
- Do not use `--likeminded-dev-auth-bypass` as TestFlight evidence; it is a DEBUG-only local simulator validation shortcut
- Treat simulator voice verification as transport/state verification; real spoken profile-signal quality still needs device or simulator audio-input testing with an audible utterance
- Do not add project-local agents until the user accepts a recommendation and `workflow summary subagent-playbook` has been checked
- Prefer durable repo docs over long repeated instruction prose in `AGENTS.md`

## Update Triggers

Update this reference when:
- runnable repo surfaces change
- architecture boundary facts change
- validation entrypoints change
- the stable context-graph entrypoints or artifact locations change

If a change affects context-graph operations, beta verification, accepted-decision capture, or supersession flow, update `docs/workflows/context-graph.md` instead of expanding this reference.

## Context Graph

- The repo-local context graph lives under `.context-graph/`
- `tools/project-context/` owns the local CLI package; `./script/project_context.sh` is the stable entrypoint
- `.context-graph/graph.db` is the only canonical graph database
- `docs/workflows/context-graph.md` owns accepted-decision admission, retrieval, trace/history, supersession, and trust checks
- SessionStart, if enabled, may query active decisions only and must not mine, validate, review, promote, or run beta logic
- The graph stores accepted durable decision traces only; raw sessions and rejected candidates are not durable graph state
- Decision versioning is keyed by `decision_key`; reuse the key for the same policy lineage so a new accepted decision supersedes the older version
