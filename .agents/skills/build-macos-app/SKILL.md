---
name: build-macos-app
description: Likeminded macOS build/run/validate skill for the SwiftUI LikemindedMac target in apps/ios-macos. Use when building, running, signing, or screen-validating the macOS surface against mockups/macos — covers xcodegen, xcodebuild for macOS, open with --mac-screen deep-link args, validation-data seeding, screen-capture, and parity checks across the welcome/meet/circles/profile/chat/communities/soulmate/settings flow set.
---

# Build macOS App — Likeminded

Project-specific skill for the **macOS SwiftUI surface** of the Like-minded-app:
the `LikemindedMac` target in `apps/ios-macos/project.yml`, source at
`apps/ios-macos/Sources/LikemindedMac/`.

## When to Use This Skill

Apply when working on the **macOS app** (`LikemindedMac`) for any of:

- Building, running, or debugging the macOS target natively (not Catalyst)
- Adding or modifying SwiftUI views/scenes under `Sources/LikemindedMac/`
- Wiring the macOS client to the Node API (`LIKEMINDED_API_BASE_URL` contract)
- Window, toolbar, menu, sidebar layout specific to the desktop surface
- Validation: capturing screenshots of all 20 `--mac-screen` flows and
  comparing against `mockups/macos/`
- macOS-specific design system / component work

**Skip this skill** for iOS simulator work (use `build-ios-app`), backend-only
changes, schema work, or non-visual infra changes — they don't need a Mac
build or mockup comparison.

## Context (lazy)

1. `npm run goal:next` — if macOS track open, note screen from output or `ledger:stale`.
2. **One** `validation/macos/<screen>.json` via `npm run ledger:screen` + `source_files` for the touched screen.
3. **One** mockup from ledger `mockup_ref` — not the whole `mockups/macos/` dir.
4. Skip `GOAL.md`, full `PROGRESS.md`, and `project_context` unless boundary dispute.

## Project Layout (macOS-relevant)

```
apps/ios-macos/
  project.yml                         # XcodeGen owner — iOS + macOS targets
  Likeminded.xcodeproj/               # generated, do NOT hand-edit
  Sources/LikemindedMac/
    LikemindedMacApp.swift            # app entry / scene
    MacRootView.swift                 # root layout
    MacScreens.swift                  # --mac-screen switch
    MacAppState.swift                 # auth + placement state
    MacPrototypeData.swift
    MacDesignSystem.swift             # macOS-only colors/typography/materials
    LikemindedAPIClient.swift         # HTTP client — same backend contract
    Models.swift
mockups/macos/                        # montage references:
  01-04-auth-meet-circles-profile.png
  05-08-chat-communities-detail-recap.png
  09-12-profile-soulmate-discover-detail.png
  13-16-community-members-event-messages-activity.png
  17-20-profile-onboarding-detail-settings.png
  21-meet-video-call.png
  22-create-event.png
```

Bundle id: `com.likeminded.mac`. Deployment target: **macOS 15.0**. No LiveKit
dependency on this target. `GENERATE_INFOPLIST_FILE: YES`. No entitlements
file declared in `project.yml` for the Mac target (Apple Sign-In is iOS-only).

## Build / Run / Debug Workflow

### 0. Prerequisites
- The API server must be running for in-app auth + placement flows. Verify:
  ```
  curl -s http://127.0.0.1:8787/health
  ```
- For realistic validation data, use the validation lane (see §Validation).
- XcodeGen must be installed: `brew install xcodegen`.

### 1. Regenerate the Xcode project after any `project.yml` change
```
(cd apps/ios-macos && xcodegen generate)
```
Never hand-edit `Likeminded.xcodeproj`. The spec is the source of truth.

### 2. Build only
```
xcodebuild \
  -project apps/ios-macos/Likeminded.xcodeproj \
  -scheme LikemindedMac \
  -destination 'platform=macOS' \
  -derivedDataPath .build/macos \
  build
```
App lands at `.build/macos/Build/Products/Debug/LikemindedMac.app`.

