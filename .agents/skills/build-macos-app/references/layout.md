# macOS project layout

## Tree (macOS-relevant)

```
apps/ios-macos/
  project.yml                    # XcodeGen owner — iOS + macOS targets
  Likeminded.xcodeproj/          # generated — do NOT hand-edit
  Sources/LikemindedMac/
    LikemindedMacApp.swift       # app entry / scene
    MacRootView.swift            # root layout
    MacScreens.swift             # --mac-screen switch (production screens)
    MacMeetOverviewConceptView.swift  # Meet plate (meetOverview + meetOverviewConcept)
    MacCirclesRoomView.swift          # Circles tab (circlesRoom + circlesRoomConcept alias)
    MacAppState.swift            # auth + placement state
    MacPrototypeData.swift       # validation fixtures
    MacDesignSystem.swift        # macOS colors/typography/materials
    LikemindedAPIClient.swift    # HTTP — same contract as iOS
    Models.swift
  Sources/Shared/                # auth buttons, LiveKitMeetSession
  Sources/DoodleArt/             # circle/community hero art
  Entitlements/LikemindedMac.entitlements
  Info/LikemindedMac-Info.plist
```

## Target facts

| Field | Value |
| --- | --- |
| Bundle id | `com.likeminded.mac` |
| Deployment | macOS 15.0 |
| Scheme | `LikemindedMac` |
| Build output | `.build/macos/Build/Products/Debug/LikemindedMac.app` |
| LiveKit | SPM `LiveKit` + `LiveKitWebRTC` — `meetVideoCall` via `LiveKitMeetSession.swift` |
| Entitlements | `Entitlements/LikemindedMac.entitlements` (Debug variant for local signing) |
| API key | `INFOPLIST_KEY_LIKEMINDED_API_BASE_URL` in Info.plist |

## Conventions

- macOS-only SwiftUI → `Sources/LikemindedMac`; shared auth/LiveKit → `Sources/Shared`.
- Auth gate: welcome screen — Apple + Google + MetaMask + Solflare (`SocialAuthButtonsView`).
- Wallet callbacks: `LikemindedMacApp.onOpenURL`. State: `@EnvironmentObject MacAppState`.
- Validation without Apple ID: `--likeminded-dev-auth-bypass` + `npm run dev:api:local-auth`.
- Validation window: **1200×760** at {80,80} — scripts resize via AppleScript before capture.
- Shell-first: `xcodebuild`, `open`, `cross_platform_validation_lock.sh`, `log stream` — no simulator.

## Mockups

Per-screen path is ledger **`mockup_ref`** (e.g. `mockups/macos/auth-login-convergence.png`). Promote `mockups/<platform>/concepts/mockup-<screen>.png` → `mockups/<platform>/<screen>.png` as SSOT — do not walk mockup dirs for routing.

**Concept preview lane:** add `Mac<Screen>ConceptView.swift` + `MacPrototypeScreen.<screen>Concept` + `--mac-screen <screen>Concept`. Keeps production screen + `MacTab.primaryScreen` unchanged; signed-in shell + `MacBottomNav` unchanged. Operator compares capture vs concept plate; on approval, promote plate and replace production view in `MacScreens.swift`.
