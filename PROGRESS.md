# Likeminded — MVP Progress

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This file holds **open roadmap checkboxes only**. Phases 0–8 are complete (historical — see git); they are not ledger owners.

## Current Status

- Route: `npm run goal:next` → `first_command`. Control status: `validation/{ios,macos}/*.json` only.
- Design: `DESIGN.md`. Product behavior: `docs/product-direction.md`. Commands: `docs/workflows/validation.md`.
- **macOS track** — `ui_validation` green; reproof `stale_pass` after Swift edits via `npm run macos:validation-batch`.
- **iOS track** — `stale_pass` reproof open; owner `validation/ios/*.json`.
- Phase 9 (external TestFlight) starts only when ledger tracks are clean and `npm run verify:ledger-progress` passes.

## Track — macOS Visual Parity + Ledger Closeout

Status: `validation/macos/*.json`. Proof: `docs/workflows/validation.md` § macOS proof.

- [ ] macOS stale_pass reproof after `MacScreens.swift` / `DoodleArt` edits (`npm run macos:validation-batch`).
- [ ] macOS infra-blocked (Phase 9/10): Apple sign-in (`01-welcome.json`), LiveKit join (`21-meet-video-call.json` `join-room`).

## Track — iOS Ledger Honesty

Status: `validation/ios/*.json`.

- [ ] iOS stale_pass reproof (`npm run ledger:stale` → reproof controls vs `source_hash`).
- [ ] iOS infra-blocked (Phase 9/10): real Apple sign-in + LiveKit on device.

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
