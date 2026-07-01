# Likeminded — MVP Progress

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This file tracks repo progress and roadmap state only.

## Current Status

- Product redesign in progress (see `docs/product-redesign.md` for full spec).
- Phases 0-2 complete (auth, MVP loop, deterministic validation).
- Phases 3-8 are the redesign build-out. TestFlight is Phase 9.
- Existing auth, backend, Realtime voice, and mvp-store infrastructure stays.
- Design system stays: warm cream canvas, deep green accent, SF typography.
- Design doc: `docs/product-redesign.md`. UI/UX research: `docs/references/ui-ux-patterns-research.md`.
- Mockup prototype pass shipped for the five-tab shell: Meet, Circles, Communities, Profile, and Soulmate now share the updated cream/green/serif visual language, with static live-call, post-meet selection, Profile empty/existing states, Community detail, and Settings/Soulmate-toggle prototypes. Phase 4 is complete; Phase 5/6 backend and real room wiring remain unchecked.

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

- [ ] Create `MeetView.swift` — new tab view replacing Talk. Top: RSVP card. Below: upcoming meets list. Below: past meets list.
- [ ] Create `RSVPCard.swift` — two rows. Row 1: "Saturday — Community meetup" + `Toggle` (Available/Not). Row 2: "Sunday — Circle meetup" + `Toggle`. Toggles use `matchedGeometryEffect` for sliding pill indicator. Add `.sensoryFeedback(.success, trigger: rsvpState)` on toggle.
- [ ] Create `PreMeetTeaserCard.swift` — shown Friday only. Circle: "Your Sunday meet: 5 people. You all share slow-trust patterns and analytical communication. Host: [name]." Community: "Your Saturday meet: 5 people from 4 different circles. Two extroverts, three introverts. Host: [name]." Group composition only, no individual profiles.
- [ ] Create `UpcomingMeetCard.swift` — day/time line, countdown ("2d 4h away" in `.monospacedDigit()`), host name, group size, join button. Join button disabled until meetup time. At meetup time: button pulses (`.animation(.easeInOut(duration: 0.8).repeatForever())`) and activates.
- [ ] Create `PastMeetRow.swift` — compact list row: date, group/circle name, host name. Tap → past meet detail (just the info, no transcript).

### LiveKit video

- [ ] Add LiveKit Swift SDK to `project.yml` via SPM dependency: `livekit-client-swift` (url: `https://github.com/livekit/client-sdk-swift`, from: `2.0.0`).
- [ ] Create `GroupVideoCallView.swift` — `Room` from LiveKit SDK. `Participant` tiles in a `LazyVGrid` (adaptive columns, 2 per row for 10 participants). Camera on — no toggle to disable. Mute mic toggle available. "Leave" button to disconnect. Connect to room using token from `POST /v1/meetings/:id/join`.
- [ ] Create `LiveKitTokenProvider.swift` — calls `POST /v1/meetings/:id/join`, returns `{ token: String, url: String }`. Swift side: `Room.connect(url: urlString, token: tokenString)`.
- [ ] Backend: Add `livekit-server-sdk-node` dependency to `services/api/package.json`. Add `services/api/src/lib/livekit.js` — exports `createRoom(meetingId)`, `generateParticipantToken(userId, meetingId)`. Uses `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL` env vars.
- [ ] Backend: `POST /v1/meetings/:id/join` — verify user is a participant in the meeting, generate LiveKit token, return `{ token, url }`.

### Backend: meetings model + routes

- [ ] Add meetings to `mvp-store.js`: `saveMeeting(meeting)`, `getMeeting(id)`, `getUpcomingMeetings(userId)`, `getPastMeetings(userId)`, `getRSVPs(circleId|communityId, weekend)`, `saveRSVP(userId, day, circleId|communityId)`. Meeting object: `{ id, type: "circle"|"community", groupId, scheduledAt, hostUserId, participantUserIds: [], status: "scheduled"|"completed" }`.
- [ ] `POST /v1/meetings/rsvp` — auth required. Body: `{ day: "saturday"|"sunday", groupId: String }`. Saves RSVP. Response: `{ status: "rsvp_saved" }`.
- [ ] `GET /v1/meetings/upcoming` — auth required. Returns user's upcoming meetings where they're a participant.
- [ ] `GET /v1/meetings/:id` — auth required. Returns meeting detail. Verify user is a participant.
- [ ] `POST /v1/meetings/:id/join` — auth required. Returns LiveKit token (see LiveKit section above).
- [ ] `GET /v1/meetings/past` — auth required. Returns past meetings for the user.

### Backend: AI scheduling job

