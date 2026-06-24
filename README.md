# Likeminded

Likeminded is an AI-native iOS/macOS app for AI-guided self-discovery, meaningful community placement, and deep compatibility matching.

This repository is at the first project-spine stage. It keeps the app, backend, AI orchestration, shared schemas, infrastructure notes, and documentation separated while product and stack decisions are still being refined in Notion.

## Structure

- `apps/ios-macos` - SwiftUI app shell source placeholder.
  - now includes an `XcodeGen` iOS project spec and simulator run loop
- `services/api` - minimal backend API with architecture, mock profile, mock recommendation, Reflect -> Place -> Connect, and mock realtime session routes.
- `services/ai-orchestrator` - placeholder boundary for realtime session brokering, tool routing, and profile synthesis with an explicit service manifest.
- `packages/shared-schemas` - shared JSON schemas used across app, backend, and AI services.
- `infra` - local infrastructure notes and future environment contracts.
- `docs` - architecture, validation, and repo context.

## Run Locally

Current runnable surfaces:

```sh
npm run dev:api
./script/build_and_run.sh
```

Then check:

```sh
curl http://127.0.0.1:8787/health
curl http://127.0.0.1:8787/mock/profile
curl http://127.0.0.1:8787/v1/system/architecture
curl http://127.0.0.1:8787/v1/recommendations/communities/mock
curl -X POST http://127.0.0.1:8787/v1/mvp/reflect-place-connect -H 'content-type: application/json' -d '{"reflectionAnswers":["I want warmer conversations","I prefer small honest circles"]}'
```

The default native run path generates the Xcode project, builds the `Likeminded` iOS app, boots `iPhone 16 Pro (iOS 18.6)`, installs the app, and launches it in the simulator.

Run syntax validation:

```sh
npm run check
```

## Current Assumptions

- Backend framework is intentionally undecided. The API starts with Node's built-in HTTP server so the health endpoint exists without committing to FastAPI, NestJS, Supabase Edge Functions, or another framework.
- The architecture contract now reflects the Notion handoff: native app, backend API, realtime session broker, tool gateway, AI orchestration, matching, communities, chat, safety, and subscriptions. These are still placeholders, not full integrations.
- The SwiftUI prototype is now launch-verified on the iOS simulator through `XcodeGen`, but the long-term native project strategy is still open.
- Shared profile and Reflect -> Place -> Connect data start as JSON Schema so clients, backend, and AI orchestration can converge on one contract before code generation is introduced.

## Next Decisions

- Pick the MVP backend framework and persistence approach.
- Choose how to generate/manage the iOS/macOS project: Xcode project, Swift Package, Tuist, XcodeGen, or another native workflow.
- Add real tests once the backend and app toolchains are selected.
