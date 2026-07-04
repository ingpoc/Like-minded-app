# Project Context

Reference for stable repo facts. **Lazy load:** use only when `project_context query` returns decisions or boundary work — not for gap audits (`ledger:open`) or single-screen fixes (ledger JSON + `source_files`).

## Current Evidence

- Workspace path: `/Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app`
- The checkout now has a TestFlight MVP placement-loop spine: `apps/ios-macos`, `services/api`, `services/ai-orchestrator`, `packages/shared-schemas`, `infra`, deployment config, graders, and docs.
- Root `package.json` owns deterministic checks, MVP smoke validation, release-config validation, goal-contract validation, validation data seeding/removal, and macOS screen capture validation.
- `npm run phase:preflight -- <phase-number>` owns phase-scoped pre-edit checklist extraction from `PROGRESS.md`, stale-name gates, doc-lint risk surfacing, validation order, and the canonical XcodeGen reminder.
- The Node API now has an authenticated MVP placement path: `POST /v1/auth/apple`, protected `POST /v1/discover`, `GET/PATCH /v1/me/profile`, `GET /v1/me/placement`, `POST /v1/me/placement/actions`, and `POST /v1/feedback`.
- Production persistence target is Neon/Postgres through `DATABASE_URL`; local development and smoke grading use JSON files under `data/` or `LIKEMINDED_DB_DIR`.
- Repeatable seeded validation uses `npm run dev:api:validation`, which attaches the local API to `data/validation-db` with `LIKEMINDED_DB_DIR`; empty or real-user local testing should use the normal database path.
- Mock/profile/recommendation routes still exist for development, but TestFlight placement should use the authenticated `/v1/*` MVP path.
- `POST /v1/realtime/session` and `POST /v1/realtime/calls` require an app session and broker OpenAI Realtime access when `OPENAI_API_KEY` is configured server-side. Production defaults to `gpt-realtime-2`; local testing uses `OPENAI_REALTIME_MODEL=gpt-realtime-1.5`.
- The iOS SwiftUI app is now auth-gated with Sign in with Apple, has tabs `Meet`, `Circles`, `Communities`, `Profile`, plus `Soulmate` when enabled, and uses bundle id `com.likeminded.app`.
- The macOS SwiftUI target lives in `apps/ios-macos/Sources/LikemindedMac`, uses bundle id `com.likeminded.mac`, and shares the `LIKEMINDED_API_BASE_URL` backend contract with the iOS app.
- UI information architecture, copy density, and visual language are owned by `DESIGN.md`.
- The Profile surface uses `RealtimeVoiceClient` to connect to OpenAI Realtime over WebRTC through the backend, request microphone permission, stream PCM audio chunks, and commit voice input for signal extraction.
- The iOS native run surface is `./script/build_and_run.sh`, which generates the Xcode project, builds the `Likeminded` iOS target, and launches it in the simulator
- The macOS native validation surface is `npm run verify:macos-screens`, which starts the validation API on `data/validation-db`, resets seeded data, builds `LikemindedMac`, launches each `MacPrototypeScreen`, writes screenshots under `output/validation/macos-screens/`, then removes seeded data.
- `GOAL.md` owns the ultimate product goal; `goal.json` owns the current per-session goal, deterministic graders, simulator validation, rubric, and subagent model/effort routing.
- Deterministic validation commands: `docs/workflows/validation.md` (table). Ledger gate: `npm run verify:ledger-progress`; route: `npm run goal:next`.
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
