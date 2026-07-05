# Validation — Likeminded Native Screen Audit

> Per-screen runtime evidence ledger for the iOS and macOS apps.
> **Control-status owner: `validation/<platform>/*.json` only.** Do not add sibling `.md` ledgers.
> Regenerate this index with `node validation/_generate.js` (never overwrites existing JSON evidence).

## Status summary

| Platform | Screens | Controls | Pass | Fail | Blocked | Pending | Flagged stubs |
|---|---|---|---|---|---|---|---|
| iOS  | 23 | 76 | 44 | 6 | 5 | 21 | 6 |
| macOS | 22 | 105 | 79 | 0 | 2 | 24 | 24 |

_Index regenerated from on-disk JSON._

## iOS screens

| # | Screen | Mockup | Controls | Status |
|---|---|---|---|---|
| 1 | [Auth Gate (Sign in with Apple)](ios/01-auth-gate.json) | `mockups/ios/01-04-onboarding-voice-meet-soulmate.png` | 2 | partial |
| 2 | [Onboarding Wizard (name → gender → DOB → city → pincode)](ios/02-onboarding.json) | `mockups/ios/01-04-onboarding-voice-meet-soulmate.png` | 7 | pending |
| 3 | [Profile (empty — voice interview hero)](ios/03-profile-empty.json) | `mockups/ios/01-04-onboarding-voice-meet-soulmate.png` | 2 | partial |
| 4 | [Profile (populated — signals + interests + update)](ios/04-profile-populated.json) | `mockups/ios/17-20-profile-community-settings.png` | 5 | fail |
| 5 | [Profile (re-interview prompt when concernFlag set)](ios/05-profile-concern.json) | _(none)_ | 1 | pending |
| 6 | [Voice Profile Session Sheet](ios/06-voice-session-sheet.json) | `mockups/ios/01-04-onboarding-voice-meet-soulmate.png` | 3 | pass |
| 7 | [Meet (RSVP + upcoming + past)](ios/07-meet.json) | `mockups/ios/05-08-circles-meet-communities.png` | 7 | fail |
| 8 | [Past Meet Detail (recap)](ios/08-past-meet-detail.json) | `mockups/ios/09-12-meet-video-postmeet.png` | 3 | pending |
| 9 | [Group Video Call (LiveKit)](ios/09-group-video-call.json) | `mockups/ios/09-12-meet-video-postmeet.png` | 3 | partial |
| 10 | [Circles (your circle + available + concern)](ios/10-circles.json) | `mockups/ios/05-08-circles-meet-communities.png` | 6 | fail |
| 11 | [Circle Detail (fullScreenCover)](ios/11-circle-detail.json) | `mockups/ios/05-08-circles-meet-communities.png` | 3 | fail |
| 12 | [Communities (browse + search)](ios/12-communities.json) | `mockups/ios/05-08-circles-meet-communities.png` | 3 | partial |
| 13 | [Community Detail](ios/13-community-detail.json) | `mockups/ios/13-16-soulmate-chat.png` | 3 | fail |
| 14 | [Soulmate (overview + matches)](ios/14-soulmate.json) | `mockups/ios/13-16-soulmate-chat.png` | 4 | partial |
| 15 | [Soulmate Match Detail](ios/15-soulmate-match-detail.json) | `mockups/ios/13-16-soulmate-chat.png` | 3 | pass |
| 16 | [Chat (match thread)](ios/16-chat.json) | `mockups/ios/13-16-soulmate-chat.png` | 3 | pass |
| 17 | [Conversations List](ios/17-conversations.json) | `mockups/ios/13-16-soulmate-chat.png` | 1 | pass |
| 18 | [Soulmate Selection Dialog (post-meet)](ios/18-soulmate-selection.json) | _(none)_ | 2 | pending |
| 19 | [Notifications + Activity](ios/19-notifications.json) | _(none)_ | 3 | pass |
| 20 | [Settings](ios/20-settings.json) | `mockups/ios/17-20-profile-community-settings.png` | 7 | partial |
| 21 | [Privacy Policy Sheet](ios/21-settings-privacy.json) | _(none)_ | 1 | pass |
| 22 | [Settings Info Sheet (How it works / Help & FAQ)](ios/22-settings-info.json) | _(none)_ | 1 | pass |
| 23 | [Contact Support Sheet](ios/23-settings-support.json) | _(none)_ | 3 | pass |

## macOS screens

