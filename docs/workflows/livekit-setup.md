# LiveKit Cloud setup (Phase 4)

## Control Owner

This workflow owns the repository setup and verification steps for LiveKit; deployed room infrastructure and credentials remain externally owned.

## 1. Create project

1. Sign up at [LiveKit Cloud](https://cloud.livekit.io) (free dev tier).
2. Create a project and copy:
   - WebSocket URL → `LIVEKIT_URL` (e.g. `wss://your-project.livekit.cloud`)
   - API Key → `LIVEKIT_API_KEY`
   - API Secret → `LIVEKIT_API_SECRET`

## 2. Configure API

Add to `.env.local` and Render env vars:

```sh
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your-key
LIVEKIT_API_SECRET=your-secret
```

Restart API and confirm:

```sh
curl -s http://127.0.0.1:8787/health | grep livekit
# "livekit": true
```

## 3. Test group video

1. Sign in (bypass or Google).
2. Meet tab → **Join meetup** on a scheduled meeting.
3. iOS: `GroupVideoCallView` via shared `LiveKitMeetSession`.
4. macOS: `--mac-screen meetVideoCall` or navigate from Meet.

Without LiveKit env, UI shows preview tiles (layout validation only).
