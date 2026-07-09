# Likeminded — MVP Progress

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This file holds **open roadmap checkboxes only**. Phases 0–8 are complete (historical — see git); they are not ledger owners.

## Current Status

- **Session entry:** `npm run goal:next` only → run `first_command`; do not read this file, `GOAL.md`, or `CURRENT.md` for routing.
- Control status: `validation/screens/*.json`. Roadmap checkboxes: this file (active track sections only).
- Design: `DESIGN.md`. Product: `docs/product-direction.md`. Commands: `docs/workflows/validation.md`.
- **macOS track** — `stale_pass` rows open (reproof required). Infra-blocked: Apple sign-in, LiveKit join.
- **iOS track** — `stale_pass` rows open (reproof required). Infra-blocked: Apple sign-in, LiveKit join.
- Phase 9 starts only when `npm run verify:ledger-progress` passes and both tracks have zero actionable `fail`/`pending`/`stale_pass` (infra `blocked` excepted).

## Track — macOS Visual Parity + Ledger Closeout

Status: `validation/screens/*.json` (macOS `flows[].validation.macos`). Proof: `docs/workflows/validation.md` § macOS proof.

- [ ] macOS stale_pass reproof after source edits (`npm run macos:validation-batch -- --stale-only --cua-only` or `npm run validation:wave2-reproof`).
- [ ] macOS infra-blocked (Phase 9/10): Apple sign-in (`auth` / `sign-in-apple`), LiveKit join (`video-call` / `join-room`).

## Track — iOS Ledger Honesty

Status: `validation/screens/*.json` (iOS `flows[].validation.ios`).

- [ ] iOS stale_pass reproof (`npm run verify:ios-screens -- --stale-only` or `npm run validation:wave2-reproof`).
- [ ] iOS infra-blocked (Phase 9/10): real Apple sign-in (`auth` / `sign-in-apple`) + LiveKit (`meet` / `join-live-meetup`).

## Phase 9 — External TestFlight Readiness

- [ ] Create Neon/Postgres database and set `DATABASE_URL`.
- [ ] Create Render web service from `render.yaml`.
- [ ] Set production env vars: `SESSION_SECRET`, `OPENAI_API_KEY`, `OPENAI_REALTIME_MODEL`, `OPENAI_REALTIME_VOICE`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL`, `APPLE_BUNDLE_ID`, `APPLE_CLIENT_ID`, `APPLE_AUTH_BYPASS=0`.
- [ ] Provision LiveKit server (self-hosted or LiveKit Cloud). Set `LIVEKIT_URL` to the WebSocket endpoint.
- [ ] Configure Apple Developer bundle id `com.likeminded.app`.
- [ ] Enable Sign in with Apple capability for the app id.
- [ ] Configure App Store Connect/TestFlight metadata and privacy policy.
- [x] Add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to `Info.plist`.
- [x] Add repo-side account deletion readiness (`DELETE /v1/me/account`, Settings entry, `npm run smoke:mvp` proof).
- [ ] Build signed TestFlight candidate.
