# Infrastructure

Infrastructure notes for the TestFlight MVP.

## Current Target

- API runtime: Render web service, described by `render.yaml`.
- Production database: Neon/Postgres through `DATABASE_URL`.
- Secrets: Render environment variables for `SESSION_SECRET`, `OPENAI_API_KEY`, Apple identifiers, and Realtime settings.
- Local storage: JSON files under `data/` or `LIKEMINDED_DB_DIR`.

## Required Production Environment

```sh
DATABASE_URL=
SESSION_SECRET=
OPENAI_API_KEY=
OPENAI_REALTIME_MODEL=gpt-realtime-2
OPENAI_REALTIME_VOICE=marin
APPLE_BUNDLE_ID=com.gurusharan.likeminded
APPLE_CLIENT_ID=com.gurusharan.likeminded
APPLE_AUTH_BYPASS=0
```

## Validation

```sh
npm run verify:release-config
npm run smoke:mvp
npm run verify:local-product-loop
npm run verify:google-auth-config
npm run deploy:render-preflight
npm run verify:external-preflight
```

## Operator workflows

| Phase | Doc |
|-------|-----|
| 2 — Google Sign-In | [`docs/workflows/google-oauth-setup.md`](../docs/workflows/google-oauth-setup.md) |
| 3 — Render + Neon | [`docs/workflows/render-neon-deploy.md`](../docs/workflows/render-neon-deploy.md) |
| 4 — LiveKit | [`docs/workflows/livekit-setup.md`](../docs/workflows/livekit-setup.md) |
| 5 — TestFlight | [`docs/workflows/testflight-operator-checklist.md`](../docs/workflows/testflight-operator-checklist.md) |

`npm run smoke:mvp` uses a local isolated store. `npm run verify:external-preflight` is expected to fail until `release/testflight-evidence.json` is copied from `release/testflight-evidence.template.json` and filled after real Render/Neon/Apple/TestFlight proof.