- [ ] Create `services/api/src/lib/scheduling.js` — exports `runWeekendScheduling()`. Called by a cron-like trigger (MVP: manual endpoint `POST /v1/admin/run-scheduling` with a shared secret, or a `setInterval` check in server startup). Not a real cron daemon for MVP.
- [ ] `runWeekendScheduling()` logic: (1) For each circle with Sunday RSVPs >= 6, pull all RSVP'd members, `shuffle()`, partition into groups of 10 (last group min 6), gender-balance 5M/5F within each group (pull males and females separately, interleave), score host per group using `scoreCircleHost()`, create meeting record with `scheduledAt = Sunday 7pm`. (2) Same for communities with Saturday RSVPs, using `scoreCommunityHost()`, `scheduledAt = Saturday 7pm`.
- [ ] Create `scoreCircleHost(participantProfiles)` in `scheduling.js` — score each participant: `socialEnergy` high/medium (+1), `communicationStyle.primary` warm/expressive (+1), `agreeableness` > 0.6 (+1), `extraversion` > 0.6 (+1), `neuroticism` < 0.6 (+1), dominance low = `communicationStyle.primary != "direct"` AND `conflictStyle != "engaging"` (+1), `trustPattern == "fastTrust"` (+1). Highest score = host. Tiebreak: more meetups attended.
- [ ] Create `scoreCommunityHost(participantProfiles)` in `scheduling.js` — score each participant: `openness` > 0.7 (+1), `agreeableness` > 0.6 (+1), `extraversion` 0.4-0.8 (+1), `communicationStyle.primary == "warm"` (+1), `neuroticism` < 0.5 (+1), `socialEnergy` high/medium (+1), dominance low (+1). Highest score = host. Tiebreak: more meetups attended.
- [ ] Gender balance: pull `basicInfo.gender` from each participant's profile. Male + Female pools. Interleave into groups: 5 males + 5 females per group of 10. Non-binary / prefer-not-to-say: place freely without gender constraint.
- [ ] Leftover handling: if RSVP count % 10 != 0 and remainder < 6, skip the remainder group. If remainder >= 6, create a smaller group.

## Phase 6 — Soulmate + Chat

Opt-in matching: post-meet selection, mutual matches, interest profile view, in-app chat.

### Soulmate — Backend

- [ ] Add soulmate to `mvp-store.js`: `setSoulmateEnabled(userId, bool)`, `isSoulmateEnabled(userId)`, `saveSoulmateSelection(userId, meetingId, selectedUserIds: [String])`, `getSoulmateMatches(userId)`, `getSoulmateMatch(userId, matchUserId)`, `archiveStaleMatches()`. Match = two users who selected each other for the same meeting. Store selections as `{ userId, meetingId, selectedUserIds }`. Match record: `{ id, userAId, userBId, meetingId, createdAt, lastActiveAt }`.
- [ ] `POST /v1/me/soulmate/enable` — auth required. Body: `{ enabled: Bool }`. Sets soulmate flag on user. Response: `{ status: "updated", enabled: Bool }`.
- [ ] `GET /v1/me/soulmate/status` — auth required. Returns: `{ enabled: Bool, pendingSelections: [{ meetingId, potentialMatches: [String] }] }`. `potentialMatches` = opposite-sex participants in the user's recent meetings who also have soulmate enabled.
- [ ] `POST /v1/me/soulmate/select` — auth required. Body: `{ meetingId: String, selectedUserIds: [String] }`. Saves selection. Check if any selected user also selected this user → if yes, create match record. Response: `{ status: "saved", newMatches: [String] }`.
- [ ] `GET /v1/me/soulmate/matches` — auth required. Returns: `[{ matchId, userId, name, meetingId, meetingDate, createdAt }]`.
- [ ] `GET /v1/me/soulmate/matches/:id` — auth required. Returns: match detail with other person's `basicInfo.name`, `interests` (full, read-only), `basicInfo.gender`. No `hiddenSignals`. No personality signals. Just interests + name + gender.
- [ ] `GET /v1/me/soulmate/past` — auth required. Returns archived matches (30+ days inactive).

### Chat — Backend

- [ ] Add chat messages to `mvp-store.js`: `saveMessage(matchId, senderId, text)`, `getMessages(matchId, afterTimestamp?)`. Message: `{ id, matchId, senderId, text, createdAt }`. Store as array per match.
- [ ] `GET /v1/me/soulmate/matches/:id/messages` — auth required. Returns messages for the match (paginated, last 50). Verify requester is a participant in the match.
- [ ] `POST /v1/me/soulmate/matches/:id/messages` — auth required. Body: `{ text: String }`. Saves message, updates `lastActiveAt` on match. Returns saved message.

### Soulmate + Chat — Swift UI

