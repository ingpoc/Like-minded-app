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
APPLE_BUNDLE_ID=com.likeminded.app
APPLE_CLIENT_ID=com.likeminded.app
APPLE_AUTH_BYPASS=0
```

## Validation

```sh
npm run verify:release-config
npm run smoke:mvp
```

`npm run smoke:mvp` uses a local isolated store. Deployed Render/Neon readiness still requires a real health check and signed-in device/TestFlight validation.
