---
name: build-ios-app
description: Likeminded iOS build/run/validate skill for the SwiftUI LikemindedApp target in apps/ios-macos. Use when building, running, debugging, or screenshot-validating the iOS surface against mockups/ios — covers xcodegen, xcodebuild for iphonesimulator, simctl launch with auth-bypass args, validation-data seeding, and parity checks. Covers the project-specific placement-loop / onboarding / circles / meet / soulmate / profile flows.
---

# Build iOS App — Likeminded

Project-specific skill for the **iOS SwiftUI surface** of the Like-minded-app:
the `Likeminded` target in `apps/ios-macos/project.yml`, source at
`apps/ios-macos/Sources/LikemindedApp/`.

## When to Use This Skill

Apply when working on the **iOS app** (`LikemindedApp`) for any of:

- Building, running, or debugging the iOS target in the simulator
- Adding or modifying SwiftUI views under `Sources/LikemindedApp/Views/`
- Wiring the iOS client to the Node API (`LIKEMINDED_API_BASE_URL` contract)
- Validation: capturing screenshots and comparing against `mockups/ios/`
- Onboarding, placement loop, circles, meet video, soulmate, profile flows
- LiveKit / Realtime voice integration (the iOS target depends on LiveKit)

**Skip this skill** for backend-only changes, schema work, macOS-only layout
(use `build-macos-app`), or non-visual infra changes — they don't need a
simulator or mockup comparison.

## Context (lazy)

1. `npm run goal:next` + `npm run ledger:open --platform=ios` for open rows.
2. **One** `validation/ios/<screen>.json` + `source_files` for the touched screen.
3. One mockup from ledger `mockup_ref` — not full `mockups/ios/`.
4. Skip `GOAL.md`, full `PROGRESS.md`, `project_context` unless boundary dispute.

## Project Layout (iOS-relevant)

```
apps/ios-macos/
  project.yml                         # XcodeGen owner — iOS + macOS targets
  Likeminded.xcodeproj/               # generated, do NOT hand-edit
  Entitlements/Likeminded.entitlements # Apple Sign-In entitlement
  Sources/LikemindedApp/
    LikemindedApp.swift               # app entry
    Models/PrototypeModels.swift
    Data/
      LikemindedAPIClient.swift       # HTTP client — backend contract
      AuthSessionStore.swift          # Apple Sign-In auth gate
      RealtimeVoiceClient.swift       # OpenAI Realtime voice
      LiveKitTokenProvider.swift      # meet video tokens
      DeviceIdentity.swift
      PrototypeAppState.swift         # placement loop state
      PrototypeData.swift
    Views/
      AuthGateView.swift              # entry gate
      OnboardingView.swift            # voice onboarding
      RootView.swift                  # tab root
      CustomTabBar.swift
      CircleCard.swift, CirclesPrototypeView.swift
      MeetView.swift                  # LiveKit meet
      SoulmateView.swift
      ProfilePrototypeView.swift, SettingsPrototypeView.swift
      CommunitiesPrototypeView.swift, NotificationsView.swift
      Shared/PrototypeComponents.swift
mockups/ios/                          # 4 sheet-montage PNG references:
  01-04-onboarding-voice-meet-soulmate.png
  05-08-circles-meet-communities.png
  09-12-meet-video-postmeet.png
  13-16-soulmate-chat.png
  17-20-profile-community-settings.png
```

Bundle id: `com.likeminded.app`. Deployment target: **iOS 18.0**. Family: `1,2`
(iPhone + iPad). LiveKit + LiveKitWebRTC are SPM dependencies.

## Build / Run / Debug Workflow

### 0. Prerequisites
- The API server must be running for in-app auth + placement flows. Verify:
  ```
  curl -s http://127.0.0.1:8787/health
  ```
- For realistic validation data, use the validation lane (see §Validation).
- XcodeGen must be installed: `brew install xcodegen` (or `mint install yonaskolb/xcodegen`).

