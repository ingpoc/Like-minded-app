# Like-minded-app Repo Instructions

## Inheritance Contract

- Global baseline: `/Users/gurusharan/.codex/AGENTS.md`
- Control owner: global `AGENTS.md`
- Local file declares only repo scope, routing, boundaries, and validation

## Scope

- Like-minded-app workspace.
- Current checkout evidence is a TestFlight MVP placement-loop workspace: SwiftUI auth-gated app, Node HTTP API, OpenAI Realtime backend broker, local JSON development store, Render/Neon deployment config, shared schemas, infra notes, and docs.
- `GOAL.md` owns the ultimate product goal; `PROGRESS.md` owns roadmap state; `goal.json` owns the current per-session goal, graders, rubric, and project-agent model/effort routing.
- Guidance lives under `docs/` and should load through `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary <doc>`.

## Session Start

1. If `resume-session` is explicitly triggered, read `.claude/session-data/CURRENT.md` once and verify `route_contract.first_command` if present.
2. Read `PROGRESS.md` and `goal.json`.
3. If `goal.json.status == "completed"`, do not resume that goal; set `goal.json` from `goal.template.json` to the next coherent unchecked surface in `PROGRESS.md`, then continue from that new goal.
4. Otherwise treat an existing `goal.json` goal as active unless `PROGRESS.md`, required graders/evidence, and any required completion commit prove it is complete.
5. If no active goal exists, copy `goal.template.json` → `goal.json` and set `goal` to the next coherent unchecked surface in `PROGRESS.md`.
6. Set the Codex thread goal from the active `goal.json`, then run `./script/project_context.sh query --task "<active goal>"`.
7. Load only returned active decisions; if the query returns zero decisions, continue from `goal.json` and the narrow workflow for the lane instead of expanding retrieval.
8. Before editing phase-scoped work, run `npm run phase:preflight -- <phase-number>` and use its unchecked items, stale-name gate, doc-lint risks, and validation order as the acceptance checklist.
9. Before editing, run `git status --short`; at closeout, update `PROGRESS.md` and `goal.json` if state changed.

Next-goal selection: choose the smallest surface that can use a full session: one phase, screen, endpoint family, validation lane, or doc set with its required tests. Do not pick a trivial one-checkbox goal unless it is the only blocker; group adjacent tiny checkboxes under the same owner surface.

## Trigger Map

- BEFORE non-trivial repo work: if a route contract or task hint already names a first command, verify that command first; otherwise run `./script/project_context.sh query --task "<current task>"` and load only the returned durable decisions plus the workflow doc needed for the current lane.
- BEFORE phase-scoped build work: run `npm run phase:preflight -- <phase-number>` after the project-context query and before edits. Do not claim the phase complete until the scoped unchecked list is empty and the stale-name gate is clean.
- BEFORE build/run/test: verify API server is running (`curl -s http://127.0.0.1:8787/health`) and check env is loaded.
- BEFORE adding app structure, dependencies, or framework assumptions: `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary bootstrap-and-discovery`
- BEFORE changing app/API/AI/schema/infra boundaries: `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary project-spine`
- BEFORE recording save-time decisions or changing decision-graph behavior: `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary context-graph`
- BEFORE relying on durable project decision history or context graph state: `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary context-graph`
- BEFORE context-graph trust claims: follow `docs/workflows/context-graph.md`; use the global beta registry only as maturity tracking, not as a local workflow owner.
- BEFORE acting on every non-trivial task after the first query: do not repeat broad workflow loading already performed for the same task unless the task changes, the first retrieval was insufficient, or live evidence contradicts it; re-query when the task or decision point changes.
- BEFORE claiming validation or readiness: `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary validation`
- BEFORE using fresh/resume agent simulation to test any workflow: `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary agent-simulation`
- BEFORE creating or optimizing project agents: `workflow summary subagent-playbook`

## Project Agents

- Project-scoped custom agents live in `.codex/agents/`.
- Use them only for bounded, parallel, or context-isolating work; keep integration judgment in the main thread.
- Available agents: `native-app`, `backend-authority`, `ai-orchestrator`, `matching-schema`, `privacy-safety`, `validation-release`.

## Repo Rules

- Keep this file compact; put detailed workflow or architecture guidance in `docs/`.
- Do not duplicate global doctrine here.
- Treat `./script/project_context.sh query --task "<current task>"` as the primary entrypoint for non-trivial repo work; do not pair it with broad `workflow summary` loading by default.
- Treat `npm run phase:preflight -- <phase-number>` as the primary checklist extractor for phase work; it is a pre-edit routing aid, not a replacement for validation.
- Preserve awareness of what is already loaded in context for the current task; do not repeat retrieval or rerun an equivalent task because another surface mentions the same rule.
- Global beta tracking can audit maturity, but it does not replace the system's own workflow.
- Treat `services/api/src/server.js` as the current MVP Node HTTP API surface; do not replace the backend framework or deployment target without explicit acceptance.
- Treat `apps/ios-macos/project.yml` as the current native project source of truth; regenerate the Xcode project through XcodeGen after project spec changes.
- Keep `goal.template.json` and `goal.json` current when graders, validation, release files, or project-agent routing change.
- Add project-specific agents only after user acceptance and repo evidence justify repeated workflows, risk isolation, or cheaper bounded execution.
- When stack choices, runnable surfaces, or validation commands change, update `docs/references/project-context.md` and `docs/workflows/validation.md` in the same change.
- When project decision-history, context-graph stack, or validation commands change, update `docs/workflows/context-graph.md`, `docs/references/project-context.md`, and `docs/workflows/validation.md` in the same change.
