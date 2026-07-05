# Like-minded-app Repo Instructions

## Inheritance Contract

- Global baseline: `/Users/gurusharan/.codex/AGENTS.md`
- Control owner: global `AGENTS.md`
- Local file declares only repo scope, routing, boundaries, and validation

## Scope

- Like-minded-app workspace: SwiftUI iOS/macOS, Node API, local JSON store, validation ledgers, TestFlight path.
- `GOAL.md` — ultimate product goal (scope disputes only).
- `PROGRESS.md` — roadmap checkboxes (active track section only during work).
- `goal.json` — per-session goal, graders, routing.
- `validation/{ios,macos}/*.json` — **control status owner** (pass/fail/pending/stale/blocked + `expected` + evidence).

## Context doctrine (all agents)

1. **Lazy retrieval** — minimum high-signal context for the task. Progressive disclosure only when blocked.
2. **Lazy authoring** — no new docs/workflows when an owner already holds the fact. Edit the owner.
3. **Proactive prune** — delete stale triggers, duplicate status tables, sibling ledgers, historical prose sold as current truth.
4. **Single control chain** — JSON ledger (status) → `PROGRESS.md` track (roadmap) → code. No parallel backlogs.

### First commands (stop when the question is answered)

| Lane | Run | Do not preload |
|------|-----|----------------|
| Any session | `npm run goal:next` | Full `PROGRESS.md`, `GOAL.md` |
| Gap / what's pending | `npm run ledger:open` (`ledger:stale` after source edits) | Source trees, mockup images, design docs |
| Native UI (one screen) | One `validation/*/*.json` + its `source_files` | Other platform, all mockups |
| Backend route | `services/api/src/server.js` family | Native UI docs |
| Phase N | `npm run phase:preflight -- N` | Entire phase history |
| Claim track/goal done | `npm run verify:ledger-progress` | — |
| macOS CUA proof | `./script/macos_audit_prepare.sh` → `macos_cua_screen.sh` | Full app walk |

`./script/project_context.sh query --task "…"`: **only** if `goal:next` is insufficient, `decision_count > 0`, or boundary/decision-graph work. **Skip when zero decisions.**

`workflow --docs-dir … summary <slug>`: **only** when the trigger names one slug **and** that lane is not already covered. Never load multiple summaries for one task.

## Session start

1. `resume-session` only: read `.claude/session-data/CURRENT.md` once if `route_contract.first_command` present.
2. `goal.json` + active slice of `PROGRESS.md` (track named in `goal:next`).
3. `npm run goal:next` → run `first_command`; do not expand retrieval if it answers the task.
4. `git status --short` before edits; `npm run verify:ledger-progress` before claiming track/goal complete.
5. Phase edits: `npm run phase:preflight -- <N>` once, then implement scoped unchecked list.

Next-goal: smallest full-session surface (one screen family, endpoint family, or track)—not a single checkbox unless it is the only blocker.

## Trigger map (compact)

- **API running** before build/run: `curl -s http://127.0.0.1:8787/health`
- **Seeded native validation**: `npm run dev:api:validation` + `npm run reset:validation-data`; mockup paths from ledger JSON `mockup_ref`, not directory walks
- **iOS UI**: `@build-ios-app` skill; `Sources/LikemindedApp`; mockups only for visual work
- **macOS UI**: `@build-macos-app` skill; `Sources/LikemindedMac`; `script/macos_canonical_app.sh` for one binary path
- **Backend**: `services/api/src/server.js`; same `LIKEMINDED_API_BASE_URL` on both natives
- **Boundary / stack change** (rare): `workflow summary project-spine` **or** `project_context query`, not both by default
- **Decision graph** (rare): `workflow summary context-graph`
- **Do not repeat** retrieval already done for the same task unless the task changed or evidence contradicts loaded context

## Project agents

`.codex/agents/` — bounded parallel work only; main thread owns integration.

## Repo rules

- Keep this file compact; details in `docs/workflows/` per lane.
- `apps/ios-macos/project.yml` — XcodeGen owner; never hand-edit `.xcodeproj`.
- iOS → `LikemindedApp/`; macOS → `LikemindedMac/`.
- Command/script changes: update `docs/workflows/validation.md` + `docs/references/project-context.md` in the same change—**edit, don't add** parallel docs.
- No sibling `validation/**/*.md` ledgers; JSON only.

## Cursor Cloud specific instructions

Cloud VM is **Linux with no Swift/Xcode**. Only the Node API (`services/api/src/server.js`, Node 20+) is runnable here. It defaults to **local JSON storage** under `./data/` (git-ignored) — no Postgres/`DATABASE_URL` needed for dev.

### What cloud agents CAN do

- Develop/run/test the **backend** (`services/api`) and the Node graders/scripts under `script/`.
- Start the API with dev auth bypass (so authenticated routes work without real Sign in with Apple): `SESSION_SECRET=local-session-secret-minimum-24-chars APPLE_AUTH_BYPASS=1 node services/api/src/server.js` (or `npm run dev:api:local-auth`). Default host/port is `127.0.0.1:8787`; `GET /health` reports active storage mode.
- Drive the placement loop over HTTP: `POST /v1/auth/apple` (any body under bypass) returns `sessionToken`; pass it as `Authorization: Bearer <token>`, then `/v1/discover` → `/v1/me/placement` → `/v1/me/placement/actions` → `/v1/me/circles` → `/v1/feedback`.
- Edit SwiftUI sources and `apps/ios-macos/project.yml` (code review / static edits), but cannot compile or launch them here.

### Scripts to USE (Linux-safe, zero-token)

- `npm run check` — syntax/lint gate for all JS + shell scripts. Primary lint check.
- `npm run smoke:mvp` — self-contained end-to-end backend test on a temp JSON DB. Primary functional check (no formal unit-test framework exists).
- `npm run dev:api` / `dev:api:local-auth` / `dev:api:validation` — run the API (plain / auth-bypass / seeded validation DB).
- `npm run migrate:api` — initialize the store (JSON locally, Postgres if `DATABASE_URL` set).
- `npm run seed:test-profiles` / `seed:validation-data` / `remove:validation-data` / `reset:validation-data` — seed/reset local JSON test data.
- `npm run replay:latest-profile` — replay latest profile through placement.
- `npm run goal:next` / `phase:preflight -- <N>` — routing/planning.
- `npm run ledger:open` / `ledger:stale` / `verify:ledger-progress` / `verify:goal` / `verify:release-config` / `verify:external-preflight` — status/config graders.

### Scripts to AVOID (macOS/Xcode-only — will fail on Linux)

- `npm run verify:simulator-local`, `npm run verify:macos-screens`, `npm run dev:macos:validation`, `npm run audit:macos:*`.
- `./script/build_and_run.sh` and any `script/macos_*.sh` (they use `xcodebuild`/`simctl`/`xcodegen`/`osascript`).
- Do not attempt to prove iOS/macOS UI in cloud; leave those validation ledger rows to a macOS environment and demonstrate backend behavior via the API + smoke test instead.

### Notes

- `run_api.sh`/`run_validation_api.sh` use `lsof` (present on the VM).
- `OPENAI_API_KEY` and `LIVEKIT_*` are only needed for live voice/video; the placement loop works without them.
