---
name: apple-developer
description: Operate the Like-minded repo's Apple Developer and App Store Connect release lane. Use for Apple membership and team checks, bundle/App ID registration, Sign in with Apple, signing capabilities, App Store Connect app creation, TestFlight metadata or uploads, and reconciliation of Apple identifiers with repo release contracts.
---

# Apple Developer

Own Apple-side release setup for this repository. Keep portal state, Xcode configuration, backend Apple client IDs, and deterministic release evidence aligned.

## Project binding

| Binding | Value |
| --- | --- |
| Product | Likeminded |
| Apple team | `9UPQL479Z5` |
| Enrollment | Individual |
| App Store Connect role | Account Holder, Admin; All Apps |
| Native configuration owner | `apps/ios-macos/project.yml` |
| Backend auth owner | `docs/workflows/setup.md` and production environment |
| External evidence owner | `release/testflight-evidence.json` |
| External gate | `script/verify_external_preflight.js` |

## Verified state

Update this section only after reading a saved Apple page, list, or detail view after submission.

- 2026-07-20: Apple Developer Program membership active; renewal date 2027-07-21.
- 2026-07-20: Apple Developer Program License Agreement accepted.
- 2026-07-20: App Store Connect Terms of Service accepted by the user.
- 2026-07-20: team App IDs contain `com.guru.entourage` and `com.guru.entourage.entourage`.
- 2026-07-20: registration of `com.likeminded.app` failed because Apple reported the identifier unavailable; it was not created.
- 2026-07-20: registered explicit App ID `com.gurusharan.likeminded` under team `9UPQL479Z5`; saved detail view confirms Sign in with Apple enabled as the primary App ID.
- 2026-07-20: created one universal App Store Connect record for iOS and macOS with shared bundle ID `com.gurusharan.likeminded`, SKU `likeminded-apple`, listing name `Likeminded: Find Your Circle`, and Apple ID `6792839764`.
- 2026-07-20: exact App Store name `Likeminded` was unavailable. The longer listing name succeeded; keep the in-app product name `Likeminded`.
- 2026-07-20: capability audit found native Apple sign-in, Realtime microphone input, and LiveKit camera/microphone/network use. Keep the portal capability set to Sign in with Apple; configure macOS App Sandbox, outbound network, camera, audio input, and hardened runtime in XcodeGen/entitlements.
- 2026-07-20: Apple portal access does not prove local signing access. Xcode still exposed only the Gmail Personal Team, and an automatic-provisioning macOS build failed with `No Account for Team "9UPQL479Z5"`. The paid Apple Account must appear in Xcode Accounts before signed-build proof can pass.
- 2026-07-20: Xcode paid-team access was restored with Admin access to Certificates, Identifiers & Profiles. Automatic provisioning registered the development Mac and produced a signed macOS Release build for team `9UPQL479Z5`.
- 2026-07-20: signed macOS entitlements proved application identifier `9UPQL479Z5.com.gurusharan.likeminded`, team `9UPQL479Z5`, Sign in with Apple, App Sandbox, outbound network, camera, microphone input, and hardened runtime.
- 2026-07-20: registered the user's physical iPhone 17 in the Apple Developer device list and verified the saved row. Do not store its UDID or serial number in this skill or repo.
- 2026-07-20: iOS automatic provisioning created and used the team provisioning profile, but the Release archive stopped on existing Swift compile errors before final app signing. Physical-device build/run also requires Developer Mode on the iPhone.
- 2026-07-21: Developer Mode was enabled on the registered iPhone 17. A device-targeted iOS Release build succeeded, and signed entitlements proved team `9UPQL479Z5`, application identifier `9UPQL479Z5.com.gurusharan.likeminded`, and Sign in with Apple.
- 2026-07-21: installed and launched the signed Release app on the physical iPhone 17, then produced a successful generic iOS Release archive at `.build/Likeminded-AppleConfig.xcarchive`.
- 2026-07-21: iPhone Mirroring proved the native Sign in with Apple authorization sheet opens correctly. The post-authorization app failure `Not Found` came from the configured production fallback `https://likeminded-api.onrender.com`, which returned Render platform `404` with `x-render-routing: no-server` for both `/health` and `/v1/auth/apple`; this is a missing/stale backend deployment, not an Apple entitlement failure.