### 1. Regenerate the Xcode project after any `project.yml` change
```
(cd apps/ios-macos && xcodegen generate)
```
Never hand-edit `Likeminded.xcodeproj`. The spec is the source of truth.

### 2. Build & run (preferred entrypoint)
The repo ships a purpose-built script that handles xcodegen, simulator
resolution, build, install, and launch:
```
./script/build_and_run.sh run          # default: iPhone 17 simulator
```
Modes accepted as the first arg:
- `run` — build, install, launch
- `build` — build + install only (no launch; prints `SIMULATOR_ID=` for locked capture scripts)
- `--debug` / `debug` — build, then `lldb` into the app
- `--logs` / `logs` — build, install, launch, stream `log stream`
- `--telemetry` — same as logs
- `--verify` / `verify` — build, install, launch once with
  `--likeminded-reset-auth-session` and print launch output

Override the simulator:
```
SIMULATOR_NAME="iPhone 16" ./script/build_and_run.sh run
```

### 3. Alternative: MCP ios-simulator tools
When the `ios-simulator` plugin is active (it is, in this session), prefer
these MCP tools for ad-hoc work and skip the bash script:
```
mcp__plugin_ios-simulator__ios_discover_project   # find scheme/bundle id
mcp__plugin_ios-simulator__ios_build_and_run      # one-shot build+install+launch
mcp__plugin_ios-simulator__ios_screenshot         # capture current screen
mcp__plugin_ios-simulator__ios_ui_describe        # accessibility tree
mcp__plugin_ios-simulator__ios_ui_tap / swipe     # drive the UI
mcp__plugin_ios-simulator__ios_logs               # filtered by bundle id
```
`ios_build_and_run` will auto-discover the iOS scheme (`Likeminded`) from
`apps/ios-macos/Likeminded.xcodeproj`.

### 4. Manual xcodebuild (last resort, when scripts/MCP can't be used)
```
xcodebuild \
  -project apps/ios-macos/Likeminded.xcodeproj \
  -scheme Likeminded \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build/ios-simulator \
  build
```

## Launch Arguments (project-specific)

The iOS app reads these `simctl launch` / `ios_launch_app` args for dev + validation:
- `--likeminded-reset-auth-session` — wipe cached Apple Sign-In session
- `--likeminded-dev-auth-bypass` — skip Apple Sign-In (local-auth API mode)
- `--likeminded-dev-auth-token <token>` — pre-seed a profile token
- `--likeminded-dev-auth-name "<Name>"` — pre-seed display name
- `--likeminded-start-profile` — land on the post-auth onboarding
- `--likeminded-dev-voice-placement` — jump to the voice placement loop

Example (via simctl):
```
xcrun simctl launch --terminate-running-process booted com.likeminded.app \
  --likeminded-reset-auth-session --likeminded-dev-auth-bypass \
  --likeminded-dev-auth-token validation-gurusharan --likeminded-dev-auth-name "Gurusharan Gupta" \
  --likeminded-start-profile
```

## Validation (against `mockups/ios/`)

Per AGENTS.md: before claiming seamless behavior, point both apps at
`data/validation-db` with the validation API and seeded data.

1. Start the validation API (uses `data/validation-db`):
   ```
   npm run dev:api:validation     # background
   npm run reset:validation-data  # seed/reset
   ```
2. Boot simulator + build + install (steps above).
3. Launch with the auth-bypass args above (use the seeded profile token, e.g.
   `validation-gurusharan` / Gurusharan Gupta).
4. Capture screenshots per flow and diff against the relevant montage in
   `mockups/ios/`:
   - onboarding / voice / meet / soulmate → `01-04-...png`
   - circles / meet / communities → `05-08-...png`
   - meet video / post-meet → `09-12-...png`
   - soulmate chat → `13-16-...png`
   - profile / community / settings → `17-20-...png`
