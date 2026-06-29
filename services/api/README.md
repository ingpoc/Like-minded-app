# API Service

Node HTTP backend for the Likeminded TestFlight MVP placement loop.

## Current MVP Routes

- `GET /health` - service health and active storage mode.
- `POST /v1/auth/apple` - validates Sign in with Apple identity token and returns an app session token.
- `POST /v1/discover` - authenticated voice/reflection input -> profile signals -> circle placement.
- `GET /v1/me/profile` - latest signed-in user's profile.
- `PATCH /v1/me/profile` - signed-in user's profile corrections.
- `GET /v1/me/placement` - latest signed-in user's placement.
- `POST /v1/me/placement/actions` - signed-in user's `accept`, `swap`, or `defer` placement action.
- `POST /v1/feedback` - signed-in tester feedback.
- `POST /v1/realtime/session` - authenticated OpenAI Realtime client-secret broker.
- `POST /v1/realtime/calls` - authenticated OpenAI Realtime SDP broker.

Development/mock routes still exist for older prototype checks, but TestFlight code should use the authenticated `/v1/*` MVP path.

## Storage

- Production target: Neon/Postgres through `DATABASE_URL`.
- Local development and smoke grading: JSON files under `data/` or `LIKEMINDED_DB_DIR`.

## Run And Validate

```sh
npm run migrate:api
npm run dev:api
npm run check
npm run smoke:mvp
```

For voice sessions, set `OPENAI_API_KEY` on the API server. Production defaults to `gpt-realtime-2`; local cost-sensitive testing can use `npm run dev:api:realtime-test`.

`APPLE_AUTH_BYPASS=1` is only for isolated local API smoke checks. Do not enable it in TestFlight or production.

## Scope

This service owns app auth, permission checks, profile/placement writes, feedback writes, and Realtime brokering for the MVP. AI services may interpret or propose actions later, but the backend validates what is allowed.