## Portal workflow

1. Use the Chrome control skill when the user requests or authorizes work in their authenticated Chrome session.
2. Inspect before mutating: membership, team, current identifiers, agreements, App Store apps, and any blocking banners.
3. Resolve the repo's current bundle ID from `apps/ios-macos/project.yml` and release verifiers before registering anything.
4. Use the verified explicit App ID `com.gurusharan.likeminded`. Do not create a second iOS/macOS identifier: Apple universal-purchase records share one bundle ID across platforms.
5. Register the App ID with description `Likeminded` and enable **Sign in with Apple** as a primary App ID.
6. Treat field entry and confirmation pages as pending. Claim success only after the identifier appears in Apple's saved identifier list or detail page with the capability enabled.
7. Create the App Store Connect record only after the App ID is verified. Use:
   - platforms: iOS and macOS
   - name: `Likeminded: Find Your Circle`
   - primary language: English
   - SKU: `likeminded-apple`
   - user access: Full Access unless the account requires a narrower explicit choice
8. Verify the saved app record and capture its Apple ID. Do not infer creation from an accepted click.
9. Reconcile the verified identifier across repo owner surfaces in the same pass. Search for the previous bundle ID before editing; update code, release validators/templates, and setup docs without creating parallel configuration.
10. Run the skill validator and the repo's static release verifier after any skill or release-contract edit.

## Xcode signing workflow

1. In Xcode Settings > Apple Accounts, verify that the paid account exposes team `9UPQL479Z5`; a Personal Team alone is insufficient.
2. Leave password and 2FA entry to the user. Do not read, store, echo, or automate those secrets.
3. Select accounts by paid team and role, not by an assumed email address. Treat the account-pane label as a preliminary check only.
4. Run a Release build with `-allowProvisioningUpdates` under `script/cross_platform_validation_lock.sh`.
5. When a connected development device is not registered, add `-allowProvisioningDeviceRegistration` together with `-allowProvisioningUpdates`, or register the exact user-authorized device in the Apple Developer portal. Verify the saved device list after registration.
6. Claim local signing readiness only after the build succeeds and `codesign -d --entitlements :-` confirms the expected application identifier, team identifier, and entitlements on the built app.
7. Prove macOS and generic-device iOS separately; simulator or `CODE_SIGNING_ALLOWED=NO` builds are compile proof, not provisioning proof.
8. A paired iPhone still needs Developer Mode enabled before Xcode can target, install, or launch a development build. Treat portal registration and device-runtime readiness as separate gates.
9. After a signed device build, prove the live lane with `xcrun devicectl device install app` and `xcrun devicectl device process launch`; do not store device identifiers in repo files or command examples.

## Friction playbook

- If Xcode returns to the sign-in sheet or reports invalid credentials, stop retrying fields. Re-read Apple Accounts, let the user complete password and 2FA, then verify the paid team before rebuilding.
- After any user interaction with Xcode authentication, re-fetch the current accessibility state. Never reuse stale element indices or assume the previous field is still active.
- Detect physical devices with both `xcrun devicectl list devices` and `xcrun xctrace list devices`. The CoreDevice identifier used by `devicectl device info` differs from the UDID used by `xcodebuild -destination id=...`; never substitute one for the other.
- Verify device readiness with `xcrun devicectl device info details --device <core-device-id>`. Require `developerModeStatus: enabled`, `pairingState: paired`, and developer services available before a device-targeted build.
- Register only physical devices. Simulator entries cannot be added to the Apple Developer device list.
- Treat the certificate's display label as informational. Use `codesign` `TeamIdentifier`, application identifier, embedded provisioning profile, and entitlements as the authoritative signing proof.
- When the native Apple sheet opens but the app reports a plain HTTP error, test the exact built app API base URL at `/health` and `/v1/auth/apple`. A Render `x-render-routing: no-server` response means the hostname has no active service; do not debug Apple credentials or capabilities until the backend route is healthy.
- Do not claim Sign in with Apple end-to-end readiness from a signed build or native authorization sheet alone. Require a real device credential exchange through the configured production backend and a persisted app session.
- Use `set -o pipefail` and filter large `xcodebuild` output for `error:`, signing identity, provisioning profile, `CodeSign`, and the final build/archive result. Preserve the real pipeline exit status.
- If Xcode creates or uses a provisioning profile and later reports Swift compiler errors, record provisioning as successful but final app signing as incomplete. Do not convert a source failure into an Apple-account failure.
- Never store device IDs, serial numbers, phone numbers, account emails, certificate hashes, or provisioning-profile UUIDs in repo skills or logs intended for reuse.

