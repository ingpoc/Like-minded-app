# Project Context

**Lazy load only** for boundary disputes or `project_context query` with `decision_count > 0`. Not for gap audits or single-screen work — use `npm run goal:next`, `npm run ledger:screen`, and one `validation/*/*.json`.

Commands and proof: `docs/workflows/validation.md`. Ultimate goal: `GOAL.md`. Session goal: `goal.json`.

## Boundaries

- SwiftUI natives + Node HTTP API; production persistence Neon/Postgres via `DATABASE_URL`; local dev uses `data/` or `LIKEMINDED_DB_DIR`.
- TestFlight path: authenticated `/v1/*` MVP routes — not legacy mock/profile routes.
- iOS bundle `com.likeminded.app`; macOS `com.likeminded.mac`; shared `LIKEMINDED_API_BASE_URL`.
- Auth: Apple + Google + wallet on both natives (`Sources/Shared/`); sessions via Keychain (`AuthSessionStore` / `MacAuthSessionStore`).
- LiveKit group meets: `POST /v1/meetings/:id/join` + `Sources/Shared/LiveKitMeetSession.swift` on iOS and macOS.
- XcodeGen owner: `apps/ios-macos/project.yml` — never hand-edit `.xcodeproj`.
- `APPLE_AUTH_BYPASS=1` and `--likeminded-dev-auth-bypass` are local-only; not TestFlight evidence.
- Do not replace API, Render target, Neon, or XcodeGen workflow without explicit acceptance.
- Context graph (rare): `.context-graph/` + `docs/workflows/context-graph.md` — not this file.

## Update triggers

Edit boundaries here when stack or deployment contracts change. Edit `docs/workflows/validation.md` when commands change — not both with the same facts.