- [ ] Add `soulmateEnabled: Bool` to `PrototypeAppState`. Default `false`. When `false`, Soulmate tab is hidden from tab bar. When toggled, tab appears/disappears with `.spring(response: 0.38, dampingFraction: 0.82)`.
- [ ] Create `SoulmateView.swift` — matches list (`LazyVStack` of `SoulmateMatchRow`s). Each row: name, which meetup met at. Tap → `SoulmateMatchDetailView`. Empty state: "No matches yet. Enable Soulmate and join meetups."
- [ ] Create `SoulmateMatchDetailView.swift` — shows other person's interests as `InterestTagChip`s (same depth encoding as Profile). "Start chat" `PrimaryActionButton` with `systemImage: "message.fill"`. Top-right `Image(systemName: "bubble.right")` chat icon → pushes `ChatView`.
- [ ] Create `ChatView.swift` — `ScrollView` with `LazyVStack(spacing: 10)` of `MessageBubble`s. Outgoing: accent green bg, white text, trailing-aligned. Incoming: surface bg, ink text, leading-aligned. `RoundedRectangle(cornerRadius: 18, style: .continuous)`. Max width 70%. Composer: `TextField(axis: .vertical)` with `.lineLimit(1...4)` + `Button` with `Image(systemName: "arrow.up.circle.fill")`. Composer pinned at bottom with `.background(.regularMaterial)`. Poll messages every 3 seconds when view is active.
- [ ] Create `ConversationListView.swift` — list of all chat conversations. Row: name, last message preview (truncated), timestamp. Push to `ChatView` on tap. Accessed via top-right `Image(systemName: "bubble.right")` in `SoulmateView` toolbar.
- [ ] Create `TypingIndicatorView.swift` — `HStack` of 3 `Circle`s (6pt). Sequential opacity animation: `.easeInOut(duration: 0.3).delay(Double(i) * 0.2)`. Inside a bubble-shaped container (same shape as incoming messages).
- [ ] Create `SoulmateSelectionDialog.swift` — `.sheet` presented after a meetup ends (if soulmate enabled). "Did you connect with someone?" `LazyVStack` of names (opposite-sex group members with soulmate enabled). Multi-select with checkmark overlay. "Submit" button. Calls `POST /v1/me/soulmate/select`.
- [ ] Add `fetchSoulmateStatus()`, `fetchSoulmateMatches()`, `fetchSoulmateMatchDetail(id:)`, `fetchMessages(matchId:)`, `sendMessage(matchId:text:)`, `submitSoulmateSelection(meetingId:selectedUserIds:)`, `setSoulmateEnabled(_:)` to `LikemindedAPIClient.swift`.

## Phase 7 — Navigation + Motion Polish

Tab restructure, custom tab bar, animation system, material backgrounds.

### Tab restructure

- [ ] Update `AppTab` enum in `PrototypeModels.swift`: change `.talk` to `.meet` (`case meet = "Meet"`, `systemImage: "person.2.video"`). Add `case soulmate = "Soulmate"` (`systemImage: "heart.circle"`). Keep `.circles`, `.communities`, `.profile`.
- [ ] Update `RootView.swift`: replace `ReflectionPrototypeView()` with `MeetView()` in the `TabView`. Add conditional `SoulmateView()` tab — only included when `appState.soulmateEnabled == true`.
- [ ] Create `CustomTabBar.swift` — replaces system `TabView` tab bar. `HStack` of tab items. Each item: `Image(systemName:)` with `.scaleEffect(selection == tab ? 1.1 : 1.0)` + `symbolVariant(selection == tab ? .fill : .none)`. Label `Text` only on selected tab with `.transition(.opacity.combined(with: .move(edge: .bottom)).combined(with: .scale))`. Background `.ultraThinMaterial`. Tap: `withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selection = tab }`.
- [ ] Soulmate tab appear/disappear: when `soulmateEnabled` toggles, the tab bar items array changes with `.animation(.spring(response: 0.38, dampingFraction: 0.82))`.

### Motion system

- [ ] Add to `PrototypeComponents.swift` or a new `MotionConstants.swift`: `extension Animation { static let interactive = .spring(response: 0.38, dampingFraction: 0.82); static let celebratory = .spring(response: 0.50, dampingFraction: 0.70); static let snappy = .spring(response: 0.30, dampingFraction: 0.85) }`.
- [ ] Apply staggered entrance to card lists: `ForEach(Array(items.enumerated()), id: \.element.id) { index, item in ItemCard(item: item).opacity(show ? 1 : 0).offset(y: show ? 0 : 20).animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.06), value: show) }.onAppear { withAnimation { show = true } }`.
- [ ] Apply `.contentTransition(.numericText())` to member counts, group sizes, countdown values.
- [ ] Apply `.contentTransition(.opacity)` to voice status labels, placement state labels.
- [ ] Apply `.scrollTransition(.interactive, axis: .horizontal)` to all horizontal card scrolls (circles, communities).
- [ ] Apply `.background(.regularMaterial)` to: custom tab bar, chat composer, onboarding wizard container, any `.sheet` content.
- [ ] Apply `matchedGeometryEffect` for circle card → detail: `@Namespace` in `CirclesPrototypeView`, `.matchedGeometryEffect(id: circle.id, in: namespace)` on both the card and the detail hero.
- [ ] Apply `.sensoryFeedback(.success, trigger:)` to: RSVP toggle, placement accept/swap/defer, soulmate match, soulmate selection submit.