| # | Screen | Mockup | Controls | Status |
|---|---|---|---|---|
| 1 | [Welcome / Sign in with Apple](macos/01-welcome.json) | `mockups/macos/01-04-auth-meet-circles-profile.png` | 1 | partial |
| 2 | [Meet Overview](macos/02-meet-overview.json) | `mockups/macos/01-04-auth-meet-circles-profile.png` | 6 | pass |
| 3 | [Circles Room](macos/03-circles-room.json) | `mockups/macos/01-04-auth-meet-circles-profile.png` | 2 | pass |
| 4 | [Circle Detail](macos/04-circle-detail.json) | `mockups/macos/17-20-profile-onboarding-detail-settings.png` | 3 | pass |
| 5 | [Profile Edit (living profile read-only)](macos/05-profile-edit.json) | `mockups/macos/09-12-profile-soulmate-discover-detail.png` | 3 | pass |
| 6 | [Chat (Chats, compact:false)](macos/06-chat.json) | `mockups/macos/05-08-chat-communities-detail-recap.png` | 7 | partial |
| 7 | [Communities Browse](macos/07-communities-browse.json) | `mockups/macos/05-08-chat-communities-detail-recap.png` | 4 | pass |
| 8 | [Community Detail](macos/08-community-detail.json) | `mockups/macos/05-08-chat-communities-detail-recap.png` | 8 | partial |
| 9 | [Community Members](macos/09-community-members.json) | `mockups/macos/13-16-community-members-event-messages-activity.png` | 4 | pass |
| 10 | [Create Event](macos/10-create-event.json) | `mockups/macos/22-create-event.png` | 9 | pass |
| 11 | [Meet Recap](macos/11-meet-recap.json) | `mockups/macos/05-08-chat-communities-detail-recap.png` | 3 | pass |
| 12 | [My Profile (view)](macos/12-my-profile.json) | `mockups/macos/09-12-profile-soulmate-discover-detail.png` | 5 | partial |
| 13 | [Profile Onboarding](macos/13-profile-onboarding.json) | `mockups/macos/17-20-profile-onboarding-detail-settings.png` | 5 | partial |
| 14 | [Profile Signals (myProfile editing:true)](macos/14-profile-signals.json) | `mockups/macos/09-12-profile-soulmate-discover-detail.png` | 1 | pass |
| 15 | [Soulmate Overview](macos/15-soulmate-overview.json) | `mockups/macos/09-12-profile-soulmate-discover-detail.png` | 2 | pass |
| 16 | [Soulmate Discover](macos/16-soulmate-discover.json) | `mockups/macos/09-12-profile-soulmate-discover-detail.png` | 4 | pass |
| 17 | [Soulmate Detail](macos/17-soulmate-detail.json) | `mockups/macos/09-12-profile-soulmate-discover-detail.png` | 2 | pass |
| 18 | [Messages (compact chat)](macos/18-messages.json) | `mockups/macos/13-16-community-members-event-messages-activity.png` | 7 | partial |
| 19 | [Notifications + Activity](macos/19-notifications.json) | `mockups/macos/13-16-community-members-event-messages-activity.png` | 5 | pass |
| 20 | [Settings (Soulmate)](macos/20-settings-soulmate.json) | `mockups/macos/17-20-profile-onboarding-detail-settings.png` | 16 | partial |
| 21 | [Meet Video Call (LiveKit parity — mockup 21)](macos/21-meet-video-call.json) | `mockups/macos/21-meet-video-call.png` | 4 | partial |
| 22 | [Create Community](macos/22-create-community.json) | `mockups/macos/05-08-chat-communities-detail-recap.png` | 4 | pass |

## Blocked locally (infrastructure-dependent)

- **Sign in with Apple** (iOS auth gate, macOS welcome) — needs real Apple ID / TestFlight creds
- **LiveKit group video call** (iOS GroupVideoCallView, macOS meet video call mockup 21) — needs LIVEKIT_URL/API_KEY/SECRET + provisioned server

## Conventions

- Each screen has one ledger: `<platform>/<id>.json`.
- Control `result` ∈ {`pass`, `fail`, `blocked`, `pending`}.
- Screen `source_hash`: sha256 prefix of `source_files` (refresh: `npm run ledger:refresh-hashes`).
- Per control: `last_tested_at`, `tested_source_hash`, `last_test_method` — set by CUA/manual via `ledger_record_control.js` / `ledger_stamp_screen.js`.
- `pass` is **stale** when `tested_source_hash` ≠ current `source_hash`; list with `npm run ledger:stale`.
- Screens with no mockup reference set `mockup_missing: true`.
- Screenshots land in `<platform>/screenshots/<NN>-<name>.png` or `output/validation/macos-screens/`.
