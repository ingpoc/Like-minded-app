# Likeminded — MVP Progress

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This file tracks repo progress and roadmap state only.

## Current Status

- Product redesign complete; product behavior lives in `docs/product-direction.md` and design language lives in `DESIGN.md`.
- Phases 0-2 complete (auth, MVP loop, deterministic validation).
- Phases 3-8 (numbered) are complete as phase checklists; open control work remains under the macOS and iOS ledger tracks below. Phase 9 is the next numbered release route only after those tracks are clean — do not start external Neon/Render/Apple setup while ledger owners are open or dirty (see root `README.md` Active route).
- Existing auth, backend, Realtime voice, and mvp-store infrastructure stays.
- Design system stays: warm cream canvas, deep green accent, SF typography.
- Design language owner: `DESIGN.md`. Visual references: `mockups/ios/` and `mockups/macos/`.
- **Track — macOS Visual Parity + Ledger Closeout** is the active local route while ledger/doodle/visual owners are open or dirty. First command: `./script/macos_audit_prepare.sh`; control-status owner is `validation/macos/*.json` only (no sibling `.md` ledgers). Track owner doc: `docs/references/macos-screen-audit.md` (routing + evidence pointers, not a second status table).
- **Track — iOS Ledger Honesty** owns open `validation/ios/*.json` fail/pending rows (Phase 8 manual-proof checkboxes are historical, not ledger-green).
- Ledger ↔ PROGRESS gate: `npm run verify:ledger-progress` (also via `npm run verify:goal`); `npm run goal:next` prints `ledger_*` ownership lines. Do not check off tracks while actionable open controls lack unchecked owners.
- Phase 9 External TestFlight Readiness is the next numbered release route after this track's session work is committed. First command when focusing Phase 9 only: `npm run phase:preflight -- 9`.

## Phase 0 — Session Control And Graders

- [x] Create `goal.template.json` as the per-session goal template.
- [x] Create current `goal.json` for the TestFlight MVP placement loop.
- [x] Add `npm run verify:goal`.
- [x] Pin delegated validation to `validation-release` using `gpt-5.4-mini` at `medium` effort.
- [x] Document what delegated verification can and cannot do.
- [x] Require a validated session commit including `goal.json` before marking a goal complete.
- [x] Remove stale generated artifacts from status and ignore future `__pycache__`, `*.pyc`, `*.egg-info`, `node_modules`, and stray `codex.js`.

## Phase 1 — Local MVP Loop (completed, superseded by redesign)

- [x] Add Sign in with Apple gate in SwiftUI.
- [x] Store app session token in Keychain.
- [x] Protect `/v1/discover`, `/v1/me/profile`, `/v1/me/placement`, `/v1/me/placement/actions`, `/v1/feedback`, and Realtime broker routes with bearer auth.
- [x] Persist profile, placement, transcript, and feedback through the MVP store.
- [x] Add placement actions: accept, defer, swap.
- [x] Add profile review/edit and tester feedback UI.
- [x] Replace prototype tabs with `Talk`, `Circles`, `Profile`.
- [x] Remove hardcoded localhost from the Realtime SDP path.

## Phase 2 — Deterministic Validation (completed)

- [x] `npm run check` — syntax checks API, orchestrator, and grader scripts.
- [x] `npm run smoke:mvp` — validates local authenticated placement loop and cross-user isolation.
- [x] `npm run verify:release-config` — validates bundle id, entitlements, Render env placeholders, API base URL, and privacy policy draft.
- [x] `npm run verify:goal` — validates goal contract, graders, rubric, and agent routing.
- [x] `workflow --docs-dir ... lint` — passes with warnings only.
- [x] `./script/build_and_run.sh --verify` — builds, installs, and launches simulator app as `com.likeminded.app`.

## Phase 3 — Profile + Onboarding + Interview

Foundation: voice interview moves from Talk to Profile. Onboarding form captures basic facts before interview. Profile becomes the personality + interests surface.

### Onboarding

- [x] Create `OnboardingView.swift` — single-field-per-screen wizard using `TabView(.page(indexDisplayMode: .never))` with programmatic step transitions. 5 steps: name (TextField), gender (3 tappable cards: Male/Female/Non-binary), DOB (DatePicker .wheel in RoundedRectangle container), city (TextField), pincode (numeric TextField). Progress dots (`HStack` of `Capsule` shapes) at top. Spring transition between steps: `.spring(response: 0.38, dampingFraction: 0.82)`.
- [x] After last onboarding step, automatically present the voice interview hero — no review screen, no dead end.
- [x] Profile empty state (no profile in backend): show `OnboardingView` inline in Profile tab. Once `basicInfo` is saved, show the voice interview hero.

### Profile model (Swift + backend)

