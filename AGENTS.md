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

- Cloud VM is **Linux, no Swift/Xcode**: only the Node API (`services/api`, local JSON storage) is runnable — never run macOS/simulator scripts (`verify:simulator-local`, `verify:macos-screens`, `dev:macos:validation`, `audit:macos:*`, `build_and_run.sh`, `macos_*.sh`).
- Full can/cannot list, cloud run command, and Linux-safe vs Xcode-only script tables: `docs/workflows/setup.md` → "Cursor Cloud (Linux, no Xcode)".
