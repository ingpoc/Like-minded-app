# TestFlight operator checklist (Phase 5)

## Control Owner

This workflow owns the repository checklist for TestFlight submission; App Store Connect state and signing credentials remain externally owned.

Subscribe to [Apple Developer Program](https://developer.apple.com/programs/) only after Phases 0–4 pass locally and on Render.

## Apple Developer + App Store Connect

- [x] Enroll in Apple Developer Program ($99/yr)
- [x] Register universal App ID `com.gurusharan.likeminded` — Sign in with Apple for iOS and macOS
- [x] Configure macOS Release App Sandbox, outbound network, camera, audio input, and hardened runtime
- [x] Re-sign macOS Release builds in Xcode with healthy Apple account
- [x] Create App Store Connect universal app (`6792839764`) for iOS and macOS
- [ ] Create TestFlight internal group
- [ ] Upload privacy policy from [`docs/references/privacy-policy-testflight.md`](../references/privacy-policy-testflight.md)
- [ ] Configure the Sign in with Apple key in Render and prove deletion-time token revocation

## Production hardening (Render)

Confirm on Render:

```sh
APPLE_AUTH_BYPASS=0
APPLE_REQUIRE_NONCE=1
APPLE_CLIENT_IDS=com.gurusharan.likeminded
GOOGLE_AUTH_BYPASS=0
WALLET_AUTH_BYPASS=0
```

## Build + upload

```sh
cd apps/ios-macos && xcodegen generate
# Archive and export iOS/macOS with App Store Connect distribution, then verify each exported app:
npm run verify:release-candidate -- ios /path/to/Likeminded.app
npm run verify:release-candidate -- macos /path/to/LikemindedMac.app
```

Set `LIKEMINDED_API_BASE_URL` empty in Release (defaults to `https://likeminded-api.onrender.com`).

## Manual device proof

- [ ] Real Apple sign-in
- [ ] Spoken voice → persisted profile + placement
- [ ] Group video join (if LiveKit configured)
- [ ] Cross-user privacy isolation
- [ ] Account deletion from Settings

## Evidence file

```sh
cp release/testflight-evidence.template.json release/testflight-evidence.json
# Fill all fields after real proof
npm run verify:external-preflight
```