- [x] Swift: Add `BasicInfo` struct to `PrototypeModels.swift` — `name: String`, `gender: Gender`, `dateOfBirth: String`, `city: String`, `pincode: String`. Add `enum Gender: String, Codable { case male, female, nonBinary, preferNotToSay }`. Add `basicInfo: BasicInfo?` to `SynthesizedProfile`.
- [x] Swift: Add `Interest` struct — `area: String`, `label: String`, `depth: InterestDepth`. Add `enum InterestDepth: String, Codable { case casual, active, deep }`. Add `interests: [Interest]` to `SynthesizedProfile`.
- [x] Swift: Add `HiddenSignals` struct — `shyness: Double?`, `languageComfort: String?`, `warmth: Double?`, `vulnerabilityOpenness: Double?`, `dominanceTendency: Double?`, `energyTrajectory: String?`. Add `hiddenSignals: HiddenSignals?` to `ReflectPlaceConnectSlice` (not to `SynthesizedProfile` — it's not user-facing).
- [x] Swift: Add `concernFlag: Bool` to `PrototypeAppState`.
- [x] Backend: Add `basicInfo`, `interests`, `hiddenSignals` to profile object in `mvp-store.js` `saveProfilePlacement` + `getLatestProfile` + `updateLatestProfile`.
- [x] Backend: `GET /v1/me/profile` must strip `hiddenSignals` from the response. `GET /v1/me/placement` must strip `hiddenSignals`. Internal placement functions (`buildPlacement`, `matchCircles`) use the full object.

### Profile UI

- [x] Create `VoiceOrbView.swift` — `Circle` filled with `RadialGradient` (accent green center → transparent edge). Size bound to audio amplitude via `.frame(width: 80 + amplitude * 40)`. 4 states: idle (gentle `PhaseAnimator` pulse), listening (orb expands with amplitude, thin audio level bar below), processing (orb contracts, spinner overlay), captured (checkmark overlay, fades to rest). Cross-fade between states with `.animation(.easeInOut(duration: 0.25))`. Replace existing `voiceHero` in `ReflectionPrototypeView`.
- [x] Move voice hero + signal read from `ReflectionPrototypeView` into `ProfilePrototypeView`. Keep `RealtimeVoiceClient` and all voice logic in `PrototypeAppState` — no changes to voice session lifecycle.
- [x] Replace `BigFiveGauge` with `TraitBar` — `ZStack` of `Capsule` track (`.quaternary`) + `Capsule` fill (`LinearGradient` from `.accent` to `.accent.opacity(0.4)`, width = `value * maxWidth`). Left label (e.g. "Reserved") and right label (e.g. "Outgoing") in `.caption2` below. No percentage numbers. Big Five = 5 `TraitBar`s stacked.
- [x] Add `InterestTagChip` — `TagView` variant with depth encoding: deep = filled accent background + white text, active = accent border + accent text, casual = muted background + subink text. Show in Profile below signal read.
- [x] Profile after profile exists: voice hero shrinks to a compact "Update profile" `Button` (height ~52). Signal read + interests + summary become the primary scroll content.
- [x] Re-interview prompt: when `concernFlag == true`, show a `FeatureCard` at top of Profile: "Let's re-evaluate your placement" with a "Start re-interview" `PrimaryActionButton`. Tapping it starts a new voice session. Re-interview appends signals (does not wipe existing profile). After voice session ends and placement re-evaluated, clear `concernFlag`.

### Realtime interview instructions

- [x] Update the `instructions` string in `server.js` `/v1/realtime/calls` route. Current instructions focus on personality signals only. New instructions must also: (1) discover interests naturally across 7 areas (movies, music, books, food/cooking, outdoors, tech/building, art/design) — ask open questions, follow the conversation, detect depth (casual/active/deep) based on specificity and emotional engagement, (2) observe hidden placement signals from HOW the user speaks (shyness from pause patterns, language comfort from language switching, warmth from follow-up questions, vulnerability from depth of sharing, dominance from interruption/talk-over, energy trajectory from response length over time), (3) submit all of this via the `submit_profile_placement` tool.
- [x] Update `submit_profile_placement` tool schema in `server.js` — add `interests: Array<{ area: String, label: String, depth: String }>` and `hiddenSignals: Object` to the `properties` and `required` arrays.
- [x] Update `model-placement.js` `normalizeSignals` to also normalize `interests` (validate depth enum, cap at 10 items) and `hiddenSignals` (clamp doubles 0-1, pass strings through). Add both to the profile object in `profilePlacementFromModelResult`.
- [x] Update `/v1/discover` route in `server.js` — pass `interests` and `hiddenSignals` from the model result through to `saveProfilePlacement`.
- [x] Update `/v1/realtime/profile-placement` route — same: persist `interests` and `hiddenSignals` from the tool call body.

### Cleanup

- [x] Delete `ReflectionPrototypeView` (Talk view) from `MVPProfileView.swift`. Move the `voiceHero`, `profileSignals`, `voiceSignalCapture`, `voiceTitle`, `statusIcon`, `voiceButtonTitle`, `voiceButtonIcon`, `signalValue`, `signalDetail`, `signalIcon` computed properties into `ProfilePrototypeView`. Delete `SegmentedSignalRow`, `SignalSummaryRow`, `PrivacyStrip`, `VoiceStatusPill`, `VoiceSignalRow`, `EmptyVoiceSignalRow`, `BigFiveGauge` from `MVPProfileView.swift` — replace with new `TraitBar`, `VoiceOrbView`, `InterestTagChip` components. Keep `ScreenContainer`, `FeatureCard`, `PrimaryActionButton`, `SecondaryActionButton`, `FlexibleTagLayout`, `TagView` from `PrototypeComponents.swift`.

## Phase 4 — Circles + Communities

Placement surfaces: circles show your placement + available catalog. Communities become backend-driven with pre-seeded catalog.

### Circles — Swift UI

- [x] Rework `CirclesPrototypeView.swift`: top section = "Your circle" card (if placement accepted) showing name, room energy, member count, themes as `FlexibleTagLayout`, next Sunday meetup date if scheduled. Bottom section = "Available circles" horizontal `ScrollView` of 5 archetype `CircleCard`s with fit score badge.
- [x] Create `CircleCard.swift` — `VStack` with `LinearGradient` background (unique per archetype — use archetype id to pick from a palette of green/cream/teal gradients). White text for name + room energy. Theme tags as translucent `Capsule` pills. Member count as secondary line. Card width ~85% of screen for peek. Add `.scrollTransition(.interactive, axis: .horizontal) { content, phase in content.scaleEffect(phase.isIdentity ? 1 : 0.92).opacity(phase.isIdentity ? 1 : 0.7) }`.
- [x] Create `CircleDetailView.swift` — push via `.navigationDestination(for: PlacementCircle.self)`. Shows: full description, room energy, meeting format, themes, fit breakdown (list of fit reasons from placement), upcoming Sunday meetup (if any), "Leave circle" `SecondaryActionButton`.
- [x] Add concern button below "Your circle" card: `SecondaryActionButton(title: "This doesn't feel like my circle", systemImage: "hand.raised.slash")`. On tap: set `appState.concernFlag = true` and switch to Profile tab (show re-interview prompt).
- [x] Remove the "Room accepted" dead-end. After `acceptPlacement()`, the card transitions (spring) to show member count + meetup info instead of just "Room accepted".

### Circles — Backend

- [x] `GET /v1/me/circles` — return array of circles the user belongs to. Pull from `circles` DBMap, filter where `members` array includes the user's profile ID. Response: `[{ id, name, roomEnergy, themes, membersCount, meetingFormat }]`.
- [x] `GET /v1/circles/:id` — return single circle detail: `{ id, name, description, roomEnergy, interactionIntent, socialFormat, themes, meetingFormat, membersCount, fitBreakdown: [{ dimension, score }] }`. `fitBreakdown` computed by calling `computeCircleFit` with the requesting user's profile signals.
- [x] `POST /v1/me/circles/concern` — set `concernFlag: true` on the user's latest profile in mvp-store. Response: `{ status: "concern_registered", message: "Re-interview prompted." }`. No body needed.

### Communities — Backend

- [x] Add `COMMUNITY_ARCHETYPES` array to `architecture.js` (8 objects, same shape as `CIRCLE_ARCHETYPES` minus personality profile fields). Communities: `ai-builders`, `longform-reading`, `design-craft`, `startups`, `mindful-living`, `creative-writing`, `jazz-music`, `trekking-outdoors`. Each has: `id`, `name`, `summary`, `themes: [String]`, `meetingFormat: String`.
- [x] Add `communities` DBMap to `architecture.js` (mirrors `circles`). Add `seedCommunities()` (mirrors `seedCircles()`). Call it on module load.
- [x] Add community membership to `mvp-store.js` — `joinCommunity(userId, communityId)`, `leaveCommunity(userId, communityId)`, `getJoinedCommunities(userId)`. Store as `communityMemberships` array per user.
- [x] `GET /v1/communities` — list all communities with member counts. No auth required (catalog is public).
- [x] `GET /v1/communities/:id` — single community detail with member count.
- [x] `POST /v1/communities/:id/join` — auth required. Add user to community members. Response: `{ status: "joined" }`.
- [x] `POST /v1/communities/:id/leave` — auth required. Remove user from community members.
- [x] `GET /v1/me/communities` — auth required. List communities the user has joined.

### Communities — Swift UI

- [x] Delete `PrototypeData.communities` (3 hardcoded `CommunityRecommendation` constants).
- [x] Rework `CommunitiesPrototypeView.swift`: fetch from `GET /v1/communities` on `.task`. Show as `LazyVStack` of `CommunityCard`s (reuse `CircleCard` shape with community gradient). "Your communities" section at top (from `GET /v1/me/communities`) with compact cards. "Browse" section below with all communities. Join button on each card: `PrimaryActionButton(title: "Join", systemImage: "person.badge.plus")`.
- [x] Create `CommunityDetailView.swift` — push with backend `Community`. Shows: summary, themes, members count, upcoming Saturday meetup (if any), leave button.
- [x] Add `fetchCommunities()` and `joinCommunity(id:)` and `leaveCommunity(id:)` methods to `LikemindedAPIClient.swift`. Add `Community` Swift struct (replaces `CommunityRecommendation` — add `meetingFormat: String` field).

## Phase 5 — Meet + LiveKit Video

Meetup flow: RSVP, AI scheduling, group formation, host selection, in-app group video calls (camera on).

### Meet UI

- [x] Create `MeetView.swift` — new tab view replacing Talk. Top: RSVP card. Below: upcoming meets list. Below: past meets list.
- [x] Create `RSVPCard.swift` — two rows. Row 1: "Saturday — Community meetup" + `Toggle` (Available/Not). Row 2: "Sunday — Circle meetup" + `Toggle`. Toggles use `matchedGeometryEffect` for sliding pill indicator. Add `.sensoryFeedback(.success, trigger: rsvpState)` on toggle.
- [x] Create `PreMeetTeaserCard.swift` — shown Friday only. Circle: "Your Sunday meet: 5 people. You all share slow-trust patterns and analytical communication. Host: [name]." Community: "Your Saturday meet: 5 people from 4 different circles. Two extroverts, three introverts. Host: [name]." Group composition only, no individual profiles.
- [x] Create `UpcomingMeetCard.swift` — day/time line, countdown ("2d 4h away" in `.monospacedDigit()`), host name, group size, join button. Join button disabled until meetup time. At meetup time: button pulses (`.animation(.easeInOut(duration: 0.8).repeatForever())`) and activates.
- [x] Create `PastMeetRow.swift` — compact list row: date, group/circle name, host name. Tap → past meet detail (just the info, no transcript).

### LiveKit video

- [x] Add LiveKit Swift SDK to `project.yml` via SPM dependency: `livekit-client-swift` (url: `https://github.com/livekit/client-sdk-swift`, from: `2.0.0`).
- [x] Create `GroupVideoCallView.swift` — `Room` from LiveKit SDK. `Participant` tiles in a `LazyVGrid` (adaptive columns, 2 per row for 10 participants). Camera on — no toggle to disable. Mute mic toggle available. "Leave" button to disconnect. Connect to room using token from `POST /v1/meetings/:id/join`.
- [x] Create `LiveKitTokenProvider.swift` — calls `POST /v1/meetings/:id/join`, returns `{ token: String, url: String }`. Swift side: `Room.connect(url: urlString, token: tokenString)`.
- [x] Backend: Add `livekit-server-sdk` dependency to root `package.json`. Add `services/api/src/lib/livekit.js` — exports `createRoom(meetingId)`, `generateParticipantToken(userId, meetingId)`. Uses `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL` env vars.
- [x] Backend: `POST /v1/meetings/:id/join` — verify user is a participant in the meeting, generate LiveKit token, return `{ token, url }`.

### Backend: meetings model + routes

- [x] Add meetings to `mvp-store.js`: `saveMeeting(meeting)`, `getMeeting(id)`, `getUpcomingMeetings(userId)`, `getPastMeetings(userId)`, `getRSVPs(circleId|communityId, weekend)`, `saveRSVP(userId, day, circleId|communityId)`. Meeting object: `{ id, type: "circle"|"community", groupId, scheduledAt, hostUserId, participantUserIds: [], status: "scheduled"|"completed" }`.
- [x] `POST /v1/meetings/rsvp` — auth required. Body: `{ day: "saturday"|"sunday", groupId: String }`. Saves RSVP. Response: `{ status: "rsvp_saved" }`.
- [x] `GET /v1/meetings/upcoming` — auth required. Returns user's upcoming meetings where they're a participant.
- [x] `GET /v1/meetings/:id` — auth required. Returns meeting detail. Verify user is a participant.
- [x] `POST /v1/meetings/:id/join` — auth required. Returns LiveKit token (see LiveKit section above).
- [x] `GET /v1/meetings/past` — auth required. Returns past meetings for the user.

### Backend: AI scheduling job

- [x] Create `services/api/src/lib/scheduling.js` — exports `runWeekendScheduling()`. Called by a cron-like trigger (MVP: manual endpoint `POST /v1/admin/run-scheduling` with a shared secret, or a `setInterval` check in server startup). Not a real cron daemon for MVP.
- [x] `runWeekendScheduling()` logic: (1) For each circle with Sunday RSVPs >= 6, pull all RSVP'd members, `shuffle()`, partition into groups of 10 (last group min 6), gender-balance 5M/5F within each group (pull males and females separately, interleave), score host per group using `scoreCircleHost()`, create meeting record with `scheduledAt = Sunday 7pm`. (2) Same for communities with Saturday RSVPs, using `scoreCommunityHost()`, `scheduledAt = Saturday 7pm`.
- [x] Create `scoreCircleHost(participantProfiles)` in `scheduling.js` — score each participant: `socialEnergy` high/medium (+1), `communicationStyle.primary` warm/expressive (+1), `agreeableness` > 0.6 (+1), `extraversion` > 0.6 (+1), `neuroticism` < 0.6 (+1), dominance low = `communicationStyle.primary != "direct"` AND `conflictStyle != "engaging"` (+1), `trustPattern == "fastTrust"` (+1). Highest score = host. Tiebreak: more meetups attended.
- [x] Create `scoreCommunityHost(participantProfiles)` in `scheduling.js` — score each participant: `openness` > 0.7 (+1), `agreeableness` > 0.6 (+1), `extraversion` 0.4-0.8 (+1), `communicationStyle.primary == "warm"` (+1), `neuroticism` < 0.5 (+1), `socialEnergy` high/medium (+1), dominance low (+1). Highest score = host. Tiebreak: more meetups attended.
- [x] Gender balance: pull `basicInfo.gender` from each participant's profile. Male + Female pools. Interleave into groups: 5 males + 5 females per group of 10. Non-binary / prefer-not-to-say: place freely without gender constraint.
- [x] Leftover handling: if RSVP count % 10 != 0 and remainder < 6, skip the remainder group. If remainder >= 6, create a smaller group.

## Phase 6 — Soulmate + Chat

Opt-in matching: post-meet selection, mutual matches, interest profile view, in-app chat.

### Soulmate — Backend

- [x] Add soulmate to `mvp-store.js`: `setSoulmateEnabled(userId, bool)`, `isSoulmateEnabled(userId)`, `saveSoulmateSelection(userId, meetingId, selectedUserIds: [String])`, `getSoulmateMatches(userId)`, `getSoulmateMatch(userId, matchUserId)`, `archiveStaleMatches()`. Match = two users who selected each other for the same meeting. Store selections as `{ userId, meetingId, selectedUserIds }`. Match record: `{ id, userAId, userBId, meetingId, createdAt, lastActiveAt }`.
- [x] `POST /v1/me/soulmate/enable` — auth required. Body: `{ enabled: Bool }`. Sets soulmate flag on user. Response: `{ status: "updated", enabled: Bool }`.
- [x] `GET /v1/me/soulmate/status` — auth required. Returns: `{ enabled: Bool, pendingSelections: [{ meetingId, potentialMatches: [String] }] }`. `potentialMatches` = opposite-sex participants in the user's recent meetings who also have soulmate enabled.
- [x] `POST /v1/me/soulmate/select` — auth required. Body: `{ meetingId: String, selectedUserIds: [String] }`. Saves selection. Check if any selected user also selected this user → if yes, create match record. Response: `{ status: "saved", newMatches: [String] }`.
- [x] `GET /v1/me/soulmate/matches` — auth required. Returns: `[{ matchId, userId, name, meetingId, meetingDate, createdAt }]`.
- [x] `GET /v1/me/soulmate/matches/:id` — auth required. Returns: match detail with other person's `basicInfo.name`, `interests` (full, read-only), `basicInfo.gender`. No `hiddenSignals`. No personality signals. Just interests + name + gender.
- [x] `GET /v1/me/soulmate/past` — auth required. Returns archived matches (30+ days inactive).

### Chat — Backend

- [x] Add chat messages to `mvp-store.js`: `saveMessage(matchId, senderId, text)`, `getMessages(matchId, afterTimestamp?)`. Message: `{ id, matchId, senderId, text, createdAt }`. Store as array per match.
- [x] `GET /v1/me/soulmate/matches/:id/messages` — auth required. Returns messages for the match (paginated, last 50). Verify requester is a participant in the match.
- [x] `POST /v1/me/soulmate/matches/:id/messages` — auth required. Body: `{ text: String }`. Saves message, updates `lastActiveAt` on match. Returns saved message.

### Soulmate + Chat — Swift UI

- [x] Add `soulmateEnabled: Bool` to `PrototypeAppState`. Default `false`. When `false`, Soulmate tab is hidden from tab bar. When toggled, tab appears/disappears with `.spring(response: 0.38, dampingFraction: 0.82)`.
- [x] Create `SoulmateView.swift` — matches list (`LazyVStack` of `SoulmateMatchRow`s). Each row: name, which meetup met at. Tap → `SoulmateMatchDetailView`. Empty state: "No matches yet. Enable Soulmate and join meetups."
- [x] Create `SoulmateMatchDetailView.swift` — shows other person's interests as `InterestTagChip`s (same depth encoding as Profile). "Start chat" `PrimaryActionButton` with `systemImage: "message.fill"`. Top-right `Image(systemName: "bubble.right")` chat icon → pushes `ChatView`.
- [x] Create `ChatView.swift` — `ScrollView` with `LazyVStack(spacing: 10)` of `MessageBubble`s. Outgoing: accent green bg, white text, trailing-aligned. Incoming: surface bg, ink text, leading-aligned. `RoundedRectangle(cornerRadius: 18, style: .continuous)`. Max width 70%. Composer: `TextField(axis: .vertical)` with `.lineLimit(1...4)` + `Button` with `Image(systemName: "arrow.up.circle.fill")`. Composer pinned at bottom with `.background(.regularMaterial)`. Poll messages every 3 seconds when view is active.
- [x] Create `ConversationListView.swift` — list of all chat conversations. Row: name, last message preview (truncated), timestamp. Push to `ChatView` on tap. Accessed via top-right `Image(systemName: "bubble.right")` in `SoulmateView` toolbar.
- [x] Create `TypingIndicatorView.swift` — `HStack` of 3 `Circle`s (6pt). Sequential opacity animation: `.easeInOut(duration: 0.3).delay(Double(i) * 0.2)`. Inside a bubble-shaped container (same shape as incoming messages).
- [x] Create `SoulmateSelectionDialog.swift` — `.sheet` presented after a meetup ends (if soulmate enabled). "Did you connect with someone?" `LazyVStack` of names (opposite-sex group members with soulmate enabled). Multi-select with checkmark overlay. "Submit" button. Calls `POST /v1/me/soulmate/select`.
- [x] Add `fetchSoulmateStatus()`, `fetchSoulmateMatches()`, `fetchSoulmateMatchDetail(id:)`, `fetchMessages(matchId:)`, `sendMessage(matchId:text:)`, `submitSoulmateSelection(meetingId:selectedUserIds:)`, `setSoulmateEnabled(_:)` to `LikemindedAPIClient.swift`.

## Phase 7 — Navigation + Motion Polish

Tab restructure, custom tab bar, animation system, material backgrounds.

### Tab restructure

- [x] Update `AppTab` enum in `PrototypeModels.swift`: change `.talk` to `.meet` (`case meet = "Meet"`, `systemImage: "person.2.video"`). Add `case soulmate = "Soulmate"` (`systemImage: "heart.circle"`). Keep `.circles`, `.communities`, `.profile`.
- [x] Update `RootView.swift`: replace `ReflectionPrototypeView()` with `MeetView()` in the `TabView`. Add conditional `SoulmateView()` tab — only included when `appState.soulmateEnabled == true`.
- [x] Create `CustomTabBar.swift` — replaces system `TabView` tab bar. `HStack` of tab items. Each item: `Image(systemName:)` with `.scaleEffect(selection == tab ? 1.1 : 1.0)` + `symbolVariant(selection == tab ? .fill : .none)`. Label `Text` only on selected tab with `.transition(.opacity.combined(with: .move(edge: .bottom)).combined(with: .scale))`. Background `.ultraThinMaterial`. Tap: `withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selection = tab }`.
- [x] Soulmate tab appear/disappear: when `soulmateEnabled` toggles, the tab bar items array changes with `.animation(.spring(response: 0.38, dampingFraction: 0.82))`.

### Motion system

- [x] Add to `PrototypeComponents.swift` or a new `MotionConstants.swift`: `extension Animation { static let interactive = .spring(response: 0.38, dampingFraction: 0.82); static let celebratory = .spring(response: 0.50, dampingFraction: 0.70); static let snappy = .spring(response: 0.30, dampingFraction: 0.85) }`.
- [x] Apply staggered entrance to card lists: `ForEach(Array(items.enumerated()), id: \.element.id) { index, item in ItemCard(item: item).opacity(show ? 1 : 0).offset(y: show ? 0 : 20).animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.06), value: show) }.onAppear { withAnimation { show = true } }`.
- [x] Apply `.contentTransition(.numericText())` to member counts, group sizes, countdown values.
- [x] Apply `.contentTransition(.opacity)` to voice status labels, placement state labels.
- [x] Apply `.scrollTransition(.interactive, axis: .horizontal)` to all horizontal card scrolls (circles, communities).
- [x] Apply `.background(.regularMaterial)` to: custom tab bar, chat composer, onboarding wizard container, any `.sheet` content.
- [x] Apply `matchedGeometryEffect` for circle card → detail: `@Namespace` in `CirclesPrototypeView`, `.matchedGeometryEffect(id: circle.id, in: namespace)` on both the card and the detail hero.
- [x] Apply `.sensoryFeedback(.success, trigger:)` to: RSVP toggle, placement accept/swap/defer, soulmate match, soulmate selection submit.

### Screen validation against mockups

- [x] iOS screens 1-20 in `mockups/ios/` checked against `DESIGN.md`: auth, voice/profile, Meet states, Circles/detail, Communities/detail/settings, Soulmate/match/chat, and bottom dock model are represented by the current SwiftUI surfaces. Intentional MVP scope: generated people photos and richer live-call media remain mockup-only.
- [x] macOS screens 1-20 in `mockups/macos/` inventoried against `DESIGN.md`: `MacPrototypeScreen` covers auth, Meet, Circles, Profile, Chat/Messages, Communities/detail/members/event, recap, Soulmate overview/discover/detail, notifications/activity, onboarding, and settings with the bottom floating dock model. Phase 8 audit evidence in `docs/references/macos-screen-audit.md` supersedes any parity claim: macOS backend connectivity now has pre-seeded validation DB evidence, while visual mockup mismatches remain before validation closeout.

## Phase 7.B — Functional Gap Closure (Pre-Phase 8)

Close the functional gap between DESIGN.md/product-direction and the shipped iOS + macOS apps so the seeded validation DB exercises real functionality, not static placeholders. Visual/mockup pixel-parity and remaining decorative stubs are owned by **Track — macOS Visual Parity + Ledger Closeout** and **Track — iOS Ledger Honesty** (not by this historical phase checkbox set).

### Part A — Wire-up fixes on existing screens

- [x] iOS Profile: replace hardcoded Big Five trait values and interest tags with real data from `appState.slice.signals.bigFive` and `appState.slice.profile.interests`. Map communication style to the read card copy.
- [x] iOS Settings: bind Soulmate toggle to `appState.setSoulmateEnabled`; wire Privacy policy sheet from `docs/references/privacy-policy-testflight.md`; confirm Sign out; mark coming-soon rows visibly disabled.
- [x] iOS Communities: working search field that filters the catalog by name/themes/summary.
- [x] iOS Circle/Community detail: derive next meetup date + countdown from `appState.upcomingMeetings` instead of hardcoded strings.
- [x] iOS Soulmate detail: verified `fetchSoulmateMatchDetail` + `ChatView` already wired (no change needed).
- [x] Dead code cleanup: delete `TodayPrototypeView.swift`, legacy `ProfilePrototypeView` in `MVPProfileView.swift`, unused `VoiceOrbView.swift`, and the `SafetyPrototypeView` alias.
- [x] macOS chat: wire composer send button to `appState.sendMessage` (was an empty `// send` stub) via a new `MacChatComposer` subview that owns the text state.
- [x] macOS Soulmate detail: remove standalone Pass/Like stub buttons (no backend for swipe-like likes); keep intentional Message action.
- [x] macOS Settings: wire Log out to `appState.signOut()` with a confirmation dialog (was a no-op label).

### Part B — New / missing screens

- [x] iOS Notifications + Activity screen (`NotificationsView.swift`): consumes `GET /v1/me/notifications`, grouped Notifications + Activity sections, filter pills (All/Meets/Matches/Messages), calm grouped cards. Entry point: bell icon in Meet header with unread badge.
- [x] iOS post-meet recap: enhance `PastMeetDetailView` with host, group size, composition, private reflection note, and a "Select connections" action that opens `SoulmateSelectionDialog` when soulmate is enabled.
- [x] Backend `GET /v1/communities/:id/members` route + `getCommunityMembers` in `mvp-store.js` (returns names + gender only; no hidden signals).
- [x] macOS community members screen: replace hardcoded demo roster with real backend members via `MacAppState.fetchCommunityMembers`.
- [x] macOS create event: functional community meet creation via `POST /v1/meetings` from `createEvent` (event type pills, live preview, optional cover/tags, create persists without navigation drift). Visual reference: `mockups/macos/22-create-event.png`. Evidence: `validation/macos/10-create-event.json` on seeded validation DB. Open: SwiftUI text-field typing proof where Computer Use cannot mutate focused fields.
- [x] macOS deep screens reachable in-app: add `navigate` closure to `MacScreenView` and wire entry points (past meetup → recap, community card → detail → members, soulmate match → detail → chat).

### Part C — Validation + docs

- [x] Extend `smoke_mvp.js` to cover `GET /v1/me/notifications` and `GET /v1/communities/:id/members`.
- [x] Update `docs/references/macos-screen-audit.md` for backend wire-up evidence (visual parity and remaining stubs deferred to the macOS track; JSON ledgers are status owner).
- [x] Update `goal.json` + `goal.template.json` to the Phase 7.B goal.
- [x] Run full grader suite.

## Phase 8 — Docs + Validation

Update docs to match shipped product. Run all graders.

- [x] Update `DESIGN.md` — new tabs: Meet (RSVP + upcoming/past meets), Circles (your circle + available + concern), Communities (backend catalog + join), Profile (voice interview + signals + interests + onboarding), Soulmate (opt-in matches + chat). New copy rules: one subtitle per screen, model prose in Profile only, meetup info in Meet only, interest tags in Communities and Soulmate match detail only.
- [x] Update `product-direction.md` — add: AI-driven meetup flow (RSVP → group formation → host selection → scheduled video call), circles vs communities contrast (personality vs interest, Sunday vs Saturday), soulmate feature (opt-in, post-meet mutual selection, chat), hidden placement signals, onboarding before interview.
- [x] Set the next active docs/validation goal in `goal.json`. Update `deterministic_graders` and `done_criteria` only if Phase 8 changes validation coverage.
- [x] Update `goal.template.json` to match `goal.json` structure.
- [x] Run `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs lint` — must pass with no errors.
- [x] Update `npm run check` script in `package.json` — add new backend files to the syntax check chain: `services/api/src/lib/scheduling.js`, `services/api/src/lib/livekit.js`.
- [x] Add deterministic validation database lifecycle: `npm run dev:api:validation` attaches `data/validation-db`; `npm run reset:validation-data` reseeds through the API; `npm run remove:validation-data` cleans seeded data.
- [x] Add macOS screen capture validation with `npm run verify:macos-screens` and record screen-by-screen mockup evidence.
- [x] Update `npm run smoke:mvp` (`script/smoke_mvp.js`) — add test coverage for: `GET /v1/me/circles`, `GET /v1/circles/:id`, `POST /v1/me/circles/concern`, `GET /v1/communities`, `POST /v1/communities/:id/join`, `GET /v1/me/communities`, `POST /v1/meetings/rsvp`, `GET /v1/meetings/upcoming`, `POST /v1/me/soulmate/enable`, `POST /v1/me/soulmate/select`, `GET /v1/me/soulmate/matches`, `GET /v1/me/soulmate/matches/:id`, `POST /v1/me/soulmate/matches/:id/messages`.
- [x] Close remaining dead local controls: iOS Settings opens How it works, Help/FAQ, Privacy, and Contact support; Contact support persists through `/v1/feedback`; macOS welcome sign-in calls the backend auth path; macOS Conversations selects each backend match thread instead of always showing the first; macOS Notifications refreshes live backend notifications; iOS/macOS recap notes persist through `POST /v1/meetings/:id/recap-note` and seed data includes a saved recap note.
- [x] `npm run verify:release-config` — add LiveKit env var checks (`LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL`) to `script/verify_release_config.js`.
- [x] `npm run verify:goal` — passes with updated `goal.json`.
- [x] `./script/build_and_run.sh --verify` — builds and launches with new tab structure, LiveKit dependency, new views.
- [x] `npm run verify:macos-screens` — all 20 MacPrototypeScreens captured to `output/validation/macos-screens/`.
- [x] All deterministic graders pass (node_syntax, mvp_backend_contract, release_static_config, goal_contract, repo_docs_lint, validation_data_lifecycle, macos_screen_capture).
- [x] Manual proofs — **iOS** (historical Phase 8 session evidence only; not ledger-green): open fail/pending rows are owned by **Track — iOS Ledger Honesty** and `validation/ios/*.json`. Do not treat these checkboxes as current control coverage.
  - [x] Onboarding wizard flows into voice profile; runtime tap covers name, gender/default, date, city, pincode, and final Start voice profile.
  - [x] Profile shows backend profile details, trait bars, interests, and a voice orb/status sheet with Stop/Done controls.
  - [x] Circles shows your circle + available circles + concern button; runtime tap also opens circle detail and Back after the card-navigation fix.
  - [x] Meet shows RSVP toggles + upcoming meets; runtime tap also opens history recap and saves a private recap note through the backend.
  - [x] Communities shows backend-driven catalog; runtime tap covers search, joined/detail navigation, Back, join, and backend member-count update.
  - [x] Soulmate toggle shows/hides tab. Post-meet dialog works. Chat works.
  - [x] Settings support screens open at runtime; Contact support persists via `/v1/feedback`.

## Phase 9 — External TestFlight Readiness (after redesign complete)

- [ ] Create Neon/Postgres database and set `DATABASE_URL`.
- [ ] Create Render web service from `render.yaml`.
- [ ] Set production env vars: `SESSION_SECRET`, `OPENAI_API_KEY`, `OPENAI_REALTIME_MODEL`, `OPENAI_REALTIME_VOICE`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL`, `APPLE_BUNDLE_ID`, `APPLE_CLIENT_ID`, `APPLE_AUTH_BYPASS=0`.
- [ ] Provision LiveKit server (self-hosted or LiveKit Cloud). Set `LIVEKIT_URL` to the WebSocket endpoint.
- [ ] Configure Apple Developer bundle id `com.likeminded.app`.
- [ ] Enable Sign in with Apple capability for the app id.
- [ ] Configure App Store Connect/TestFlight metadata and privacy policy.
- [x] Add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to `Info.plist` — required for LiveKit video + OpenAI Realtime audio.
- [x] Add repo-side account deletion readiness before wider beta: Settings entry on iOS and macOS, `DELETE /v1/me/account`, session revocation through user deletion, removal/anonymization of user-owned profile/placement/transcript/feedback/chat/meeting data, and runtime proof in `npm run smoke:mvp`. App Store Connect metadata still ships under the TestFlight metadata checklist above.
- [ ] Build signed TestFlight candidate.

## Phase 10 — Simulator/Device Proof (after Phase 9)

- [ ] Fresh install shows Sign in with Apple gate.
- [ ] Real Apple sign-in succeeds.
- [ ] Onboarding form appears after sign-in.
- [ ] Voice interview starts from Profile tab after onboarding.
- [ ] Stopping voice creates persisted profile with personality + interests + hidden signals.
- [ ] Relaunch restores latest profile + placement.
- [ ] Tabs are `Meet`, `Circles`, `Communities`, `Profile` (+ `Soulmate` if enabled).
- [ ] Circles shows your circle + available circles.
- [ ] Meet shows RSVP toggles.
- [ ] Communities shows backend-driven catalog.
- [ ] Soulmate toggle shows/hides tab. Post-meet selection works. Chat works.
- [ ] iOS group video call joins with camera on.
- [x] macOS group video call parity: `MacGroupVideoCallView` wires LiveKit SDK, `Join meetup` calls `POST /v1/meetings/:id/join`, mute/leave disconnect the room; validation API join smoke passes. Remaining: provision LiveKit server at `LIVEKIT_URL` for connected-room device proof (Phase 9).
- [x] macOS Settings rows are honest: Account/Soulmate controls are real, destructive account actions open confirmations, and Privacy & safety, Notifications, Voice profile, Connected apps, Appearance, Language, and Help & support are muted/static labels instead of selectable-looking no-op rows.
- [ ] A second tester cannot access the first tester's profile, placement, or chat.

## Track — macOS Visual Parity + Ledger Closeout

Parallel to Phase 9; not a numbered phase. Owner: `docs/references/macos-screen-audit.md`. First command when focusing this track: `./script/macos_audit_prepare.sh` then `./script/run_macos_manual_validation.sh <screen>` or `./script/macos_cua_screen.sh`.

- [x] Manual proofs — **macOS**: infra-only blockers remain (welcome Apple sign-in, meet video LiveKit join); all other `validation/macos/*.json` controls pass/fail/blocked with CUA on validation-priya.
- [x] macOS validation ledgers: drive `validation/macos/*.json` controls to pass/fail/blocked with runtime evidence (JSON is the only status owner). Closed: chat/messages, soulmate discover/detail, profile surfaces, communities browse typing, create-event typing, meet recap note, create-community (`22-create-community.json`), CUA stale reproof after social auth (`npm run macos:cua-reproof`). Remaining infra: welcome Apple sign-in capture, meet video LiveKit join (Phase 10).
- [x] macOS profile honesty: `profileEdit` / `profileOnboarding` / personality signal cards use backend profile data or honest static labels; CUA evidence in `validation/macos/05-profile-edit.json`, `12-my-profile.json`, `13-profile-onboarding.json`, `14-profile-signals.json`.
- [x] macOS soulmate discover/detail honesty: fake distance/filter/compatibility chrome removed; match cards use API fields; CUA evidence in `validation/macos/15-soulmate-overview.json`, `16-soulmate-discover.json`, `17-soulmate-detail.json`.
- [x] macOS community members honesty: sidebar/filter pills/member rows wired or demoted; search proven; CUA evidence in `validation/macos/09-community-members.json`.
- [x] Re-CUA all macOS controls still `pending` for CUA (chat, messages, soulmate, share-profile, onboarding continue, members search, communities search, recap note, create-event fields) using `./script/macos_cua_screen.sh`.
- [x] macOS create-community form ledger: `validation/macos/22-create-community.json` controls for name/summary/themes/submit driven to pass with CUA.
- [x] macOS visual parity vs `mockups/macos/` and per-screen refs in `docs/references/macos-screen-audit.md`; regenerate `output/validation/macos-screens/` via `npm run verify:macos-screens` after UI polish.
- [x] macOS create event layout parity vs `mockups/macos/22-create-event.png` at default, smaller, and maximized window sizes with traffic lights visible.
- [x] macOS CUA needle alignment: `script/macos_cua_screen.sh` click labels match `MacScreens.swift` accessibilityLabel strings; stamp gated on `CUA-click` success (no launch-only false-green); onboarding step rows expose individual AX labels.

## Track — macOS Unimplemented Controls (static UI)

Ledger owner: `validation/macos/*.json` pending rows with `stub: true` and blocker `Not implemented`. Rollup index: `validation/macos-unimplemented-inventory.json`. Static row = no screen on click.

- [x] macOS Settings: implement 7 sidebar nav rows (Account, Privacy & safety, Notifications, Connected apps, Appearance, Language, Help & support) and 3 Soulmate preference editors (discovery, age range, visibility); evidence in `validation/macos/20-settings-soulmate.json` (10 pending).
- [x] macOS Chat + Messages: implement voice call, video call, and conversation info header actions; evidence in `validation/macos/06-chat.json` and `18-messages.json` (6 pending total).
- [x] macOS Community detail: implement ellipsis options + Resources/Highlights rows; evidence in `validation/macos/08-community-detail.json` (5 pending).
- [x] macOS Profile voice/onboarding: macOS voice interview + onboarding steps 2–3; evidence in `validation/macos/12-my-profile.json` and `13-profile-onboarding.json` (3 pending).
- [ ] macOS infra-blocked (not static): real Sign in with Apple (`validation/macos/01-welcome.json`) — Phase 9 Apple Developer setup.

## Track — iOS Ledger Honesty (post–Phase 8)

Phase 8 marked iOS manual proofs complete, but `validation/ios/*.json` still has open fail/pending rows. Close these before claiming production-grade iOS control coverage.

- [x] iOS Leave circle: Leave circle confirms and calls `deferPlacement` via `POST /v1/me/placement/actions`; evidence in `validation/ios/11-circle-detail.json`.
- [x] iOS past-meet row navigation: `NavigationLink(value: Meeting)` pushes `PastMeetDetailView`; evidence in `validation/ios/07-meet.json`.
- [x] iOS ledger closeout: functional + visual parity controls pass/blocked in `validation/ios/*.json`; remaining infra-blocked: real Apple sign-in + LiveKit (Phase 9/10).

## Deferred

- Push notifications.
- Subscriptions and entitlements.
- Advanced moderation/report/block flows.
- Offline meeting coordination (restaurant/cafe bookings).
- AI transcript analysis (group dynamics, host performance, profile signal updates).
- Same-sex Soulmate.
- Community-created content/feeds.
- Host volunteer path.
- RSVP window: always open, closes Friday midnight? (Proposed: yes.)
- Min RSVP threshold: if 15 RSVP, skip the remainder < 6. (Proposed: skip groups smaller than 6.)
- Non-binary in group formation: exclude from gender balance, place by fit only? (Proposed: yes.)
- Meetup duration: 60 min default or open-ended?
- Multiple time slots per day: all groups within one timezone meet at 7pm local.
- Soulmate match expiry: archive after 30 days of inactivity?
- Interest profile visibility: can soulmate matches see full interest profile? (Proposed: yes.)