### 3. Run the built app (native open, not simulator)
```
open -F -n .build/macos/Build/Products/Debug/LikemindedMac.app
```
- `-F` launches a fresh instance even if one is running.
- `-n` opens a new instance.
- Use `--args …` to pass launch arguments (see §Launch Arguments).

### 4. Terminate / restart (use lock holder)

During validation, never bare `pkill -x LikemindedMac` from parallel agents — it kills another agent's capturable window.

```
./script/cross_platform_validation_lock.sh with_lock macos-app bash -c '
  source script/macos_canonical_app.sh
  macos_kill_if_lock_holder
'
```

Only the lock holder should kill/relaunch. Set `LIKEMINDED_HOLDS_MACOS_APP_LOCK=1` when your script owns `macos-app`.

### 5. Stream runtime logs
```
log stream --level debug --style compact --predicate 'process == "LikemindedMac"'
```

## Launch Arguments (project-specific)

The macOS app reads these `open --args` flags. The most important is
`--mac-screen <name>`, which deep-links the app to a specific screen flow
for validation:

Auth / dev:
- `--likeminded-reset-auth-session` — wipe cached session
- `--likeminded-dev-auth-bypass` — skip Apple Sign-In (local-auth mode)
- `--likeminded-dev-auth-token <token>` — pre-seed a profile token
- `--likeminded-dev-auth-name "<Name>"` — pre-seed display name

Deep-link screen (one of):
```
welcome, meetOverview, circlesRoom, profileEdit, chat, communitiesBrowse,
communityDetail, meetRecap, myProfile, soulmateOverview, soulmateDiscover,
soulmateDetail, communityMembers, createEvent, messages, notifications,
profileOnboarding, profileSignals, circleDetail, settingsSoulmate
```

Example (deep-link to soulmate discover with seeded validation profile):
```
open -F -n .build/macos/Build/Products/Debug/LikemindedMac.app --args \
  --likeminded-reset-auth-session --likeminded-dev-auth-bypass \
  --likeminded-dev-auth-token validation-gurusharan --likeminded-dev-auth-name "Gurusharan Gupta" \
  --mac-screen soulmateDiscover
```

**Launch arg order matters.** Put `--mac-screen <name>` **before** profile/dev flags when both are needed (e.g. empty onboarding):
```
--mac-screen profileOnboarding --likeminded-dev-profile-empty
```
Wrong order can yield **no capturable window**.

**Post-sign-in re-apply.** `MacRootView` must re-apply `--mac-screen` after dev auth completes (`onChange(of: isSignedIn)`); otherwise notifications/settings deep links land on Profile.

**Screen-specific recipes:**
- **Welcome (auth gate):** no dev bypass — `--likeminded-reset-auth-session --mac-screen welcome --likeminded-validation-welcome`
- **Settings how-it-works:** `--mac-screen settingsSoulmate --mac-settings-pane howItWorks` only (dual iOS-style flags + pane can open 0 windows)
- **Communities browse:** catalog vs joined are separate API fetches in `MacAppState.fetchCommunities()` — both must succeed for the grid

## Validation (against `mockups/macos/`)

**Mockup compare before controls.** Capture the live app window, open the
matching plate in `mockups/macos/`, and classify differences as **match**,
**intentional variation**, or **gap** before CUA or ledger pass/fail. Mockups
are montages and often diverge (seeded roster size, no photos, tab order
Soulmate before Profile, planned call chrome, honest empty Groups). Record
variations in ledger `visual_parity.notes` — do not fail controls solely for those.

Per AGENTS.md: before claiming seamless behavior, point both apps at
`data/validation-db` with the validation API and seeded data.

The repo ships an end-to-end script that captures **all 20** screen flows:
```
./script/verify_macos_screens.sh
```
What it does, in order:
1. Kills any prior app instance + frees port `${PORT:-8787}`.
2. Starts the validation API (`script/run_validation_api.sh`) and waits for `/health`.
3. `npm run reset:validation-data` — seeds `data/validation-db`.
4. `(cd apps/ios-macos && xcodegen generate)`.
5. `xcodebuild … -scheme LikemindedMac -destination 'platform=macOS' build` into `.build/macos`.
6. For each of the 20 screens: lock `macos-app`, `macos_open_with_args … --mac-screen <name>`,
   activate + resize the window to 1200×760 at {80,80} via AppleScript,
   then `screencapture -x -l <window_id>` the Likeminded window only
   (filtered by owner + size through CoreGraphics).
