# iOS TestFlight external beta operator checklist

The first external beta is iOS-only. The App Store Connect record is universal, but macOS TestFlight distribution remains deferred.

## Apple Developer and production configuration

- [x] Apple Developer Program active under team `9UPQL479Z5`
- [x] Universal App ID `com.gurusharan.likeminded` with Sign in with Apple
- [x] Universal App Store Connect app `6792839764`
- [ ] Create a Sign in with Apple key for the primary App ID; store its key ID and `.p8` content only in Render secrets
- [ ] Confirm Render has `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_IDS`, `APPLE_REQUIRE_NONCE=1`, and `APPLE_AUTH_BYPASS=0`
- [ ] Confirm `/health`, `/privacy`, `/v1/auth/apple`, and LiveKit production behavior before archiving

## Privacy and review metadata

- [ ] Publish `https://likeminded-api.onrender.com/privacy`
- [ ] Complete App Privacy for the app, OpenAI, LiveKit, and Google Sign-In; no advertising or cross-app tracking
- [ ] Set export compliance from `ITSAppUsesNonExemptEncryption=false`
- [ ] Use the Account Holder's contact details in App Store Connect; do not store them in the repo

Beta description:

> Likeminded creates a private voice-informed profile, suggests a compatible circle, and supports communities, scheduled group meets, recaps, and one-to-one matching. This beta is focused on authentication, profile creation, placement quality, community participation, video-room reliability, chat, privacy, and account deletion.

What to Test:

> Please test Sign in with Apple, the voice interview, profile and circle placement, communities, scheduled meets, LiveKit room joining, soulmate chat, session restoration, and account deletion. Report unclear copy, incorrect placement, failed joins, crashes, privacy concerns, or flows that cannot be completed.

Review notes: reviewers use Sign in with Apple; no paid subscription or special credential is required. Test sign in → voice interview → placement → communities → scheduled meet → chat → account deletion. Push notifications and payments are not included.

## Build, upload, and groups

- [ ] Query App Store Connect and set `CURRENT_PROJECT_VERSION` to one above the highest uploaded iOS build
- [ ] Generate the Xcode project from `project.yml`
- [ ] Archive and export iOS Release under the cross-platform validation lock using App Store Connect signing
- [ ] Run `npm run verify:ios-release-candidate -- /absolute/path/to/export/Payload/Likeminded.app` to verify bundle/team, non-empty Google OAuth values, Apple entitlement, privacy manifest, production URL, camera/microphone descriptions, and `get-task-allow=false`
- [ ] Upload the iOS build and resolve processing/export-compliance prompts
- [ ] Install once through an Account Holder-only internal smoke group
- [ ] Create external group `Likeminded Early Access`, limit 25, email invitations only, public link disabled
- [ ] Submit the build for Beta App Review; send invitations only after approval
- [ ] Invite 5 testers for 24 hours, then expand to 25 if auth, backend health, and crash feedback remain healthy

## Manual release proof

- [ ] Real Apple sign-in and Keychain restoration
- [ ] Spoken voice → persisted profile and placement
- [ ] LiveKit room join
- [ ] Cross-user privacy isolation
- [ ] Account deletion reauthentication, Apple token revocation, backend deletion, and rejected old session
- [ ] One invited external tester completes the core loop

Populate `release/testflight-evidence.json` only from observed saved state, then run `npm run verify:external-preflight`.
