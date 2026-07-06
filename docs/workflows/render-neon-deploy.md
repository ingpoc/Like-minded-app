# Render free tier + Neon deploy (Phase 3)

## Neon (free tier)

1. Create a project at [Neon](https://neon.tech).
2. Copy the **pooled** Postgres connection string → `DATABASE_URL`.
3. Set `DATABASE_SSL=1`.

Local migrate once:

```sh
set -a && source .env.local && set +a
npm run migrate:api
```

## Render (free tier)

[`render.yaml`](../../render.yaml) uses `plan: free` (cold starts after ~15 min idle).

1. Connect GitHub repo in [Render Dashboard](https://dashboard.render.com).
2. Create **Blueprint** from `render.yaml` — service name should be `likeminded-api` to match the Release URL `https://likeminded-api.onrender.com`.
3. Set sync=false env vars in Render dashboard:

| Variable | Notes |
|----------|--------|
| `DATABASE_URL` | Neon connection string |
| `SESSION_SECRET` | ≥24 chars, unique |
| `OPENAI_API_KEY` | Required for voice |
| `GOOGLE_CLIENT_IDS` | After Phase 2 |
| `LIVEKIT_*` | After Phase 4 (optional) |
| `WALLETCONNECT_PROJECT_ID` | Optional |

4. Deploy and verify:

```sh
export RENDER_SERVICE_URL=https://likeminded-api.onrender.com
curl -s "$RENDER_SERVICE_URL/health"
./script/deploy_render_preflight.sh
```

## Native Release testing

Release builds default to `https://likeminded-api.onrender.com`. Warm Render before voice demos (first request may take 30–60s).
