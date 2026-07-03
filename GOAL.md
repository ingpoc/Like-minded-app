# Likeminded — Project Goal

## What This App Is

Likeminded is an AI-native iOS app that helps people who should meet actually meet, talk, and build relationships. It uses voice conversation with AI to understand people deeply, then places them into the right human context — not through feeds or swipes, but through personality-aware placement.

## The Core Loop

1. User talks with AI via voice interview
2. AI builds a living personality profile (Big Five, attachment, communication style, trust pattern, humor, conflict style, social energy)
3. AI creates and suggests personality-fit circles
4. AI suggests interest-led communities
5. AI encourages interaction through in-app hosted meetings
6. AI learns from transcripts and feedback to improve placement

## Product Principles

- **Voice first.** Profile is built through conversation, not forms.
- **Placement, not browsing.** AI suggests where you belong. You confirm.
- **Circles over feeds.** Small groups based on personality fit, not popularity.
- **Communities for interests.** Broader than circles, easier entry.
- **AI as operator.** The AI creates circles, suggests hosts, evaluates fit, and encourages interaction. It doesn't just recommend — it acts.
- **User controls commitment.** AI proposes, user confirms sharing, attendance, and placement.

## Target Users

Gurusharan is the first operator and tester. The current MVP target is up to 50 invited TestFlight users proving the placement loop across voice profile, circles, communities, meetings, recap, and optional Soulmate chat before subscriptions, push notifications, or a full community engine.

## Tech Stack

- **Frontend:** SwiftUI (iOS/macOS)
- **Backend:** Node.js HTTP service
- **AI:** OpenAI Realtime API (gpt-realtime-2) via WebRTC
- **Production target:** Render web service + Neon/Postgres
- **Design:** Warm cream canvas, deep green accents, SF native typography
- **Repo:** https://github.com/ingpoc/Like-minded-app

## Current State
As of 2026-07-03:
- Local MVP backend contract passes through `npm run smoke:mvp`, seeded validation data, and native screen validators
- Server has authenticated Apple-session MVP routes for discovery, profile resume/update, placement resume/actions, feedback, account deletion, Realtime broker calls, notifications, communities, meetings, recap notes, and Soulmate chat
- iOS app is auth-gated and uses product tabs: Meet, Circles, Communities, Profile, plus Soulmate when enabled
- macOS has native screens for the same product areas, with remaining parity gaps tracked in `PROGRESS.md`
- Local development persistence uses JSON files and validation DB data; production persistence target is Neon/Postgres through `DATABASE_URL`
- Device UUID remains local continuity metadata; Sign in with Apple is the primary TestFlight identity path
- Not yet production-ready: external Render/Neon/LiveKit setup, signed TestFlight proof, macOS video-call parity, push notifications, subscriptions, full community engine, and advanced moderation

## What Needs to Happen

See **PROGRESS.md** for the full roadmap with checkboxes. Summary:

1. **Phase 0 — Session control:** `goal.template.json`, `goal.json`, deterministic graders, validation routing
2. **Phases 1-8 — Local product loop and native parity:** auth, voice profile, Meet, Circles, Communities, Profile, Soulmate, seeded backend data, and runtime-tapped iOS/macOS screens
3. **Phase 9 — External TestFlight readiness:** Render, Neon, LiveKit, Apple Developer, App Store Connect, privacy metadata, account deletion readiness, signed candidate
4. **Phase 10 — Simulator/device proof:** real sign-in, voice, placement, group video, chat, privacy isolation, and native parity proof

## Open Questions

- Keep Render + Neon for first TestFlight, or replace only after explicit operator decision?
- Voice interview design: what should the AI ask, how many turns?
- When should heuristic profile extraction be replaced by a reasoning model?
