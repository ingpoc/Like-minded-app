# Project Context

**Lazy load only** for boundary disputes or `project_context query` with `decision_count > 0`. Session routing: `npm run goal:next`. Commands: `docs/workflows/validation.md`.

## Boundaries

- SwiftUI natives + Node HTTP API; production persistence Neon/Postgres via `DATABASE_URL`; local dev uses `data/` or `LIKEMINDED_DB_DIR`.
- TestFlight path: authenticated `/v1/*` MVP routes — not legacy mock/profile routes.
- iOS external beta owner: invite-only `Likeminded Early Access` group; public privacy owner is `docs/references/privacy-policy-testflight.md`, served by `GET /privacy`; external proof is schema-2 `release/testflight-evidence.json`.
- Universal iOS/macOS bundle `com.gurusharan.likeminded`; Apple team `9UPQL479Z5`; App Store Connect Apple ID `6792839764`; shared `LIKEMINDED_API_BASE_URL`.
- Auth: Apple + Google + wallet on both natives (`Sources/Shared/`); sessions via Keychain (`AuthSessionStore` / `MacAuthSessionStore`).
- LiveKit group meets: `POST /v1/meetings/:id/join` + `Sources/Shared/LiveKitMeetSession.swift` on iOS and macOS.
- XcodeGen owner: `apps/ios-macos/project.yml` — never hand-edit `.xcodeproj`.
- `APPLE_AUTH_BYPASS=1` and `--likeminded-dev-auth-bypass` are local-only; not TestFlight evidence.
- Every signed iOS export must pass `npm run verify:ios-release-candidate -- /absolute/path/to/export/Payload/Likeminded.app`; placeholder Google OAuth values and Release auth-bypass strings are hard failures.
- Do not replace API, Render target, Neon, or XcodeGen workflow without explicit acceptance.
- Context graph (rare): `.context-graph/` + `docs/workflows/context-graph.md` — not this file.

## Update triggers

Edit boundaries here when stack or deployment contracts change. Edit `docs/workflows/validation.md` when commands change — not both with the same facts.
