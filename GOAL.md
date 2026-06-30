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

Gurusharan is the first operator and tester. The current MVP target is up to 50 invited TestFlight users proving the placement loop before chat, meetings, subscriptions, or a full community engine.

## Tech Stack

- **Frontend:** SwiftUI (iOS/macOS)
- **Backend:** Node.js HTTP service
- **AI:** OpenAI Realtime API (gpt-realtime-2) via WebRTC
- **Production target:** Render web service + Neon/Postgres
- **Design:** Warm cream canvas, deep green accents, SF native typography
- **Repo:** https://github.com/ingpoc/Like-minded-app

## Current State
As of 2026-06-29:
- Local MVP backend contract passes through `npm run smoke:mvp`
- Server has authenticated Apple-session MVP routes for discovery, profile resume/update, placement resume/actions, feedback, and Realtime broker calls
- iOS app is auth-gated and uses MVP tabs: Talk, Circles, Profile
- Local development persistence uses JSON files; production persistence target is Neon/Postgres through `DATABASE_URL`
- Device UUID remains local continuity metadata; Sign in with Apple is the primary TestFlight identity path
- No chat, meetings, subscriptions, push notifications, full community engine, or advanced moderation yet

## What Needs to Happen

See **PROGRESS.md** for the full roadmap with checkboxes. Summary:

1. **Phase 0 — Session control:** `goal.template.json`, `goal.json`, deterministic graders, validation routing
2. **Phase 1 — Local MVP loop:** auth-gated Talk → Profile → Circles loop, profile edit, placement actions, feedback
3. **Phase 2 — Deterministic validation:** backend smoke, release config, goal contract, docs lint, simulator build/launch
4. **Phase 3 — External TestFlight readiness:** Render, Neon, Apple Developer, App Store Connect, TestFlight metadata
5. **Phase 4 — Device proof:** real sign-in, voice, placement, profile edit, placement action, feedback, relaunch restore

## Open Questions

- Keep Render + Neon for first TestFlight, or replace only after explicit operator decision?
- Voice interview design: what should the AI ask, how many turns?
- When should heuristic profile extraction be replaced by a reasoning model?
- What minimal account deletion path is required before wider beta?
