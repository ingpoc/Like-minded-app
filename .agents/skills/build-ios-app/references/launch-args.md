# Launch arguments (simctl / validation)

## Auth / dev flags

| Flag | Purpose |
| --- | --- |
| `--likeminded-reset-auth-session` | Wipe cached session |
| `--likeminded-dev-auth-bypass` | Skip Apple Sign-In (local-auth API) |
| `--likeminded-dev-auth-token <token>` | Pre-seed profile token |
| `--likeminded-dev-auth-name "<Name>"` | Pre-seed display name |
| `--likeminded-force-onboarding` | Onboarding flow |
| `--likeminded-start-profile` | Post-auth profile tab |
| `--likeminded-dev-voice-placement` | Voice placement loop (dev) |

## Deep-link flags (`--likeminded-start-*`)

Mapped per ledger screen in `cross_platform_screen_validate.sh` → `ios_launch_args_for_screen`. Common:

| Flag | Typical screen |
| --- | --- |
| `--likeminded-start-circles` | circles, circle-detail |
| `--likeminded-start-communities` | communities, community-detail |
| `--likeminded-start-soulmate` | soulmate, conversations |
| `--likeminded-start-chat` | chat |
| `--likeminded-start-settings` | settings |
| `--likeminded-start-video-call` | group video call |
| `--likeminded-start-notifications` | notifications |

Full per-screen mapping lives in the script `case` block — add new screens there + `RootView.swift`.

## Default validation recipe

```bash
xcrun simctl launch --terminate-running-process <SIMULATOR_UDID> com.likeminded.app \
  --likeminded-reset-auth-session \
  --likeminded-dev-auth-bypass \
  --likeminded-dev-auth-token "${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}" \
  --likeminded-dev-auth-name "${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}" \
  --likeminded-start-chat
```

Prefer **`npm run validate:screen`** — script supplies args per ledger id.

## Auth gate (`auth-gate` / `01-auth-gate`)

`npm run validate:screen -- --screen auth-gate --platform ios` — only `--likeminded-reset-auth-session` (no dev bypass). Reference: `mockups/ios/auth-login-convergence.png`. Do **not** use `--screen auth` for the gate (that id applies dev bypass).

## build_and_run.sh modes

| Mode | Use |
| --- | --- |
| `run` | Dev: build + install + launch (no deep links) |
| `build` | Build + install only; prints `SIMULATOR_ID=` for capture scripts |
| `logs` / `debug` | Stream logs / lldb |