7. `npm run remove:validation-data` cleanup on exit.
8. Writes PNGs to `output/validation/macos-screens/<screen>.png`.

Then compare each capture against the matching montage in `mockups/macos/`:

| Screens (`--mac-screen`) | Mockup file |
|---|---|
| welcome, meetOverview, circlesRoom, profileEdit | `01-04-auth-meet-circles-profile.png` |
| chat, communitiesBrowse, communityDetail, meetRecap | `05-08-chat-communities-detail-recap.png` |
| myProfile, soulmateOverview, soulmateDiscover, soulmateDetail | `09-12-profile-soulmate-discover-detail.png` |
| communityMembers, messages, notifications | `13-16-community-members-event-messages-activity.png` |
| createEvent | `22-create-event.png` |
| profileOnboarding, profileSignals, circleDetail, settingsSoulmate | `17-20-profile-onboarding-detail-settings.png` |
| meet video call (extra) | `21-meet-video-call.png` |

Ad-hoc single-screen capture (without the full script):
```
# build + open with the desired deep-link, then capture the window:
screencapture -x -l "$(python3 -c 'import Quartz; \
  ws=Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionOnScreenOnly|Quartz.kCGWindowListExcludeDesktopElements,Quartz.kCGNullWindowID); \
  print(next((w["kCGWindowNumber"] for w in ws if (w.get("kCGWindowOwnerName") or "").startswith("Likeminded") and w.get("kCGWindowBounds",{}).get("Width",0)>400), ""))')" \
  output/validation/macos-screens/soulmateDiscover.png
```

## Post-parallel validation batch

After **parallel** UI work across multiple ledger screens, do **not** run CUA or
capture from multiple agents at once (port `:8787` and `LikemindedMac` instance
fights produce empty AX trees and wrong screenshots).

Use one orchestrated pass:
```
npm run macos:validation-batch              # full closeout
npm run macos:validation-batch -- --stale-only --cua-only   # ledger stale_pass only
npm run macos:cua-reproof                   # alias for stale-only CUA
```
Or: `./script/macos_validation_batch.sh` with the same flags.

What it does:
1. Sole owner of validation API on `:8787` (frees port if needed)
2. `npm run reset:validation-data` once (skipped in `--cua-only` when API already up)
3. `./script/verify_macos_screens.sh` — captures at 1200×760 (`--stale-only` limits screen list)
4. Sequential `./script/macos_cua_screen.sh <screen>` per prototype screen
5. `npm run ledger:stale` summary

Flags: `--stale-only`, `--capture-only`, `--cua-only`, optional screen list, `--keep-api`.

**Parallel OK:** disjoint `MacScreens.swift` MARK slices per `validation/macos/*.json`.  
**Parallel NOT OK:** capture, CUA, `reset:validation-data` mid-flight.

## Validation fixtures contract (`--mac-screen` deep links)

When a screen must match a mockup plate but API rows are unstable (parallel
seeding, empty chat threads, roster order), add a **fixture layer** in
`MacPrototypeData.swift` (or screen-local plate map) used when `--mac-screen`
is set and API data is empty or validation needs plate copy.

| Screen | Fixture | Mockup plate | Rule |
|--------|---------|--------------|------|
| `chat` | `MacChatFixtures` | 05 | API matches first; fixtures for plate-05 roster + jazz thread |
| `messages` | `MacMessagesFixtures` | 15 | Fixtures preferred on `messages` deep-link |
| `communitiesBrowse` | `communityBrowsePlate` in `MacScreens.swift` | 06 | Maps API ids → mockup names/order/join badges |

When adding a new deep-link screen to validation:
1. Add fixture block if plate copy ≠ seeded API shape
2. Document in ledger `intentional_differences`
3. Wire `macos_cua_screen.sh` click labels to `accessibilityLabel` strings

