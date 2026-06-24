# API Service

Minimal backend boundary for deterministic product behavior.

## Current Routes

- `GET /health` - returns service health and version.
- `GET /v1/system/architecture` - returns the current architecture contract exposed by the API surface.
- `GET /mock/profile` and `GET /v1/profiles/mock` - return a mock profile-shaped payload for app integration.
- `GET /v1/recommendations/communities/mock` - returns mock community recommendations.
- `GET /v1/recommendations/matches/mock` - returns mock one-to-one match recommendations.
- `POST /v1/realtime/session` - creates an OpenAI Realtime client secret using the server-side `OPENAI_API_KEY`.
- `POST /v1/profiles/synthesize` - returns a mock synthesized profile reflection from JSON input.
- `POST /v1/mvp/reflect-place-connect` - returns the first vertical slice: reflection, starter circle placement, and a consent-aware connection path.

## Run

```sh
npm run dev:api
```

The service listens on `127.0.0.1:8787` by default. Set `PORT` to override.

For voice sessions, set `OPENAI_API_KEY` on the API server. Production defaults to `gpt-realtime-2`; local testing can use `npm run dev:api:realtime-test`, which sets `OPENAI_REALTIME_MODEL=gpt-realtime-1.5`. The default Realtime voice is `marin`; override with `OPENAI_REALTIME_VOICE`.

## Scope

This service should own auth, permissions, payments, messaging, moderation, account deletion, and data writes once those features are implemented. AI services can interpret and propose actions, but this backend validates what is allowed.
