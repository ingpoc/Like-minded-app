# Product Redesign — Work Backwards From The Goal

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This document owns pre-TestFlight product redesign decisions.

## The Goal

People who should meet actually meet, talk, and build relationships.

## The Problem

Most people sign up and don't use it. They won't ice-break, select a host, schedule a meetup, or organize a circle. That's the AI's job. If the user has to do organizational work, the app is dead.

## Working Backwards

```
Goal: people meet
  ↑
Scheduled meetup they attend
  ↑
They RSVP'd "available this weekend"
  ↑
AI scheduled it, formed the group (10 people, 5M/5F), picked a host
  ↑
AI placed them in a circle (personality) and/or community (interest)
  ↑
Voice interview built a deep profile (personality + interests with depth)
  ↑
User signed up and was guided into a voice interview
```

## The User Does Two Things

1. Voice interview (builds deep profile — personality + interests + depth of interest)
2. RSVP "I'm available this weekend" (one tap)

Everything else is AI:
- Places you in a circle based on personality
- Suggests communities based on interests
- Asks you to RSVP
- Forms the group (10 people, gender-balanced)
- Picks the host
- Schedules the meetup
- Transcribes the meetup
- Learns and improves

---

## Circles vs Communities — The Core Contrast

| | Circle | Community |
|---|--------|-----------|
| Basis | Personality — how you process the world | Interest — what you're into |
| People | Same personality type, different interests | Different personalities, same interest |
| Meet day | Sunday | Saturday |
| Group formation | Random from 1000+ similar-personality people | Random from everyone who RSVP'd in that community |
| Chemistry | Natural — you're in a room of people who get you | Bridging — opposite personalities around a shared passion |
| Host skill needed | Keep energy up, pull in quiet people | Bridge personality gaps, read the room when people talk past each other |
| Movement | Personality-only, triggered by user concern + re-interview | Join/leave freely, interest-based |

A circle is where you feel understood. A community is where you're surprised.

---

## Weekly Rhythm

Saturday: community meet (interest-based, cross-personality)
Sunday: circle meet (personality-based, natural fit)

Two touchpoints per week. Builds habit without daily engagement pressure. People don't need to open the app daily — they need to show up twice a week.

---

## Profile Layers

Two layers. One visible to the user, one not.

### Visible layer (user can see and edit)

What shows in the Profile tab:
- Basic info: name, gender, date of birth, city, pincode (set during onboarding, editable)
- Personality signals: Big Five, communication style, social energy, trust, attachment, humor, conflict
- Interests with depth: what they're into and how deep
- Editable summary: model-generated reflection, strengths

### Hidden layer (placement-only, not shown to user)

Signals the AI observes during the interview that the user cannot self-report accurately. These feed circle placement and host selection but never appear in the user's profile view:

| Signal | Why it's hidden | How AI captures it |
|--------|----------------|-------------------|
| Shyness | People don't self-report shyness accurately | Pauses, short answers, hesitation patterns |
| Language comfort | Which language the person thinks and speaks in most naturally | Language switching, vocabulary depth, ease of expression |
| Conversational warmth | Self-assessment of warmth is unreliable | Tone, follow-up questions, emotional engagement |
| Vulnerability openness | Can't ask "are you open?" directly | Depth of personal sharing, willingness to go beyond surface |
| Dominance tendency | People underreport dominance | Talk-over patterns, topic control, interruption frequency |
| Energy trajectory | Does energy rise or fall over the conversation | Response length and enthusiasm over time |

These are observational — the AI picks them up from HOW the person talks, not WHAT they say about themselves. They make placement more honest.

---

## Onboarding Flow (pre-interview)

Before the voice interview starts, capture basic factual info through a simple form. No personality questions, no interests — just facts that don't need conversation.

**Onboarding form fields:**
- Name (first name minimum)
- Gender: Male / Female / Non-binary / Prefer not to say
- Date of birth
- City
- Area pincode

This takes 30 seconds. Then the voice interview starts immediately — no dead ends, no "what do I do next."

