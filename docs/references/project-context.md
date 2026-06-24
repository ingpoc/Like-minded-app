# Project Context

Reference for stable Like-minded-app repo facts. This doc owns current repo evidence, boundaries, and command reminders. It does not own context-graph workflow or beta-trust procedure.

## Current Evidence

- Workspace path: `/Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app`
- The checkout began empty and now has a first project spine: `apps/ios-macos`, `services/api`, `services/ai-orchestrator`, `packages/shared-schemas`, `infra`, and `docs`
- Root `package.json` exists for dependency-light Node checks and the local API health endpoint
- The Node API exposes mock MVP routes for profile synthesis, recommendations, and `POST /v1/mvp/reflect-place-connect`; `POST /v1/realtime/session` brokers OpenAI Realtime client secrets when `OPENAI_API_KEY` is configured server-side. Production defaults to `gpt-realtime-2`; local testing uses `OPENAI_REALTIME_MODEL=gpt-realtime-1.5`.
- The SwiftUI prototype is now a multi-file shell with an `XcodeGen` project spec at `apps/ios-macos/project.yml`
- The Talk surface uses `RealtimeVoiceClient` to connect to OpenAI Realtime over WebSocket, request microphone permission, stream PCM audio chunks, and commit voice input for signal extraction
- The native run surface is `./script/build_and_run.sh`, which generates the Xcode project, builds the `Likeminded` iOS target, and launches it in the simulator

## Boundaries

- Do not assume frontend framework, database, hosting target, authentication provider, or test runner
- Do not confuse mock routes with production integrations; the Realtime session route is a real OpenAI boundary but still lacks app auth, persistence, quota controls, and production observability
- Do not treat the Node health endpoint as the final backend framework decision
- Do not treat the current iOS simulator target as the final native project strategy
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
