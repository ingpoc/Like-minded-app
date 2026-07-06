# Validation index

**Not a status owner.** Pass/fail/stale live in `validation/screens/*.json` only (schema v2).

| Need | Command |
|------|---------|
| Route | `npm run goal:next` |
| One screen | `npm run ledger:screen -- --platform ios\|macos --screen <logical-id> --section flows\|controls\|all` |
| Gap audit (open flows) | `npm run ledger:open` |
| Session brief (anti-redo) | `npm run ledger:brief` |
| One flow packet | `npm run ledger:flow -- --platform ios\|macos --screen <id> --flow <flow-id>` |
| Stale after edits | `npm run ledger:stale` |
| Apply gap backlog | `npm run ledger:apply-gaps` |
| Apply proof packets | `npm run ledger:apply-proof` |
| Production gate | `npm run verify:production-ready` |
| Migration verify | `npm run verify:ledger-migration` |

**Contract:** `production-contract.json` (TestFlight MVP scope). **Templates:** `screens/_template.*.json`. Batch gaps: `gap-flows-registry.json`.

Regenerate this link list: `node validation/_generate.js` (never overwrites JSON evidence).

## Logical screens (27)

Each file owns **both platforms** + `flows[]` (primary status) + `controls.{ios,macos}` (atomic UI).

| Screen | iOS legacy | macOS legacy | Flows |
|--------|------------|--------------|-------|
| [App shell (tabs, chrome, global navigation)](screens/app-shell.json) (`app-shell`) | — | — | 5 |
| [Auth / Sign in](screens/auth.json) (`auth`) | 01-auth-gate | 01-welcome | 7 |
| [Chat (match thread)](screens/chat.json) (`chat`) | 16-chat | 06-chat | 3 |
| [Circle Detail](screens/circle-detail.json) (`circle-detail`) | 11-circle-detail | 04-circle-detail | 10 |
| [Circles (your circle + browse + concern)](screens/circles.json) (`circles`) | 10-circles | 03-circles-room | 9 |
| [Communities (browse + search)](screens/communities.json) (`communities`) | 12-communities | 07-communities-browse | 7 |
| [Community Detail](screens/community-detail.json) (`community-detail`) | 13-community-detail | 08-community-detail | 13 |
| [Community Members](screens/community-members.json) (`community-members`) | 25-community-members | 09-community-members | 6 |
| [Conversations / Messages list](screens/conversations.json) (`conversations`) | 17-conversations | 18-messages | 7 |
| [Create Community](screens/create-community.json) (`create-community`) | 24-create-community | 22-create-community | 6 |
| [Create Event](screens/create-event.json) (`create-event`) | 26-create-event | 10-create-event | 10 |
| [Meet (RSVP + upcoming + past)](screens/meet.json) (`meet`) | 07-meet | 02-meet-overview | 5 |
| [Notifications + Activity](screens/notifications.json) (`notifications`) | 19-notifications | 19-notifications | 8 |
| [Profile Onboarding (3-step)](screens/onboarding.json) (`onboarding`) | 02-onboarding | 13-profile-onboarding | 7 |
| [Past Meet Detail / Recap](screens/past-meet-recap.json) (`past-meet-recap`) | 08-past-meet-detail | 11-meet-recap | 3 |
| [Profile (re-interview when concernFlag)](screens/profile-concern.json) (`profile-concern`) | 05-profile-concern | — | 1 |
| [Profile Edit (traits / living profile)](screens/profile-edit.json) (`profile-edit`) | — | 05-profile-edit | 3 |
| [Profile (empty — voice interview hero)](screens/profile-empty.json) (`profile-empty`) | 03-profile-empty | — | 3 |
| [Profile (populated — signals + interests)](screens/profile-populated.json) (`profile-populated`) | 04-profile-populated | 12-my-profile | 11 |
| [Profile Signals (share / edit mode)](screens/profile-signals.json) (`profile-signals`) | — | 14-profile-signals | 1 |
| [Settings (account, privacy, support)](screens/settings.json) (`settings`) | 20-settings | 20-settings-soulmate | 19 |
| [Soulmate Discover](screens/soulmate-discover.json) (`soulmate-discover`) | — | 16-soulmate-discover | 5 |
| [Soulmate Match Detail](screens/soulmate-match.json) (`soulmate-match`) | 15-soulmate-match-detail | 17-soulmate-detail | 6 |
| [Soulmate Overview](screens/soulmate-overview.json) (`soulmate-overview`) | 14-soulmate | 15-soulmate-overview | 7 |
| [Soulmate Selection (post-meet)](screens/soulmate-selection.json) (`soulmate-selection`) | 18-soulmate-selection | — | 2 |
| [Group Video Call (LiveKit)](screens/video-call.json) (`video-call`) | 09-group-video-call | 21-meet-video-call | 7 |
| [Voice Profile Session Sheet](screens/voice-session.json) (`voice-session`) | 06-voice-session-sheet | — | 3 |

Legacy ledgers archived at `validation/_legacy/{ios,macos}/`.

Conventions: `docs/workflows/validation.md`.