## Phase 8 — Docs + Validation

Update docs to match shipped product. Run all graders.

- [ ] Update `app-design-language.md` — new tabs: Meet (RSVP + upcoming/past meets), Circles (your circle + available + concern), Communities (backend catalog + join), Profile (voice interview + signals + interests + onboarding), Soulmate (opt-in matches + chat). New copy rules: one subtitle per screen, model prose in Profile only, meetup info in Meet only, interest tags in Communities and Soulmate match detail only.
- [ ] Update `product-direction.md` — add: AI-driven meetup flow (RSVP → group formation → host selection → scheduled video call), circles vs communities contrast (personality vs interest, Sunday vs Saturday), soulmate feature (opt-in, post-meet mutual selection, chat), hidden placement signals, onboarding before interview.
- [ ] Update `goal.json` — replace MVP placement loop goal with redesign goal. Update `deterministic_graders` to include new smoke test coverage. Update `done_criteria` to reflect Phase 3-8 completion.
- [ ] Update `goal.template.json` to match `goal.json` structure.
- [ ] Run `workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs lint` — must pass with no errors.
- [ ] Update `npm run check` script in `package.json` — add new backend files to the syntax check chain: `services/api/src/lib/scheduling.js`, `services/api/src/lib/livekit.js`.
- [ ] Update `npm run smoke:mvp` (`script/smoke_mvp.js`) — add test coverage for: `GET /v1/me/circles`, `GET /v1/circles/:id`, `POST /v1/me/circles/concern`, `GET /v1/communities`, `POST /v1/communities/:id/join`, `GET /v1/me/communities`, `POST /v1/meetings/rsvp`, `GET /v1/meetings/upcoming`, `POST /v1/me/soulmate/enable`, `POST /v1/me/soulmate/select`, `GET /v1/me/soulmate/matches`, `GET /v1/me/soulmate/matches/:id`, `POST /v1/me/soulmate/matches/:id/messages`.
- [ ] `npm run verify:release-config` — add LiveKit env var checks (`LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL`) to `script/verify_release_config.js`.
- [ ] `npm run verify:goal` — passes with updated `goal.json`.
- [ ] `./script/build_and_run.sh --verify` — builds and launches with new tab structure, LiveKit dependency, new views.
- [ ] Manual: onboarding wizard flows into voice interview.
- [ ] Manual: Profile shows voice orb + trait bars + interests.
- [ ] Manual: Circles shows your circle + available circles + concern button.
- [ ] Manual: Meet shows RSVP toggles + upcoming meets.
- [ ] Manual: Communities shows backend-driven catalog.
- [ ] Manual: Soulmate toggle shows/hides tab. Post-meet dialog works. Chat works.

## Phase 9 — External TestFlight Readiness (after redesign complete)

- [ ] Create Neon/Postgres database and set `DATABASE_URL`.
- [ ] Create Render web service from `render.yaml`.
- [ ] Set production env vars: `SESSION_SECRET`, `OPENAI_API_KEY`, `OPENAI_REALTIME_MODEL`, `OPENAI_REALTIME_VOICE`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL`, `APPLE_BUNDLE_ID`, `APPLE_CLIENT_ID`, `APPLE_AUTH_BYPASS=0`.
- [ ] Provision LiveKit server (self-hosted or LiveKit Cloud). Set `LIVEKIT_URL` to the WebSocket endpoint.
- [ ] Configure Apple Developer bundle id `com.likeminded.app`.
- [ ] Enable Sign in with Apple capability for the app id.
- [ ] Configure App Store Connect/TestFlight metadata and privacy policy.
- [ ] Add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to `Info.plist` — required for LiveKit video + OpenAI Realtime audio.
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
- [ ] Group video call joins with camera on.
- [ ] A second tester cannot access the first tester's profile, placement, or chat.

## Deferred

- Push notifications.
- Subscriptions and entitlements.
- Advanced moderation/report/block flows.
- Offline meeting coordination (restaurant/cafe bookings).
- AI transcript analysis (group dynamics, host performance, profile signal updates).
- Same-sex Soulmate.
- Community-created content/feeds.
- Host volunteer path.
- Account deletion flow (required before wider beta).
