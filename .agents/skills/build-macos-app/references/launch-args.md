# Launch arguments (`open --args`)

## Auth / dev flags

| Flag | Purpose |
| --- | --- |
| `--likeminded-reset-auth-session` | Wipe cached session |
| `--likeminded-dev-auth-bypass` | Skip Apple Sign-In (local-auth mode) |
| `--likeminded-dev-auth-token <token>` | Pre-seed profile token |
| `--likeminded-dev-auth-name "<Name>"` | Pre-seed display name |
| `--likeminded-dev-profile-empty` | Empty profile (onboarding) |
| `--likeminded-validation-welcome` | Welcome validation mode |

## `--mac-screen` values (22)

```
welcome, meetOverview, circlesRoom, profileEdit, chat, communitiesBrowse,
communityDetail, meetRecap, myProfile, soulmateOverview, soulmateDiscover,
soulmateDetail, communityMembers, createEvent, createCommunity, messages,
notifications, profileOnboarding, profileSignals, circleDetail,
settingsSoulmate, meetVideoCall
```

## Default validation recipe (signed-in screens)

```bash
open -F -n .build/macos/Build/Products/Debug/LikemindedMac.app --args \
  --likeminded-reset-auth-session \
  --likeminded-dev-auth-bypass \
  --likeminded-dev-auth-token "${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}" \
  --likeminded-dev-auth-name "${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}" \
  --mac-screen soulmateDiscover
```

## Hard rules

| Rule | Detail |
| --- | --- |
| Arg order | Put `--mac-screen <name>` **before** profile/dev flags when both needed — wrong order → no capturable window |
| Post-sign-in | `MacRootView` must re-apply `--mac-screen` after dev auth (`onChange(of: isSignedIn)`) |
| Welcome | No dev bypass: `--likeminded-reset-auth-session --mac-screen welcome --likeminded-validation-welcome` |
| Settings pane | `--mac-screen settingsSoulmate --mac-settings-pane howItWorks` only — dual iOS-style flags can open 0 windows |
| Communities | `fetchCommunities()` needs **both** catalog and joined API fetches for the grid |

## Screen-specific

| Screen | Notes |
| --- | --- |
| `welcome` | Real Apple Sign-In blocked locally — layout capture + `blocked` control in ledger |
| `settingsSoulmate` | Modals for sign-out/delete — CUA uses `--max 80` (see macos-cua skill) |
| `meetVideoCall` | LiveKit join; preview tiles when `POST /v1/meetings/:id/join` fails without `LIVEKIT_*`. CUA mute/leave need `--max 80` (`MACOS_CUA_MAX_MODAL`) — call controls sit past default AX budget. |
