# Likeminded

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This README describes repo state and runnable surfaces only.

Likeminded is an AI-native iOS/macOS app for AI-guided self-discovery, meaningful community placement, and deep compatibility matching.

This repository is moving from prototype to a TestFlight MVP for the placement loop: Sign in with Apple → voice profile → persisted profile and circle placement → profile review → placement action → tester feedback.

## Structure

- `apps/ios-macos` - SwiftUI iOS app with Sign in with Apple gate and MVP tabs: Talk, Circles, Profile.
  - includes an `XcodeGen` iOS project spec, Sign in with Apple entitlement, and simulator run loop
- `services/api` - Node API with authenticated MVP placement routes, Realtime broker routes, local JSON storage for development, and Postgres support for deployment.
- `services/ai-orchestrator` - placeholder boundary for realtime session brokering, tool routing, and profile synthesis with an explicit service manifest.
- `packages/shared-schemas` - shared JSON schemas used across app, backend, and AI services.
- `infra` - local infrastructure notes and future environment contracts.
- `docs` - architecture, validation, and repo context.

## Run Locally

Start each session by reading `GOAL.md`, `PROGRESS.md`, and `goal.json`. `goal.json` is the current per-session execution contract: graders, simulator validation, rubric, and model/effort routing for project agents.

Current runnable surfaces:

```sh
npm run dev:api
./script/build_and_run.sh
```

Then check:

```sh
curl http://127.0.0.1:8787/health
curl http://127.0.0.1:8787/v1/system/architecture
```

The default native run path generates the Xcode project, builds the `Likeminded` iOS app, boots an available `iPhone 17` simulator, installs the app, and launches bundle id `com.likeminded.app`.

Run validation:

```sh
npm run check
npm run smoke:mvp
npm run verify:release-config
npm run verify:goal
./script/build_and_run.sh --verify
```

## Current Assumptions

- Backend framework is intentionally minimal: the API uses Node's built-in HTTP server for the TestFlight MVP.
- Production deployment target is Render + Neon Postgres through `DATABASE_URL`; local smoke tests use isolated JSON storage.
- Realtime, discovery, placement actions, and feedback require an app session token.
- The SwiftUI app is launch-verified on the iOS simulator through `XcodeGen`, but the long-term native project strategy is still open.
- Shared profile and Reflect -> Place -> Connect data start as JSON Schema so clients, backend, and AI orchestration can converge on one contract before code generation is introduced.

## Next Decisions

- Create Render service and Neon database, then set production env vars.
- Configure Apple Developer/App Store Connect for bundle id `com.likeminded.app` and Sign in with Apple.
- Run the full voice loop on a signed-in physical device before wider TestFlight invites.