## Per-screen validation checklist

1. One `validation/macos/NN-*.json` + `mockup_ref` + `requires_fixing`
2. One `MacScreens.swift` MARK section (or `MacDesignSystem` helper)
3. `xcodebuild … LikemindedMac` — compile
4. Capture at **1200×760** → `output/validation/macos-screens/<screen>.png`
5. Compare plate; gaps → fix or `intentional_differences`
6. `./script/macos_cua_screen.sh <screen>` — stamp controls + `tested_source_hash`
7. `ui_validation.result=pass` only when layout matches `DESIGN.md` + plate

## Conventions Specific to This App

- **Backend contract is `LIKEMINDED_API_BASE_URL`.** Both iOS and macOS read
  the same key from their Info.plist (`INFOPLIST_KEY_LIKEMINDED_API_BASE_URL`).
  Never hardcode a URL in the Swift client; never fork the contract per platform.
- **Auth gate** is the macOS welcome screen (`MacScreens.swift`):
  Sign in with Apple + Google + MetaMask + Solflare (same shared buttons as iOS).
  Entitlement: `Entitlements/LikemindedMac.entitlements`. URL schemes + `GIDClientID`
  in `Info/LikemindedMac-Info.plist`. Wallet callbacks in `LikemindedMacApp.onOpenURL`.
  `MacRootView` uses `@EnvironmentObject MacAppState` from the app entry point.
  For validation without real Apple ID: `--likeminded-dev-auth-bypass` with
  `npm run dev:api:local-auth`.
- **LiveKit** on macOS: `LikemindedMac` links LiveKit SPM packages; join flow uses
  `Sources/Shared/LiveKitMeetSession.swift` in `meetVideoCall`. Preview tiles when
  `POST /v1/meetings/:id/join` fails (no `LIVEKIT_*` env).
- **Keep macOS-only SwiftUI in `Sources/LikemindedMac`.** Shared auth + LiveKit
  live in `Sources/Shared/`.
- **Window size for validation is 1200×760** at {80,80} — match this when
  capturing for parity with `mockups/macos/`.
- **Shell-first.** No simulator tooling on this surface — use `xcodebuild`,
  `open`, `cross_platform_validation_lock.sh`, `screencapture`, `log stream`, `osascript`.

## Common Pitfalls

- Editing `Likeminded.xcodeproj` directly → always edit `project.yml` and run `xcodegen generate`.
- Circle/community hero art uses `Sources/DoodleArt` + `Assets.xcassets` doodles — if `DoodleCover` fails to compile, confirm `project.yml` lists `Sources/DoodleArt` under the Mac target and rerun `xcodegen generate`.
- Building for `platform=iOS Simulator` when you wanted the Mac → use `-destination 'platform=macOS'` and scheme `LikemindedMac`.
- Leaving a prior `LikemindedMac` instance running → new `--mac-screen` args won't take effect. Use `macos_kill_if_lock_holder` inside the `macos-app` lock — not bare `pkill` from parallel agents.
- Forgetting to start the validation API → blank/auth-gated screens. Always `curl /health` first.
- `screencapture` without `-l <window_id>` → grabs the whole screen, breaking mockup parity.
- Port 8787 already in use → `verify_macos_screens.sh` will kill the existing listener, but be aware it does so unconditionally.
- **Parallel agents + CUA/capture** → empty AX tree, wrong window in PNG; use `npm run macos:validation-batch` after parallel UI work.
- **Community browse card white line at hero top** → apply `MacPalette.surface` only on the text footer, not the full card; hero uses `DoodleCover` with top-aligned `scaledToFill` (see `communityCard` in `MacScreens.swift`).
- Treating macOS as Catalyst → this project is **native macOS**, not Catalyst (`SUPPORTS_MACCATALYST: NO` on the iOS target). Don't switch to a Catalyst destination.

## Related
- `build-ios-app` skill — the iOS SwiftUI surface (`Likeminded`).
- AGENTS.md "Trigger Map" for the canonical validation order and the
  `npm run verify:macos-screens` / `npm run verify:simulator-local` aliases.