5. For automated capture of stale ledger screens after Swift edits:
   ```
   npm run verify:ios-screens -- --stale-only
   ```
   For the legacy smoke batch (no stamp): `npm run verify:ios-screens`.
6. Quick local smoke (auth gate + tabs, not ledger reproof):
   ```
   ./script/verify_simulator_local.sh
   ```

### Validation deep-link checklist (per screen)

When adding or fixing a ledger screen for capture:

1. **`RootView` route** — every `--likeminded-start-*` flag must map to the correct tab/sheet/selection in `RootView.swift` (and `initialSelection()` when the screen is tab-adjacent, e.g. voice session on Meet).
2. **Concern-flag bypass** — during validation launches, block the profile-concern redirect so `--likeminded-start-profile` / populated profile screens land on the intended surface.
3. **`LIKEMINDED_VALIDATION_SCREEN` fallback** — when `simctl launch` drops args, set UserDefaults before screenshot (patterns: chat, community-members, past-meet-detail).
4. **Explicit simulator UDID** — read from `./script/build_and_run.sh` output; never use `booted` when multiple simulators are running.
5. **Build-only + explicit launch** — for capture, prefer `xcodebuild` + locked `simctl launch` with full arg list; `./script/build_and_run.sh run` alone auto-launches without deep links.
6. **Post-launch wait** — 15–60s after launch for dev-auth before screenshot.
7. **Parallel proof** — code edits per screen can run in parallel; build + capture must be **sequential** via `./script/cross_platform_screen_validate.sh --platform ios`.

Example locked single-screen capture:
```
./script/cross_platform_screen_validate.sh --screen 16-chat --platform ios
```

- **Backend contract is `LIKEMINDED_API_BASE_URL`.** Both iOS and macOS read
  the same key from their Info.plist (`INFOPLIST_KEY_LIKEMINDED_API_BASE_URL`).
  Never hardcode a URL in the Swift client; never fork the contract per platform.
- **Auth gate** is `AuthGateView` → Apple Sign-In (`com.apple.developer.applesignin`
  entitlement). For local dev bypass, run `npm run dev:api:local-auth` and pass
  `--likeminded-dev-auth-bypass`.
- **LiveKit** is iOS-target-only (video meet). macOS does not link it. Do not
  move LiveKit imports into shared Swift without making them macOS-safe.
- **Keep iOS-only SwiftUI in `Sources/LikemindedApp`.** Extract shared Swift
  into a shared target only when both `Likeminded` and `LikemindedMac` compile
  it without platform-specific deps.
- **`GENERATE_INFOPLIST_FILE: YES`** — there is no hand-written Info.plist;
  configure keys via `project.yml` (`INFOPLIST_KEY_*`), then regenerate.

## Common Pitfalls

- Editing `Likeminded.xcodeproj` directly → always edit `project.yml` and run `xcodegen generate`.
- Forgetting to boot the simulator before `simctl install` → the script handles this; if using MCP, `ios_boot_simulator` first.
- API not running → blank auth gate / no placement. Always `curl /health` first.
- Leaving the validation API on port 8787 → `verify_simulator_local.sh` will refuse to start a second one; stop the prior instance.
- Building without the `LiveKit`/`LiveKitWebRTC` SPM packages resolving → ensure network access on first build; packages resolve into the generated project.
- **Parallel `xcodebuild` / `simctl launch`** → SIGKILL and wrong screens; use `./script/cross_platform_validation_lock.sh` and sequential `./script/cross_platform_screen_validate.sh`.
- **iOS stale_pass reproof** → `npm run verify:ios-screens -- --stale-only` (capture + bulk stamp); not the default smoke list.
- **Auth gate “Could not connect”** → usually `:8787` was killed mid-seed by another agent, not a wrong plist URL.

## Related
- `build-macos-app` skill — the macOS SwiftUI surface (`LikemindedMac`).
- AGENTS.md "Trigger Map" for the canonical validation order.
