# iOS project layout

## Tree (iOS-relevant)

```
apps/ios-macos/
  project.yml
  Likeminded.xcodeproj/          # generated — do NOT hand-edit
  Entitlements/Likeminded.entitlements
  Info/Likeminded-Info.plist
  Sources/LikemindedApp/
    LikemindedApp.swift
    Data/                        # API client, auth, voice, LiveKit tokens, state
    Views/                       # AuthGateView, RootView, tabs, flows
    Models/
  Sources/Shared/                # ConvergenceFieldView, ConvergenceField.metal, auth buttons, LiveKitMeetSession
```

## Target facts

| Field | Value |
| --- | --- |
| Bundle id | `com.likeminded.app` |
| Scheme | `Likeminded` |
| Deployment | iOS 18.0, iPhone + iPad |
| Build output | `.build/ios-simulator/Build/Products/Debug-iphonesimulator/Likeminded.app` |
| Default sim | `iPhone 17` (`SIMULATOR_NAME` override) |
| LiveKit | SPM `LiveKit` + `LiveKitWebRTC` — `GroupVideoCallView` / shared `LiveKitMeetSession` |
| API key | `INFOPLIST_KEY_LIKEMINDED_API_BASE_URL` |

## Conventions

- iOS-only SwiftUI → `Sources/LikemindedApp`; shared auth/LiveKit/convergence → `Sources/Shared`.
- Auth gate: `AuthGateView` — `ConvergenceFieldView` + Apple, Google, MetaMask, Solflare.
- Dev bypass: `--likeminded-dev-auth-bypass` + `npm run dev:api:local-auth`.
- LiveKit join needs `LIVEKIT_*` on API; preview tiles when join fails.
- Mockup path per screen: ledger **`mockup_ref`**. Promote `mockups/ios/concepts/mockup-<screen>.png` → `mockups/ios/<screen>.png` as SSOT — do not walk `mockups/ios/` for routing.
