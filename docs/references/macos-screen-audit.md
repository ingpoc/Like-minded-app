# macOS Screen Audit

Routing + evidence pointers only. **Status owner: `validation/macos/*.json`** (index: `validation/README.md`).

## Commands

- Prepare: `./script/macos_audit_prepare.sh [screen]`
- CUA: `./script/macos_cua_screen.sh <screen>`
- Captures: `npm run verify:macos-screens` → `output/validation/macos-screens/`
- Seed: `npm run reset:validation-data` (with `dev:api:validation`)
- One app binary: `script/macos_canonical_app.sh`

## Mockup plates

| `--mac-screen` | Plate |
|----------------|--------|
| welcome, meetOverview, circlesRoom, profileEdit | `mockups/macos/01-04-auth-meet-circles-profile.png` |
| chat, communitiesBrowse, communityDetail, meetRecap | `05-08-chat-communities-detail-recap.png` |
| myProfile, soulmateOverview, soulmateDiscover, soulmateDetail | `09-12-profile-soulmate-discover-detail.png` |
| communityMembers, createEvent, messages, notifications | `13-16-community-members-event-messages-activity.png` |
| profileOnboarding, profileSignals, circleDetail, settingsSoulmate | `17-20-profile-onboarding-detail-settings.png` |
| meetVideoCall | `21-meet-video-call.png` |
| createEvent layout | `22-create-event.png` |

## Intentional variations (do not fail controls solely for these)

Documented in git history and ledger `visual_parity.notes`. Examples: doodle covers vs photo mockups; initials not photos; chat phone/video icons muted; Mac voice retake routes to basics onboarding; tab order Communities → Soulmate → Profile.

## Historical

2026-07-02 backend connectivity resolved (real API via `MacAppState`). Phase 7.B wire-up is historical—not ledger-green. Per-control pass/fail: **JSON only**.
