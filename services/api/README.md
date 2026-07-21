# API Service

Node HTTP backend for the Likeminded TestFlight MVP placement loop.

## Current MVP Routes

- `GET /health` - service health and active storage mode.
- `POST /v1/auth/apple` - validates Sign in with Apple identity token (audience, signature, optional nonce) and returns an app session token.
- `POST /v1/auth/google` - validates Google ID token and returns an app session token.
- `POST /v1/auth/wallet/challenge` - creates a short-lived sign-in message for MetaMask (Ethereum) or Solflare (Solana).
- `GET /v1/auth/wallet/sign` - WalletConnect signing page used by native clients through `ASWebAuthenticationSession`.
- `POST /v1/auth/wallet/verify` - verifies wallet signature and returns an app session token.
- `POST /v1/discover` - authenticated voice/reflection input -> profile signals -> circle placement.
- `POST /v1/profile-interview/turn` - authenticated multi-turn typed AI interviewer; returns one follow-up and completion readiness.
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

For voice sessions, set `OPENAI_API_KEY` on the API server. Production defaults to `gpt-realtime-2`; local cost-sensitive testing uses `gpt-realtime-mini` via `npm run dev:api:realtime-test`.

iOS and macOS request a fully configured ephemeral client secret from `POST /v1/realtime/session`, then exchange SDP directly with OpenAI. The permanent API key and private placement prompt remain server-owned. macOS also offers the typed `/v1/profile-interview/turn` path; both input modes persist through the same profile-placement contracts.

`APPLE_AUTH_BYPASS=1` is only for isolated local API smoke checks. Do not enable it in TestFlight or production.

Production should set `APPLE_CLIENT_IDS=com.gurusharan.likeminded`, keep `APPLE_AUTH_BYPASS=0`, and enable `APPLE_REQUIRE_NONCE=1` so clients must send the raw nonce used during Sign in with Apple.

## Scope

This service owns app auth, permission checks, profile/placement writes, feedback writes, and Realtime brokering for the MVP. AI services may interpret or propose actions later, but the backend validates what is allowed.
