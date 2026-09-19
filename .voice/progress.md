# Likeminded — MVP Progress

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This file holds **open roadmap checkboxes only**. Phases 0–8 are complete (historical — see git); they are not ledger owners.

## Track — macOS Visual Parity + Ledger Closeout

Status: `validation/screens/*.json` (macOS `flows[].validation.macos`). Proof: `docs/workflows/validation.md` § macOS proof.

- [ ] Reprove the selected macOS band with bundled `@Computer`: voice amplitude, start, stop, profile-placement reload, typed AI interview, and the selected create-event controls. Record each result in the testing ledger before selecting another band.
- [ ] Run the next macOS batch only after the first band is recorded; stop and fix the first semantic failure before continuing.
- [ ] macOS infra-blocked (Phase 9/10): Apple sign-in (`auth` / `sign-in-apple`), LiveKit join (`video-call` / `join-room`).

## Track — iOS Ledger Honesty

Status: `validation/screens/*.json` (iOS `flows[].validation.ios`).

- [ ] Reprove the selected iOS band with the exact planned controls: chat headers and send, open conversation, create-community cancel, selected create-event and recap navigation, settings deletion cancel, soulmate navigation, and voice-session completion. Record each result in the testing ledger.
- [ ] Run the next iOS batch only after the first band is recorded; stop and fix the first semantic failure before continuing.
- [ ] iOS infra-blocked (Phase 9/10): real Apple sign-in (`auth` / `sign-in-apple`) + LiveKit (`meet` / `join-live-meetup`).

## Phase 9 — External TestFlight Readiness

Order of operations: close the native proof bands first; obtain Apple sign-in and LiveKit runtime proof next; then configure the production services and build the signed TestFlight candidate. Do not treat configuration or a successful build as customer acceptance.

- [x] Create Neon/Postgres database and set `DATABASE_URL`.
- [x] Create Render web service from `render.yaml`.
- [x] Set production env vars: `SESSION_SECRET`, `OPENAI_API_KEY`, `OPENAI_REALTIME_MODEL`, `OPENAI_REALTIME_VOICE`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL`, `APPLE_BUNDLE_ID`, `APPLE_CLIENT_ID`, `APPLE_AUTH_BYPASS=0`.
- [x] Provision LiveKit server (self-hosted or LiveKit Cloud). Set `LIVEKIT_URL` to the WebSocket endpoint.
- [x] Configure universal Apple Developer bundle id `com.gurusharan.likeminded` for iOS and macOS.
- [x] Enable Sign in with Apple capability for the primary app id.
- [ ] Configure App Store Connect/TestFlight metadata and privacy policy.
- [x] Add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to `Info.plist`.
- [x] Add repo-side account deletion readiness (`DELETE /v1/me/account`, Settings entry, `npm run smoke:mvp` proof).
- [x] Build signed TestFlight candidate.
