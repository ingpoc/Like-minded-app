# Likeminded — MVP Progress

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This file tracks repo progress and roadmap state only.

## Session Start Contract

Every session starts from:

1. `GOAL.md` — ultimate product goal.
2. `PROGRESS.md` — current roadmap and state.
3. `goal.json` — current per-session goal, deterministic graders, simulator validation, rubric, and subagent model/effort routing.
4. `docs/workflows/validation.md` — validation contract.
5. `./script/project_context.sh query --task "<current task>"`.

If graders, validation commands, new release files, or project agents change, update `goal.template.json`, `goal.json`, `docs/workflows/validation.md`, and `docs/references/project-context.md` in the same change.

## Current Status

- TestFlight MVP target: Sign in with Apple -> voice onboarding -> persisted profile and circle placement -> profile review/edit -> accept/swap/defer -> tester feedback.
- Native app is auth-gated and uses MVP tabs: `Talk`, `Circles`, `Profile`.
- Bundle id is `com.likeminded.app`; Sign in with Apple entitlement exists.
- API has authenticated MVP routes for Apple auth, discovery, profile resume/update, placement resume/actions, feedback, and Realtime broker calls.
- Production deployment config targets Render plus Neon/Postgres through `DATABASE_URL`.
- Local development uses JSON-backed storage; local smoke testing uses isolated temporary JSON data.
- Deterministic graders exist for backend MVP contract, release config, and goal contract.
- Remaining hard blockers are external setup and proof: Apple Developer/App Store Connect, Render, Neon, real Sign in with Apple, and real simulator/device voice-loop validation.

## Phase 0 — Session Control And Graders

- [x] Create `goal.template.json` as the per-session goal template.
- [x] Create current `goal.json` for the TestFlight MVP placement loop.
- [x] Add `npm run verify:goal`.
- [x] Pin delegated validation to `validation-release` using `gpt-5.4-mini` at `medium` effort.
- [x] Document what delegated verification can and cannot do.
- [x] Require a validated session commit including `goal.json` before marking a goal complete.
- [x] Remove stale generated artifacts from status and ignore future `__pycache__`, `*.pyc`, `*.egg-info`, `node_modules`, and stray `codex.js`.

## Phase 1 — Local MVP Loop

- [x] Add Sign in with Apple gate in SwiftUI.
- [x] Store app session token in Keychain.
- [x] Protect `/v1/discover`, `/v1/me/profile`, `/v1/me/placement`, `/v1/me/placement/actions`, `/v1/feedback`, and Realtime broker routes with bearer auth.
- [x] Persist profile, placement, transcript, and feedback through the MVP store.
- [x] Add placement actions: accept, defer, swap.
- [x] Add profile review/edit and tester feedback UI.
- [x] Replace prototype tabs with `Talk`, `Circles`, `Profile`.
- [x] Remove hardcoded localhost from the Realtime SDP path.

## Phase 2 — Deterministic Validation

- [x] `npm run check` — syntax checks API, orchestrator, and grader scripts.
- [x] `npm run smoke:mvp` — validates local authenticated placement loop and cross-user isolation.
- [x] `npm run verify:release-config` — validates bundle id, entitlements, Render env placeholders, API base URL, and privacy policy draft.
- [x] `npm run verify:goal` — validates goal contract, graders, rubric, and agent routing.
- [x] `workflow --docs-dir ... lint` — passes with warnings only.
- [x] `./script/build_and_run.sh --verify` — builds, installs, and launches simulator app as `com.likeminded.app`.

## Phase 3 — External TestFlight Readiness

- [ ] Create Neon/Postgres database and set `DATABASE_URL`.
- [ ] Create Render web service from `render.yaml`.
- [ ] Set production env vars: `SESSION_SECRET`, `OPENAI_API_KEY`, `OPENAI_REALTIME_MODEL`, `OPENAI_REALTIME_VOICE`, `APPLE_BUNDLE_ID`, `APPLE_CLIENT_ID`, `APPLE_AUTH_BYPASS=0`.
- [ ] Configure Apple Developer bundle id `com.likeminded.app`.
- [ ] Enable Sign in with Apple capability for the app id.
- [ ] Configure App Store Connect/TestFlight metadata and privacy policy.
- [ ] Build signed TestFlight candidate.

## Phase 4 — Simulator/Device Proof

- [ ] Fresh install shows Sign in with Apple gate, not prototype tabs.
- [ ] Real Apple sign-in succeeds.
- [ ] Signed-in app restores session after relaunch.
- [ ] Tabs are exactly `Talk`, `Circles`, `Profile`.
- [ ] Voice onboarding reaches Realtime through the authenticated backend path.
- [ ] Stopping voice creates persisted profile and circle placement.
- [ ] Relaunch restores latest placement.
- [ ] Circles accept/swap/defer persists through backend.
- [ ] Profile edit persists.
- [ ] Feedback submits and stores.
- [ ] A second tester cannot access the first tester's profile or placement.

## Deferred Until After MVP Proof

- Chat and direct messaging.
- Hosted in-app meetings.
- Push notifications.
- Subscriptions and entitlements.
- Full community engine.
- Advanced moderation/report/block flows.
- Reasoning-model replacement for heuristic profile extraction.
- Offline meeting coordination.
