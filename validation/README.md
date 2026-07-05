# Validation index

**Not a status owner.** Pass/fail/stale live in `validation/<platform>/*.json` only.

| Need | Command |
|------|---------|
| Route | `npm run goal:next` |
| One screen | `npm run ledger:screen -- --platform ios\|macos --screen <id> --section ui\|controls\|all` |
| Gap audit (all open) | `npm run ledger:open` |
| Stale after edits | `npm run ledger:stale` |

Regenerate this link list: `node validation/_generate.js` (never overwrites JSON evidence).

## iOS (26)

- [Auth Gate (Sign in with Apple)](ios/01-auth-gate.json)
- [Profile Onboarding (3-step: About you → Voice profile → Join first circle)](ios/02-onboarding.json)
- [Profile (empty — voice interview hero)](ios/03-profile-empty.json)
- [Profile (populated — signals + interests + update)](ios/04-profile-populated.json)
- [Profile (re-interview prompt when concernFlag set)](ios/05-profile-concern.json)
- [Voice Profile Session Sheet](ios/06-voice-session-sheet.json)
- [Meet (RSVP + upcoming + past)](ios/07-meet.json)
- [Past Meet Detail (recap)](ios/08-past-meet-detail.json)
- [Group Video Call (LiveKit)](ios/09-group-video-call.json)
- [Circles (your circle + available + concern)](ios/10-circles.json)
- [Circle Detail (fullScreenCover)](ios/11-circle-detail.json)
- [Communities (browse + search)](ios/12-communities.json)
- [Community Detail](ios/13-community-detail.json)
- [Soulmate (overview + matches)](ios/14-soulmate.json)
- [Soulmate Match Detail](ios/15-soulmate-match-detail.json)
- [Chat (match thread)](ios/16-chat.json)
- [Conversations List](ios/17-conversations.json)
- [Soulmate Selection Dialog (post-meet)](ios/18-soulmate-selection.json)
- [Notifications + Activity](ios/19-notifications.json)
- [Settings](ios/20-settings.json)
- [Privacy Policy Sheet](ios/21-settings-privacy.json)
- [Settings Info Sheet (How it works / Help & FAQ)](ios/22-settings-info.json)
- [Contact Support Sheet](ios/23-settings-support.json)
- [Create Community](ios/24-create-community.json)
- [Community Members](ios/25-community-members.json)
- [Create Event](ios/26-create-event.json)

## macOS (22)

- [Welcome / Sign in with Apple](macos/01-welcome.json)
- [Meet Overview](macos/02-meet-overview.json)
- [Circles Room](macos/03-circles-room.json)
- [Circle Detail](macos/04-circle-detail.json)
- [Profile Edit (living profile read-only)](macos/05-profile-edit.json)
- [Chat (Chats, compact:false)](macos/06-chat.json)
- [Communities Browse](macos/07-communities-browse.json)
- [Community Detail](macos/08-community-detail.json)
- [Community Members](macos/09-community-members.json)
- [Create Event](macos/10-create-event.json)
- [Meet Recap](macos/11-meet-recap.json)
- [My Profile (view)](macos/12-my-profile.json)
- [Profile Onboarding](macos/13-profile-onboarding.json)
- [Profile Signals (myProfile editing:true)](macos/14-profile-signals.json)
- [Soulmate Overview](macos/15-soulmate-overview.json)
- [Soulmate Discover](macos/16-soulmate-discover.json)
- [Soulmate Detail](macos/17-soulmate-detail.json)
- [Messages (compact chat)](macos/18-messages.json)
- [Notifications + Activity](macos/19-notifications.json)
- [Settings (Soulmate)](macos/20-settings-soulmate.json)
- [Meet Video Call (LiveKit parity — mockup 21)](macos/21-meet-video-call.json)
- [Create Community](macos/22-create-community.json)

Conventions: `docs/workflows/validation.md`.
