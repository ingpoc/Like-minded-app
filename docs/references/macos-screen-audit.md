# macOS Screen Audit

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This file records macOS screen validation evidence only.

## Evidence

- Mockups: `mockups/macos/01-04-auth-meet-circles-profile.png` through `mockups/macos/17-20-profile-onboarding-detail-settings.png`.
- Current captures: `output/validation/macos-screens/`.
- Capture command: `npm run verify:macos-screens`.
- Backend seed command: `npm run seed:validation-data`.
- Last local evidence: `npm run check` passed, `npm run reset:validation-data` passed, `npm run remove:validation-data` passed, and `npm run verify:macos-screens` captured all 20 screens while owning validation API setup and cleanup.

## Blocking Functional Finding

The macOS app is not backend-backed yet. `apps/ios-macos/Sources/LikemindedMac` renders static prototype data and does not call the API. `MacBackendConfig` exists, but no macOS screen uses it for profile, circles, communities, meetings, soulmate, messages, or notifications. Backend validation data can now be seeded, but the current macOS UI cannot prove that data is rendered from the backend.

## Screen Findings

| # | Screen | Capture | Status | Findings |
|---|---|---|---|---|
| 1 | Auth / Welcome | `welcome.png` | Mismatch | Layout is left-panel plus separate header, not the mockup's integrated two-column welcome. The bottom dock appears before auth. Sign in button has default focus ring in capture. |
| 2 | Meet Overview | `meetOverview.png` | Mismatch | Upcoming meetup hero is visually empty/washed out and text is compressed at the bottom. Mockup expects a dark polished card with readable host, participant count, join button, and distinct past meet rows. |
| 3 | Circles | `circlesRoom.png` | Partial | Main room and available cards exist, but concern card is too small and the mockup's browse action, high-fit chip, next-meet metadata, and richer landscape treatment are reduced. |
| 4 | Profile Exists | `profileEdit.png` | Mismatch | Current screen shows sliders/edit controls. Mockup expects profile overview with personal metadata, interests, reflection, and a signal hero card. |
| 5 | Chat | `chat.png` | Partial | Conversation structure exists, but message density, search/new conversation controls, contact avatars, header actions, and timeline labels do not match the mockup. |
| 6 | Communities Browse | `communitiesBrowse.png` | Mismatch | Cards are compressed into horizontal bands and overlap the create card visually. Mockup expects a 2x3 grid with search, filters, joined badges, photos/gradients, and spacious cards. |
| 7 | Community Detail | `communityDetail.png` | Mismatch | Current detail lacks the large full-width scenic hero, joined/menu controls, tab strip, attendee avatars, and fit/sidebar card from the mockup. |
| 8 | Meet Recap | `meetRecap.png` | Partial | Core stats and connected people exist. Missing top themes, private note input, and momentum card visual hierarchy from mockup. |
| 9 | My Profile | `myProfile.png` | Partial | Overview exists but uses placeholder avatar initial, compact cards, and no portrait. Mockup expects richer profile card, retake voice action, larger signal grid, and decorative orb panel. |
| 10 | Soulmate Overview | `soulmateOverview.png` | Partial | Enable card and orb exist, but mockup expects large heart field, toggle state, clearer privacy rows, and stronger visual balance. |
| 11 | Soulmate Discover | `soulmateDiscover.png` | Mismatch | Current cards are narrow gradient placeholders. Mockup expects person photos, filter sidebar, interest chips, distance, active flags, and heart affordances. |
| 12 | Soulmate Detail | `soulmateDetail.png` | Mismatch | Current layout lacks portrait/gallery, online status, right compatibility card, shared-interest card, and full pass/like/message button row. |
| 13 | Community Members | `communityMembers.png` | Mismatch | Current sidebar and member list are simplified. Mockup expects search, filters, avatars, host badge, status metadata, and richer left community panel. |
| 14 | Create Event | `createEvent.png` | Partial | Form exists, but event type cards, preview hierarchy, date/time controls, participant avatars, and create button placement differ from mockup. |
| 15 | Messages | `messages.png` | Partial | Same structural gap as Chat: missing search/filter chips, composed sidebar rows, header actions, and richer avatars. |
| 16 | Notifications / Activity | `notifications.png` | Partial | Two-column structure exists, but mockup expects notification filters, richer avatar rows, activity tabs, dates, and notification enable card. |
| 17 | Profile Onboarding | `profileOnboarding.png` | Partial | Stepper and form exist, but mockup expects larger intro copy, privacy card, stronger orb callout, and a more spacious card hierarchy. |
| 18 | Profile Signals | `profileSignals.png` | Partial | Same as My Profile, but missing portrait, stats, language/about cards, and larger signal layout. |
| 19 | Circle Detail | `circleDetail.png` | Mismatch | Current screen reuses Jazz community content under the Circles tab. Mockup expects The Thinkers' Room circle detail with join/message/mod controls, discussions, values, moderators, and circle-specific copy. |
| 20 | Settings / Soulmate | `settingsSoulmate.png` | Partial | Settings shell exists, but mockup expects prominent Soulmate hero, toggle row, intentional/private match cards, discovery dropdown, visibility radio group, and better spacing. |

## Required Fix Order

1. Wire macOS to backend-backed state for auth bypass, profile, circles, communities, meetings, soulmate, messages, and notifications, or clearly mark the target as prototype-only.
2. Fix the highest-impact layout mismatches: Meet Overview, Communities Browse, Community Detail, Soulmate Discover, Soulmate Detail, and Circle Detail.
3. Replace placeholder gradient/person cards with real generated or backend-provided image fields before claiming visual parity.
4. Re-run `npm run seed:validation-data`, `npm run verify:macos-screens`, and compare the regenerated contact sheet before Phase 8 validation closeout.
