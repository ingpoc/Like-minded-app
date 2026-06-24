# Likeminded — Progress & Plan

> Living document. Each item ticks ✅ when complete, ⏳ when in progress, ❌ when not started.

---

## Current Status (2026-06-24)

- Voice profiling works end-to-end via WebRTC (OpenAI Realtime)
- Server runs on localhost:8787, serves profile matching and circle placement
- iOS app has 3-tab prototype (Place / Talk / Connect)
- 5 archetype circles seeded, keyword-based personality extraction works
- GitHub repo live at https://github.com/ingpoc/Like-minded-app
- **SQLite persistence active** — profiles, circles, placements, transcripts survive restarts
- **No auth** — no user identity
- **No database** — ~~all data ephemeral~~ → SQLite now persistent

---

## Phase 1 — Foundation

- [x] ✅ Add SQLite persistence (profiles, circles, placements, transcripts)
- [ ] ❌ Add device auth (anonymous UUID, then Sign in with Apple)
- [ ] ❌ Wire voice transcript auto-submission: when voice session ends, POST transcript to `/v1/discover`, store result
- [ ] ❌ Build profile review/edit screen so user can see and correct AI signals
- [ ] ❌ Store OpenAI API key in .env, load via dotenv (currently hardcoded in RealtimeVoiceClient)

## Phase 2 — Core Loop (Talk → Profile → Circles)

- [ ] ❌ Fix nav to match DESIGN.md: Talk / Circles / Communities (remove Place and Connect as separate tabs)
- [ ] ❌ Connect profile data to circle matching end-to-end (currently resets on server restart)
- [ ] ❌ Add profile update on follow-up voice conversations (profile should be "living")
- [ ] ❌ Show circle members and placement status in Circles tab
- [ ] ❌ Add "My Profile" section accessible from Talk or account controls

## Phase 3 — Social Layer

- [ ] ❌ Build chat infrastructure (message model, send/receive, presence)
- [ ] ❌ Build community engine (interest-based, broader than circles)
- [ ] ❌ Add in-app meeting concept with basic transcript capture
- [ ] ❌ Build host evaluation signals from meeting behavior
- [ ] ❌ Community join/browse UI in Communities tab

## Phase 4 — Production

- [ ] ❌ Safety and moderation layer
- [ ] ❌ Subscription and entitlement system
- [ ] ❌ Push notifications
- [ ] ❌ Production deployment (not localhost)
- [ ] ❌ Real personality inference via reasoning model (replace keyword extraction)

---

## What's Built & Working

### Backend (Node.js, port 8787)
- [x] Health endpoint (`/health`)
- [x] Architecture and personality dimensions metadata
- [x] OpenAI Realtime session broker (`/v1/realtime/session`)
- [x] WebRTC SDP exchange (`/v1/realtime/calls`)
- [x] Keyword-based personality extraction (Big Five, attachment, trust, communication, humor, conflict)
- [x] Circle matching engine against 5 archetype circles
- [x] Profile creation from interview transcript
- [x] Placement engine (auto-create circle or match archetype)
- [x] Accept / swap / defer placement actions
- [x] Circle swap and deferred circle suggestions
- [x] Design system tokens (colors, typography, spacing)
- [x] SQLite persistence (profiles, circles, placements, transcripts) via better-sqlite3

### iOS App (SwiftUI)
- [x] App entry point and root navigation
- [x] 3-tab structure (Place / Talk / Connect)
- [x] Voice profile hero with WebRTC connection
- [x] Live connection status and transcript display
- [x] Profile signal cards (communication, emotional rhythm, trust)
- [x] Placement card with primary circle, fit reasons, acceptance
- [x] Connections view with circles and people modes
- [x] Person fit cards with compatibility percentage
- [x] Circle selector with secondary options
- [x] Basic animations and entrance transitions
- [x] Design system components (FeatureCard, PrimaryActionButton, etc.)

### Design & Docs
- [x] Product direction document
- [x] Design direction document (DESIGN.md)
- [x] Architecture metadata
- [x] Personality framework (Big Five, attachment, trust, communication, humor, conflict)
- [x] Circle archetype definitions with personality profiles
- [x] GitHub repo created and code pushed

---

## Product Direction

North Star: AI voice conversation builds personality profile → AI creates and suggests circles → AI suggests communities → AI encourages interaction → AI learns from feedback.

Target loop: Talk → Profile → Circles → Communities → Hosted Interaction

Key principles:
- Profile must be built through active voice conversation, not written forms
- Circles are personality-fit (selective, like "the right room")
- Communities are interest-based (broader, easier entry)
- Meetings happen inside the app first (AI learns from transcripts)
- Hosts are AI-evaluated, not just volunteers
- User controls commitment, sharing, and attendance

---

## Open Questions

1. Database: SQLite for local dev, Postgres for production?
2. Auth: Sign in with Apple only, or also email/phone?
3. Voice interview design: how many turns, what should the AI ask?
4. Multi-user: when do we need real server deployment vs single-user prototype?
5. OpenAI Realtime model: keep gpt-realtime-2 or switch to gpt-4o-realtime-preview?
