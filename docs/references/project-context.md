# Project Context

Reference for stable Like-minded-app repo facts. This doc owns current repo evidence, boundaries, and command reminders. It does not own context-graph workflow or beta-trust procedure.

## Current Evidence

- Workspace path: `/Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app`
- The checkout now has a TestFlight MVP placement-loop spine: `apps/ios-macos`, `services/api`, `services/ai-orchestrator`, `packages/shared-schemas`, `infra`, deployment config, graders, and docs.
- Root `package.json` owns deterministic checks, MVP smoke validation, release-config validation, and goal-contract validation.
- The Node API now has an authenticated MVP placement path: `POST /v1/auth/apple`, protected `POST /v1/discover`, `GET/PATCH /v1/me/profile`, `GET /v1/me/placement`, `POST /v1/me/placement/actions`, and `POST /v1/feedback`.
- Production persistence target is Neon/Postgres through `DATABASE_URL`; local development and smoke grading use JSON files under `data/` or `LIKEMINDED_DB_DIR`.
- Mock/profile/recommendation routes still exist for development, but TestFlight placement should use the authenticated `/v1/*` MVP path.
- `POST /v1/realtime/session` and `POST /v1/realtime/calls` require an app session and broker OpenAI Realtime access when `OPENAI_API_KEY` is configured server-side. Production defaults to `gpt-realtime-2`; local testing uses `OPENAI_REALTIME_MODEL=gpt-realtime-1.5`.
- The SwiftUI app is now auth-gated with Sign in with Apple, has MVP tabs `Talk`, `Circles`, and `Profile`, and uses bundle id `com.likeminded.app`.
- The Talk surface uses `RealtimeVoiceClient` to connect to OpenAI Realtime over WebRTC through the backend, request microphone permission, stream PCM audio chunks, and commit voice input for signal extraction
- The native run surface is `./script/build_and_run.sh`, which generates the Xcode project, builds the `Likeminded` iOS target, and launches it in the simulator
- `GOAL.md` owns the ultimate product goal; `goal.json` owns the current per-session goal, deterministic graders, simulator validation, rubric, and subagent model/effort routing. Start sessions by reading `PROGRESS.md` and `goal.json`.
- Deterministic MVP validation is `npm run check`, `npm run smoke:mvp`, `npm run verify:release-config`, `npm run verify:goal`, `npm run migrate:api`, `workflow --docs-dir ... lint`, and `./script/build_and_run.sh --verify` when native files changed.

## Boundaries

- Do not assume a frontend framework beyond SwiftUI or a backend framework beyond the current Node HTTP service
- Do not confuse mock routes with production integrations; the authenticated MVP path is the TestFlight path
- Do not replace the current Node HTTP API, Render target, or Neon/Postgres production persistence without explicit acceptance.
- Do not replace XcodeGen or the current iOS simulator workflow without explicit acceptance.
- Do not enable `APPLE_AUTH_BYPASS=1` outside local API-only tests
- Treat simulator voice verification as transport/state verification; real spoken profile-signal quality still needs device or simulator audio-input testing with an audible utterance
- Do not add project-local agents until the user accepts a recommendation and `workflow summary subagent-playbook` has been checked
- Prefer durable repo docs over long repeated instruction prose in `AGENTS.md`

## Update Triggers

Update this reference when:
- runnable repo surfaces change
- architecture boundary facts change
- validation entrypoints change
- the stable context-graph entrypoints or artifact locations change

If a change affects context-graph operations, beta verification, mining, source inventory, or review flow, update `docs/workflows/context-graph.md` instead of expanding this reference.

## Context Graph

- The repo-local context graph lives under `.context-graph/`
- `tools/project-context/` owns the local CLI package; `./script/project_context.sh` is the stable entrypoint
- `.context-graph/graph.db` is the only canonical graph database
- `docs/workflows/context-graph.md` owns mining, source inventory, review, and trust checks
- SessionStart, if enabled, should run only `pending-mining` triage and must not mine, validate, review, promote, or run beta logic
- Deterministic mining stages candidates only; promotion into active repo-local context requires explicit agent review
- Promotion versioning is keyed by `decision_key`; reuse the key for the same policy lineage so promotion supersedes the older version
