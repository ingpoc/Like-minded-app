# iOS App

SwiftUI source for the Likeminded TestFlight MVP placement loop.

## Current Status

- Auth gate uses Sign in with Apple.
- MVP tabs are `Talk`, `Circles`, `Communities`, and `Profile`.
- `Talk` uses `RealtimeVoiceClient` and sends Realtime SDP through the authenticated backend broker.
- `Circles` shows the current placement and supports accept, swap, and defer actions.
- `Profile` supports profile review/edit and tester feedback.
- `AuthSessionStore` persists the app session token in Keychain.
- `DeviceIdentity` remains local continuity metadata, not the primary identity.

## Project Source Of Truth

`project.yml` is the source of truth for the native project. Run XcodeGen through the repo script:

```sh
./script/build_and_run.sh --verify
```

The generated app bundle id is `com.likeminded.app`, with Sign in with Apple entitlement at `Entitlements/Likeminded.entitlements`.

## Validation

Use:

```sh
npm run verify:release-config
./script/build_and_run.sh --verify
```

For visual validation, the first unauthenticated screen should be the Sign in with Apple gate. After sign-in, `Talk`, `Circles`, `Communities`, and `Profile` tabs should be visible.
