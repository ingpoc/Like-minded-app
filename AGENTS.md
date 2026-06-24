# Like-minded-app Repo Instructions

## Inheritance Contract

- Global baseline: `/Users/gurusharan/.codex/AGENTS.md`
- Control owner: global `AGENTS.md`
- Local file declares only repo scope, routing, boundaries, and validation

## Scope

- Like-minded-app workspace.
- Current checkout evidence is a first project spine: SwiftUI placeholder, Node API health endpoint, AI orchestrator placeholder, shared schema, infra notes, and docs.
- Do not infer final backend framework, native project generator, database, deployment, auth, or test runner until repo files or user requirements establish them.
- Guidance lives under `docs/` and should load through `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary <doc>`.

## Trigger Map

- BEFORE non-trivial repo work: if a route contract or task hint already names a first command, verify that command first; otherwise run `./script/project_context.sh query --task "<current task>"` and load only the returned durable decisions plus the workflow doc needed for the current lane.
- BEFORE build/run/test: verify API server is running (`curl -s http://127.0.0.1:8787/health`) and check env is loaded.
- BEFORE adding app structure, dependencies, or framework assumptions: `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary bootstrap-and-discovery`
- BEFORE changing app/API/AI/schema/infra boundaries: `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary project-spine`
- BEFORE mining sessions, prompt history, or operator intent: `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary context-graph`
- BEFORE relying on durable project decision history or context graph state: `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary context-graph`
- BEFORE context-graph trust claims: follow `docs/workflows/context-graph.md`; use the global beta registry only as maturity tracking, not as a local workflow owner.
- BEFORE acting on every non-trivial task after the first query: do not repeat broad workflow loading already performed for the same task unless the task changes, the first retrieval was insufficient, or live evidence contradicts it; re-query when the task or decision point changes.
- BEFORE claiming validation or readiness: `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs summary validation`
- BEFORE creating or optimizing project agents: `workflow summary subagent-playbook`

## Project Agents

- Project-scoped custom agents live in `.codex/agents/`.
- Use them only for bounded, parallel, or context-isolating work; keep integration judgment in the main thread.
- Available agents: `native-app`, `backend-authority`, `ai-orchestrator`, `matching-schema`, `privacy-safety`, `validation-release`.

## Repo Rules

- Keep this file compact; put detailed workflow or architecture guidance in `docs/`.
- Do not duplicate global doctrine here.
- Treat `./script/project_context.sh query --task "<current task>"` as the primary entrypoint for non-trivial repo work; do not pair it with broad `workflow summary` loading by default.
- Preserve awareness of what is already loaded in context for the current task; do not repeat retrieval or rerun an equivalent task because another surface mentions the same rule.
- Global beta tracking can audit maturity, but it does not replace the system's own workflow.
- Treat `services/api/src/server.js` as a minimal runnable health/mock endpoint, not a final backend-framework decision.
- Treat `apps/ios-macos/Sources/LikemindedApp/LikemindedApp.swift` as SwiftUI source placeholder until a native project workflow is chosen.
- Add project-specific agents only after user acceptance and repo evidence justify repeated workflows, risk isolation, or cheaper bounded execution.
- When stack choices, runnable surfaces, or validation commands change, update `docs/references/project-context.md` and `docs/workflows/validation.md` in the same change.
- When project decision-history, context-graph stack, or validation commands change, update `docs/workflows/context-graph.md`, `docs/references/project-context.md`, and `docs/workflows/validation.md` in the same change.
