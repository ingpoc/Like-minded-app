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

Gurusharan is the first user. The app should work for a single user doing voice interviews and seeing their placement before multi-user features are needed.

## Tech Stack

- **Frontend:** SwiftUI (iOS/macOS)
- **Backend:** Node.js (Express)
- **AI:** OpenAI Realtime API (gpt-realtime-2) via WebRTC
- **Design:** Warm cream canvas, deep green accents, SF native typography
- **Repo:** https://github.com/ingpoc/Like-minded-app

## Current State
As of 2026-06-24:
- Voice profiling works end-to-end (WebRTC connects, transcript captured)
- Server has profile matching and circle placement logic
- iOS app has 3-tab prototype with voice hero, placement cards, connections view
- SQLite persistence active — profiles, circles, placements, transcripts survive restarts
- No auth, no chat, no communities, no meetings

## What Needs to Happen

See **PROGRESS.md** for the full roadmap with checkboxes. Summary:

1. **Phase 1 — Foundation:** ~~SQLite persistence~~ ✅ done, device auth, wire profile pipeline, profile review UI
2. **Phase 2 — Core Loop:** Fix nav, end-to-end profile → circle flow, living profile updates
3. **Phase 3 — Social Layer:** Chat, communities, meetings, host evaluation
4. **Phase 4 — Production:** Safety/moderation, subscriptions, notifications, deployment, AI-powered reasoning

## How to Pick Up This Project

1. Read this file for vision and context
2. Read PROGRESS.md for current state and what's next
3. Check the server is running: `curl -s http://127.0.0.1:8787/health`
4. Check git log for recent work: `git log --oneline -10`
5. Start with the first unchecked item in PROGRESS.md Phase 1

## Open Questions

- Database: SQLite (local dev) → Postgres (production)?
- Auth: Sign in with Apple, or also email/phone?
- Voice interview design: what should the AI ask, how many turns?
- Multi-user: when to move off localhost?
- Model: keep gpt-realtime-2 or switch?