**Why before interview:** Name, gender, DOB, city, pincode are facts. Wasting voice interview time asking "what's your name?" is pointless. The interview is for personality and interests — things that need conversation to discover honestly.

**Gender** is needed for 5M/5F group formation. **City/pincode** enables future location-aware meetup coordination (MVP doesn't use it, but capturing it now is free). **DOB** enables age-aware placement later.

---

## The Voice Interview — Deep Profile Building

The interview is the foundation. It must build a deep, honest profile before any placement happens.

### What the AI extracts

**Personality signals (visible — existing):**
- Big Five (openness, conscientiousness, extraversion, agreeableness, neuroticism)
- Attachment style
- Social energy
- Communication style (primary + pace)
- Trust pattern
- Humor style
- Conflict style

**Interests (visible — new, with depth detection):**
The AI doesn't just ask "what movies do you like?" — it first discovers whether the person is even into movies. Not a checklist; a conversation that finds what actually matters to them.

| Interest area | Discovery question | Depth probe | Depth signal |
|---------------|-------------------|-------------|--------------|
| Movies | "What's the last film that really stayed with you?" | If vague/short → casual viewer. If specific + emotional → deep. | "watched one film last month" vs "rewatched Tarkovsky twice" |
| Music | "What do you play when you need to feel something?" | If "whatever's on" → background listener. If specific artist/genre + why → deep. | "doesn't actively listen" vs "knows Coltrane's discography" |
| Books | "What's a book you keep coming back to?" | If "don't read much" → casual. If specific + why it mattered → deep. | "reads occasionally" vs "devours essays" |
| Food/cooking | "What does a good meal mean to you?" | If "just eat" → functional. If ritual/craft → deep. | "eats to live" vs "cooks as meditation" |
| Outdoors | "When was the last time you felt outdoors?" | If "rarely" → indoor. If specific trip + feeling → deep. | "prefers inside" vs "treks every weekend" |
| Tech/building | "What's the last thing you built or fixed?" | If "nothing" → casual. If specific project + why → deep. | "uses tools" vs "builds for joy" |
| Art/design | "What's something beautiful that you noticed recently?" | If "nothing" → low. If specific observation → deep. | "doesn't notice" vs "sees design everywhere" |

The AI should ask naturally, not through this table. It follows the conversation — if someone lights up about music, go deeper. If they say "I don't really watch movies," move on. The depth matters as much as the interest itself.

**Hidden placement signals (not shown to user — new):**
- Shyness (pause patterns, answer length, hesitation)
- Language comfort (which language they think/speak in most naturally)
- Conversational warmth (tone, follow-up questions, emotional engagement)
- Vulnerability openness (depth of personal sharing)
- Dominance tendency (talk-over, topic control, interruption)
- Energy trajectory (does energy rise or fall over the conversation)

These are observational — captured from HOW the person talks, not what they say about themselves. They feed circle placement and host selection but never appear in the user's profile view.

### Interview instructions (Realtime)

The system prompt for the Realtime session must be updated to:
1. Conduct a warm, open-ended personality discovery conversation (existing)
2. Discover interests naturally — ask what they do, what excites them, what they lose track of time doing
3. Detect depth of each interest — not just what, but how much it matters to them
4. Observe hidden placement signals — shyness, language comfort, warmth, vulnerability, dominance, energy trajectory
5. Submit profile with visible signals (personality + interests with depth) AND hidden placement signals
6. Wait patiently, never interrupt

---

## Tab Structure

Five tabs. Each has one job. Soulmate appears in the nav bar only if the user enables it in settings.

### Profile — "Who you are"

Build and view your living personality profile through voice.

**Structure:**
1. Basic info — name, gender, DOB, city, pincode (set during onboarding, editable here)
2. Voice interview hero — start/stop, realtime status
3. Signal read — Big Five gauges, communication style, social energy, trust, attachment, humor, conflict
4. Interests read — what you're into, with depth (casual / active / deep)
5. Editable summary — model-generated reflection, strengths, editable + save
6. Privacy strip + account controls + tester feedback

**Empty state:** basic info form only. Fill it → voice interview starts immediately.

**After profile:** voice hero shrinks to "Update profile" button. Signal read + interests + summary become primary.

**Re-interview (concern-triggered):** If user raises a circle concern (see Circles tab), Profile tab surfaces a "Let's re-evaluate your placement" prompt. Re-interview appends new signals to the existing profile, doesn't wipe it. AI re-evaluates placement after re-interview completes.

### Circles — "Who you're placed with"

See your circle, who's in it, and why you fit.

**Structure:**
1. Your circle (if placed) — name, room energy, members count, themes, next Sunday meetup (if scheduled)
2. Placement proposal (if unaccepted) — proposed circle, fit reasons, accept/swap/defer
3. Available circles (the 5 archetypes) — browse with fit score, "Request to join"
4. **Concern button** — "This doesn't feel like my circle" → triggers re-interview flow in Profile

**Circle detail:** members count (not individual profiles — surprise is part of the meet), room energy, meeting format, themes, fit breakdown (why your personality fits), upcoming Sunday meetup, leave circle.

**Concern flow:**
```
User taps "This doesn't feel like my circle"
  ↓
"Tell me what's off" (one-line text or voice)
  ↓
AI schedules a re-interview (appears in Profile tab)
  ↓
Re-interview appends to existing profile
  ↓
AI re-evaluates placement — may move to different circle or confirm current
  ↓
User sees new placement proposal with explanation
```

Circle movement is personality-only. Never triggered by meeting someone from another circle in a community meet. Communities are interest-based side doors, not circle reassignment paths.

### Meet — "When you meet"

RSVP for the weekend, see upcoming meets, join, review past.

**Structure:**
1. RSVP card — "Available this weekend?" Yes/No. Two lines below:
   - Saturday: community meet (if in a community)
   - Sunday: circle meet (if in a circle)
   - Toggle each independently (can do both, one, or neither)
2. Pre-meet teaser (Friday) — group composition preview
3. Upcoming meets — cards with day (Sat/Sun), circle/community name, time, host, group size, join button
4. Join — at meet time, opens in-app group video call (LiveKit, camera on — no voice-only, 10 participants)
5. Past meets — meetup history with date, group, host
6. Post-meet: Soulmate selection dialog (if enabled)

**RSVP flow:**
```
User taps "Available this weekend" → picks Saturday and/or Sunday
  ↓
AI collects RSVPs through Friday midnight
  ↓
Saturday 12am: AI forms community groups from RSVP'd members
  ↓
Sunday 12am: AI forms circle groups from RSVP'd members
  (same logic — random partition into groups of 10, 5M/5F)
  ↓
AI picks host per group (different scoring for circle vs community)
  ↓
AI schedules: Saturday 7pm (community), Sunday 7pm (circle), user-local time
  ↓
Friday: pre-meet teaser appears
  ↓
At 7pm: Join button activates → Realtime voice session
  ↓
After: AI posts transcript summary + connection prompts
```

### Pre-meet teaser (Friday)

Before showing up, users see group composition:
- Circle: "Your Sunday meet: 5 people. You all share slow-trust patterns and analytical communication. Host: Priya."
- Community: "Your Saturday jazz meet: 5 people from 4 different circles. Two are extroverts, three are introverts. Host: Marco."

Reduces no-shows, builds anticipation. No individual profiles — just group-level composition.

### Post-meet: Soulmate prompt

After every meetup (circle or community), if the user has Soulmate enabled, a dialog appears: "Did you connect with someone?" The user sees names of opposite-sex group members who also have Soulmate enabled. They tap who they connected with (can select none, one, or multiple). If two people select each other → match shows up in the Soulmate tab. If only one selects the other → nothing happens. Silent.

No AI transcript analysis. User-driven selection only. See Soulmate tab for full feature.

### Communities — "What you're into"

Interest-based, cross-personality. Lower stakes than circles.

**Pre-seeded (8):**
- AI Builders, Longform Reading, Design & Craft, Startups & Entrepreneurship, Mindful Living, Creative Writing, Jazz & Music, Trekking & Outdoors

**Structure:**
1. Your communities (if joined) — compact cards with next Saturday meetup (if scheduled)
2. Community catalog — backend-driven, not Swift constants. Cards: name, summary, themes, members count, join button. Fit label if profile interests match.
3. Community detail — full description, themes, members count, upcoming Saturday meetup, leave community.

**Community meetups happen on Saturday.** Same group formation logic as circles — random partition of RSVP'd community members into groups of 10 (5M/5F). But the people come from different circles — opposite personalities around a shared interest.

### Soulmate — "Who you connected with" (opt-in)

Not a dating tab. Not a swipe deck. It's where mutual connections land when both people felt it during a meetup.

**Enable:** Off by default. User enables in Settings. When off, tab is invisible in nav bar and no post-meet prompts appear. When on, tab appears and post-meet selection dialogs become active.

**How a match happens:**
1. After a meetup (circle or community), dialog appears: "Did you connect with someone?"
2. User sees names of opposite-sex group members who also have Soulmate enabled
3. User taps who they connected with (none, one, or multiple)
4. If two people select each other → match shows up in both people's Soulmate tab
5. If only one selects the other → nothing happens. Silent. No notification.

No AI transcript analysis. Pure user-driven selection.
**Soulmate tab structure:**
1. **Your matches** — mutual connections (both selected each other)
   - Name, which meetup you met at
   - Tap a match → see their interests, likes, dislikes (from voice interview profile) before deciding to chat
   - Chat icon on the match → opens that conversation
2. **Pending prompts** — post-meet selection dialogs not yet answered
3. **Past connections** — matches from previous meetups, archived after 30 days of inactivity

**Chat access:**
- Top-right chat icon (visible when Soulmate is enabled) → list of all conversations with different matches. Pick any to resume.
- Per-match chat icon → opens that specific conversation directly.
- Chat is text-based, in-app, only between matched soulmates.

**Before chat:** Both people can see each other's interests, likes, and dislikes (extracted during voice interview). This gives context before starting a conversation — you know what they're into and how deep before you say hi.

**What Soulmate is NOT:**
- Not swiping on faces
- Not a dating profile with photos
- Not a chat inbox
- Not based on proximity or looks

**Gender:** Opposite sex only for MVP. Same-sex is a later product decision.

---

## AI-Driven Logic (Backend)

### Host Selection — Circle (Sunday)

Score every member's profile for circle-host suitability:

| Signal | Weight | Why |
|--------|--------|-----|
| socialEnergy = high/medium | + | Bubbly, brings energy |
| communicationStyle = warm/expressive | + | Inclusive, breaks ice |
| agreeableness high | + | Makes people comfortable |
| extraversion high | + | Engages quiet people |
| neuroticism low-mid | + | Steady under group dynamics |
| dominance low (low direct + low engaging conflict) | + | Doesn't dominate |
| trustPattern = fastTrust | + | Opens up quickly, sets tone |

### Host Selection — Community (Saturday)

Community hosts need a different skill: bridging personality gaps. The room has opposite personalities talking about a shared interest. The host must read when people are talking past each other and pull people in.

| Signal | Weight | Why |
|--------|--------|-----|
| openness high | + | Curious about different personalities |
| agreeableness high | + | Bridges tension, makes space |
| extraversion medium-high | + | Engages but doesn't dominate |
| communicationStyle = warm | + | Translates between direct and indirect communicators |
| neuroticism low | + | Steady when personalities clash |
| socialEnergy = high/medium | + | Sustains energy across personality gaps |
| dominance low | + | Doesn't impose their personality on the room |

Score is computed per-group after random partitioning. Highest score in the group = host. If tied, pick the person with more meetups attended (reliability).

### Group Formation

A circle or community can have 1000+ people. Among RSVP'd people, AI creates random groups of 10 (5M/5F). Naturally many meets happen within the same circle/community.

1. Pull all RSVP'd members in the circle (Sunday) or community (Saturday) for the weekend
2. Shuffle randomly
3. Partition into groups of 10, gender-balanced (5M/5F)
4. If odd RSVP count, last group is smaller (min 6)
5. Score host within each group
6. Assign host = highest host-score in that group
7. Each group gets its own meeting record, own Realtime session, own time slot

### Scheduling

- Saturday 7pm user-local: community meets
- Sunday 7pm user-local: circle meets
- MVP: fixed weekend evening slots. No negotiation, no Doodle polls.
- AI picks the slot. User just shows up.

### Transcript Learning

Not for MVP. No AI transcript analysis. No group dynamics extraction. Meetups are just voice calls — people show up, talk, leave.

Skipped: AI transcript analysis, host performance review, profile signal updates from observed behavior.

### Circle Re-placement

Triggered only by user concern, never automatic:
1. User raises concern in Circles tab
2. Re-interview scheduled in Profile tab
3. Re-interview appends to existing profile
4. AI re-scores personality against all circle archetypes
5. If better fit found → new placement proposal with explanation
6. If no better fit → confirm current placement with deeper explanation of why

---

## Backend Changes

### New: Meetings + RSVP

```
POST /v1/meetings/rsvp          — user RSVPs available for weekend (specify Sat, Sun, or both)
GET  /v1/meetings/upcoming      — user's upcoming meets (circle + community)
GET  /v1/meetings/:id           — meet detail (group, host, time, join info)
POST /v1/meetings/:id/join      — get Realtime session for the meet
GET  /v1/meetings/past          — past meets with transcript summaries
```

### New: AI Scheduling (server-side job)

```
Friday midnight: RSVP window closes
Saturday 12am: form community groups from Saturday RSVPs, score hosts, create meeting records
Sunday 12am: form circle groups from Sunday RSVPs, score hosts, create meeting records
```

### New: Communities

```
COMMUNITY_ARCHETYPES (8 communities, seeded like circles)
GET  /v1/communities            — list all
GET  /v1/communities/:id        — detail
POST /v1/communities/:id/join   — join
POST /v1/communities/:id/leave  — leave
GET  /v1/me/communities         — user's joined communities
```

### New: Circle membership + concern

```
GET  /v1/me/circles             — circles user belongs to
GET  /v1/circles/:id            — detail with members count + fit breakdown
POST /v1/me/circles/concern     — raise placement concern, triggers re-interview
```

### New: Soulmate (connections + chat)

```
POST /v1/me/soulmate/enable       — toggle on/off (hides/shows tab)
GET  /v1/me/soulmate/status       — enabled?, any pending selections
GET  /v1/me/soulmate/matches      — mutual matches (both selected each other)
POST /v1/me/soulmate/select       — submit post-meet selections (array of user IDs)
GET  /v1/me/soulmate/prompts      — pending post-meet selection dialogs
GET  /v1/me/soulmate/matches/:id  — match detail (other person's interests/likes/dislikes)
GET  /v1/me/soulmate/matches/:id/messages — chat messages
POST /v1/me/soulmate/matches/:id/messages — send a message
GET  /v1/me/soulmate/past         — archived connections (30+ days inactive)
```

Backend logic: when both users select each other, create a match record. Chat messages stored against the match. Interest profile (from voice interview) exposed read-only to the other person via match detail.

### Modified: Profile

- Add `basicInfo`: `{ name, gender, dateOfBirth, city, pincode }` (set during onboarding, before interview)
- Add `interests` array: `[{ area: "music", label: "Jazz", depth: "deep" }]`
- Add `hiddenSignals`: `{ shyness, languageComfort, warmth, vulnerabilityOpenness, dominanceTendency, energyTrajectory }` (not returned in user-facing profile GET, used internally for placement + host scoring)
- Add `concernFlag` to track re-interview state

### Modified: Realtime instructions

Update voice interview system prompt to discover interests with depth, not just personality signals.

---

## UI/UX Design Language

Design language is owned by `DESIGN.md`. Keep this product strategy doc focused on product behavior and implementation order.

---

## What Stays The Same

- Auth gate (Sign in with Apple)
- Backend architecture (Node HTTP, Realtime broker, mvp-store)
- Realtime voice infrastructure (WebRTC + OpenAI Realtime)
- Design palette (warm cream, deep green, SF typography)
- CIRCLE_ARCHETYPES (5 existing archetypes)
- Profile signal model (Big Five + attachment + social energy + communication + trust + humor + conflict)
- Deterministic graders

## What Gets Deleted

- `PrototypeData.communities` (3 hardcoded Swift constants → backend)
- `ReflectionPrototypeView` / Talk tab (voice moves to Profile, tab becomes Meet)
- Cross-pollination concept (circle movement is personality-only, never community-driven)

---

## Implementation Order

1. **Profile tab**: move voice hero + signal read from Talk → Profile. Add gender pick. Add interests read. Delete Talk view.
2. **Circles tab**: add "your circle" + "available circles" + concern button. Backend: `GET /v1/me/circles`, `GET /v1/circles/:id`, `POST /v1/me/circles/concern`.
3. **Meet tab**: RSVP flow (Sat/Sun toggles) + upcoming meets + join. Backend: meetings model, RSVP route, AI scheduling job, group formation + host selection logic (two scoring models).
4. **Communities tab**: backend `COMMUNITY_ARCHETYPES` + `seedCommunities()` + routes. Saturday meetup flow. Delete `PrototypeData.communities`.
5. **Soulmate tab**: opt-in toggle, post-meet selection flow, matches list with interest profile view + chat. Backend: soulmate model + routes + chat message storage.
6. **Root tab restructure**: rename Talk → Meet, add Soulmate (conditional), update `AppTab` enum.
7. **Update docs**: `DESIGN.md`, `product-direction.md`, `PROGRESS.md` (Phase 2.5).

### Dependencies

- Step 1 (Profile) is independent — do first.
- Step 2 (Circles) depends on profile having gender.
- Step 3 (Meet) depends on circles + communities.
- Step 4 (Communities) is independent — can parallel with 1-2.
- Step 5 (Soulmate) depends on Meet existing (needs transcripts).
- Step 6 is a restructure, do after 1-5.
- Step 7 is docs, do last.

### Ponytail cuts for MVP

- No push notifications (users check the app)
- No Doodle-style scheduling (AI picks the slot)
- No agenda suggestions (just show up and talk)
- No host performance review (just pick based on profile)
- No offline coordination (in-app voice only)
- No full group chemistry analysis (basic talk-time + keyword extraction)
- No general chat/inbox (chat exists only inside Soulmate matches)
- No gamification/streaks (the weekly rhythm is the hook)
- No same-sex Soulmate for MVP (opposite sex only — scope decision, not technical)

---

## Open Questions

1. **RSVP window**: always open, closes Friday midnight? I propose yes.
2. **Min RSVP threshold**: min 6 per group. If 15 RSVP, one group of 10 + skip the 5? Or merge into a 15-person meet? I propose: skip groups smaller than 6.
3. **Non-binary in group formation**: exclude from gender balance, place freely? I propose: exclude from balance, place by fit only.
4. **Meetup duration**: 60 min default, Realtime session auto-closes? Or open-ended?
5. **Multiple time slots per day**: if a community has 100+ RSVPs across time zones, all groups meet at 7pm local. But within one time zone, 10 groups all meet at 7pm Saturday. Fine?
6. **Soulmate match expiry**: if both match but never chat, how long before the match archives? I propose: 30 days.
7. **Interest profile visibility**: can both soulmate matches see each other's full interest profile (all 7 areas + depth), or just the ones they share? I propose: full profile — the point is to discover who this person is.
