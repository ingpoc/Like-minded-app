# iOS capture (ledger proof)

## Entrypoint

```bash
npm run validate:screen -- --screen <ledger-id> --platform ios
# e.g. --screen 07-meet  or  --screen 16-chat
```

Wrapper: `script/cross_platform_screen_validate.sh` — locks, API check, build, launch, screenshot.

## Flow (per screen)

1. API healthy on `:8787` with `validation-db` — **does not** restart/re-seed if already up
2. Lock `xcodebuild-ios` → build **or** install-only when binary is fresh (see below)
3. Lock `ios-sim` → `simctl launch` with screen-specific args → `sleep IOS_CAPTURE_WAIT` (default **15s**) → `simctl io screenshot`
4. PNG → `output/validation/ios-screens/<slug>.png` (fail if &lt; 10KB)
5. **Ledger closeout** (automatic): `ledger_capture_closeout.js` updates `recent_screenshot_ref`, stamps controls (`ios_screen_stamp_map.js`), syncs `flows[]`

Disable closeout: `LIKEMINDED_LEDGER_CLOSEOUT=0`. Stale batch: `LIKEMINDED_LEDGER_STALE_ONLY=1` (via `verify:ios-screens -- --stale-only`).

## Build vs install-only

| Condition | Action |
| --- | --- |
| No `.build/ios-simulator/.../Likeminded.app` or Swift/project.yml newer than binary | `build_and_run.sh build` |
| Fresh binary exists | `build_and_run.sh install` only (~2s) |
| `LIKEMINDED_FORCE_IOS_BUILD=1` | Always `build` |
| `LIKEMINDED_SKIP_IOS_BUILD=1` | Skip build **and** install (batch after upfront build) |

## Deep-link checklist (new / broken screen)

1. **`RootView` route** — every `--likeminded-start-*` maps to tab/sheet/selection (+ `initialSelection()` when tab-adjacent)
2. **Concern-flag bypass** — block profile-concern redirect during validation launches
3. **`LIKEMINDED_VALIDATION_SCREEN` UserDefaults** — when `simctl` drops args (chat, community-members, past-meet-detail patterns in app code)
4. **Explicit UDID** — from `build_and_run.sh build`; not `booted` with multiple simulators
5. **Build-only + explicit launch** — `validate:screen` does this; `build_and_run.sh run` does not
6. **Post-launch wait** — default **15s**; chat (`16-chat`) uses **30s** minimum (API message fetch). Override: `IOS_CAPTURE_WAIT=60`.
7. **Parallel wave** — Swift edits parallel OK; capture **sequential** only

## Batch wrappers

| Command | Screens |
| --- | --- |
| `npm run verify:ios-screens` | Default smoke list (15 screens) |
| `npm run verify:ios-screens -- --stale-only` | Ledger stale_pass only + stamp |
| `npm run verify:ios-screens -- 07-meet 16-chat` | Explicit list |

Each screen in batch = launch + capture only (one shared build at batch start; `LIKEMINDED_SKIP_IOS_BUILD=1` skips install too). Single `validate:screen` auto-skips xcodebuild when binary is fresh but still installs to simulator.

## Slug → PNG path

Ledger id resolved via `ios_capture_slug` (e.g. `16-chat` → `chat.png`, `07-meet` → `meet.png`).