## Release research gates

- Before every upload campaign, check Apple's [upcoming submission requirements](https://developer.apple.com/news/upcoming-requirements/) instead of hardcoding an Xcode or SDK minimum in this skill.
- Upload iOS and macOS builds to the existing universal app record. Verify bundle ID, marketing version, and unique build number because App Store Connect uses them to associate an upload with the app and version.
- Complete TestFlight test information before inviting testers. Treat internal and external testing separately; external testing can require Beta App Review, and beta builds expire.
- Complete App Privacy at the app level using the most inclusive behavior across iOS and macOS. Include data collected by LiveKit, Google Sign-In, and every other integrated third-party SDK; keep the privacy policy URL and declarations synchronized with shipped behavior.
- Audit included SDKs before upload for Apple's current privacy-manifest, required-reason API, and SDK-signature requirements. Do not infer compliance from a successful archive.
- Because Likeminded contains social networking and user-generated content, require objectionable-content filtering, reporting with timely response, user blocking, and published support contact information before App Review.
- Because the app creates accounts, require an easy-to-find in-app full account-deletion flow. When deleting a Sign in with Apple account, revoke the user's Apple tokens through Apple's REST API rather than deleting only local data.
- Determine export-compliance answers from the shipped encryption behavior. If no documentation is required, encode the applicable App Store Connect determination in `Info.plist`; never guess an exemption merely because encryption comes from system frameworks.
- Keep Mac distribution lanes distinct: Mac App Store delivery uses the App Store archive/upload workflow; direct distribution outside the store requires Developer ID signing and Apple notarization. Create Developer ID credentials only when direct distribution is an approved product requirement.
- Prefer App Store Connect API automation only after the manual release path is proven. Use least-privilege roles, external secret storage, and never commit private keys or issuer/key identifiers.

Official owners: [upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds), [TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview), [app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy), [export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app), [Sign in with Apple](https://developer.apple.com/help/account/capabilities/about-sign-in-with-apple), and [Developer ID](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/).

## Safety and honesty

- Never request, read, store, or repeat passwords, 2FA codes, recovery data, phone numbers, addresses, or unrelated account details.
- Leave legal agreements, CAPTCHAs, payments, tax/banking data, and identity attestations to the user unless they explicitly authorize the exact action and policy permits it. Never accept legal terms on the user's behalf.
- Keep portal inspection read-only until the user authorizes the exact external records or capabilities to create.
- If Apple rejects an identifier, do not claim partial creation. Verify absence, record the collision here, and choose a replacement only within the user's authority.
- Keep simulator and local-auth proof separate from real Apple sign-in, signed-device, and TestFlight proof.
- Do not mark `release/testflight-evidence.json` true until the corresponding live postcondition is verified.
- Do not enable capabilities merely because the membership includes them. Enable only implemented product requirements; unused services add provisioning, privacy, review, or compliance obligations.

## Completion gates

- App ID exists under team `9UPQL479Z5`.
- Sign in with Apple is enabled on that App ID.
- App Store Connect app exists and exposes a numeric Apple ID.
- Repo bundle ID and Apple client-ID configuration match the saved App ID.
- Xcode exposes paid team `9UPQL479Z5`, and signed Release builds prove provisioning for macOS and iOS separately.
- `verify:release-config` and `verify:external-preflight` report truthfully; an external gate may remain incomplete for later infrastructure or TestFlight proof.
