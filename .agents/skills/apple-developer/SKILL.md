---
name: apple-developer
description: Use when operating the Like-minded repo's Apple Developer and App Store Connect release lane, including membership and team checks, bundle/App ID registration, Sign in with Apple, signing capabilities, App Store Connect records, TestFlight uploads, and reconciliation with repo release contracts.
---

# Apple Developer

Own Apple-side release setup for this repository. Keep portal state, Xcode configuration, backend Apple client IDs, and deterministic release evidence aligned.

> **Self-validate after edits.** Run the local `create-skill` strict audit.

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

Read [references/verified-state.md](references/verified-state.md) before relying on
saved portal, signing, device, backend, or App Store Connect claims. Update that
reference only after reading a saved Apple page, list, detail view, or signed
artifact after the relevant action.

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
4. Treat `-allowProvisioningUpdates` as an Apple-account mutation. Use it only when the requested provisioning scope authorizes that effect, then run the Release build under `script/cross_platform_validation_lock.sh`.
5. When a connected development device is not registered, add `-allowProvisioningDeviceRegistration` together with `-allowProvisioningUpdates`, or register the exact user-authorized device in the Apple Developer portal. Verify the saved device list after registration.
6. Claim local signing readiness only after the build succeeds, `codesign -d --entitlements :-` confirms the expected application identifier, team identifier, and entitlements, and the embedded provisioning profile authorizes the same restricted entitlements.
7. Prove macOS and generic-device iOS separately; simulator or `CODE_SIGNING_ALLOWED=NO` builds are compile proof, not provisioning proof.
8. A paired iPhone still needs Developer Mode enabled before Xcode can target, install, or launch a development build. Treat portal registration and device-runtime readiness as separate gates.
9. After a signed device build, prove the live lane with `xcrun devicectl device install app` and `xcrun devicectl device process launch`; do not store device identifiers in repo files or command examples.

## Physical iPhone developer diagnostics

Use bundled `@Computer` for read-only native inspection of iPhone Mirroring and device Settings. Do not route this work through legacy macOS CUA. Use Xcode, `xcodebuild`, `devicectl`, and XCUITest for deterministic device execution; Computer Use supplies visual and system-sheet evidence, not a replacement for those tools.

1. Preflight one explicit physical-device identity. Require `developerModeStatus: enabled`, `pairingState: paired`, developer services available, Developer Mode **On**, and UI Automation **On**. Keep the device identifier in the current process only; never persist it in the repo, skill, evidence JSON, or logs.
2. Build and install once per source hash, then reuse that signed binary for compatible physical-device tests. Prefer XCUITest for repeatable navigation and assertions; reserve Computer Use for permission sheets, Apple authentication handoffs, device Settings, and visual inspection.
3. Treat iPhone Mirroring as interaction and screenshot evidence only. Do not use it as the sole camera, microphone, WebRTC, or two-participant LiveKit proof; complete those checks directly on the physical iPhone and verify media state from both participants.
4. Use Network Link Conditioner only in a bounded resilience lane. Recommended profiles for the current API and LiveKit paths are Wi-Fi baseline, LTE, High Latency DNS, Very Bad Network, and 100% Loss for disconnect/recovery. Changing this network setting requires action-time confirmation. Record the starting state and profile, then restore **Enable: Off** and verify it before leaving the lane.
5. Use Hang Detection temporarily for voice interview, LiveKit join/rejoin, long scrolling, and account-deletion waits. It captures hangs over 250 ms; retain the diagnostic with the affected journey, then restore the prior setting. Do not enable Performance Trace by default: it requires a device restart and belongs only in targeted performance diagnosis.
6. The Responsiveness test may record an RPM/network baseline before a media run, but it is environment metadata, not app success evidence. Network Override cost settings remain default unless the app implements explicit expensive/constrained-network behavior.
7. Associated Domains Development and Universal Links Diagnostics are useful only when universal links enter the approved product scope. The device toggle does not prove the app entitlement, AASA file, production domain, or App Store-signed behavior.
8. Never use **Clear Trusted Computers** as routine recovery; it destroys pairing records and expands the failure surface. Re-pair only when the current trust relationship is proven broken and the user authorizes that recovery.

For a device resilience pass, retain a compact evidence bundle: source hash, binary identity, redacted device alias, network profile, immediate semantic postconditions, `.xcresult` or hang diagnostic path, screenshot references, and backend readback. Keep full logs on disk and load them only on mismatch or failure.

## Keychain secret locator contract

Read [references/keychain-secret-locators.md](references/keychain-secret-locators.md)
before storing, locating, or consuming release credentials.

## iOS TestFlight campaign

Use this order for an iOS upload. Stop at the first failed gate; do not turn later portal setup into apparent release proof.

1. Work from a clean release branch or isolated worktree. In a new worktree, run `npm ci` from the lockfile before the full auth suite; never symlink another worktree's `node_modules`.
2. Query App Store Connect for uploaded iOS builds and set `CURRENT_PROJECT_VERSION` to `max(builds) + 1`; use `1` only when the saved build list is empty.
3. Run `xcodegen generate --spec apps/ios-macos/project.yml`, then require `git diff --check` and no unexpected generated diff. `project.yml` remains the owner; never patch the generated project by hand.
4. Deploy the exact reviewed commit before archiving. For a Blueprint-managed Render service, change the Blueprint branch, approve the sync, then explicitly deploy the latest commit if auto-deploy did not start. Verify the intended commit in Render plus live `/health`, `/privacy`, and backend-owned auth JSON.
5. Run release configuration, auth, MVP smoke, and production gates. A failed ledger or external-evidence gate remains a blocker; do not replace it with a successful compile.
6. Under `script/cross_platform_validation_lock.sh with_lock xcodebuild-ios`, archive `Release` for `generic/platform=iOS` with `-allowProvisioningUpdates`, then export with App Store Connect managed signing.
7. Run `npm run verify:ios-release-candidate -- <exported-app>` on the exported signed `.app`. Require the expected bundle/team, build number, Sign in with Apple entitlement, privacy manifest, usage descriptions, production API URL, `get-task-allow=false`, and no auth bypass/debug route.
8. Upload only the verified export. Wait for App Store processing and export-compliance resolution before assigning it to groups.
9. Prove internal install first, then external Beta App Review, approval, email invitation, non-development-device install, and one external core-loop completion. Each is a separate evidence field; group creation alone is not TestFlight acceptance.

If signing opens a password, 2FA, Face ID, or device-passcode gate, pause for the user. Do not ask them to paste the credential into chat or automation.

## Friction playbook

- If Xcode returns to the sign-in sheet or reports invalid credentials, stop retrying fields. Re-read Apple Accounts, let the user complete password and 2FA, then verify the paid team before rebuilding.
- After any user interaction with Xcode authentication, re-fetch the current accessibility state. Never reuse stale element indices or assume the previous field is still active.
- Detect physical devices with both `xcrun devicectl list devices` and `xcrun xctrace list devices`. The CoreDevice identifier used by `devicectl device info` differs from the UDID used by `xcodebuild -destination id=...`; never substitute one for the other.
- Verify device readiness with `xcrun devicectl device info details --device <core-device-id>`. Require `developerModeStatus: enabled`, `pairingState: paired`, and developer services available before a device-targeted build.
- Register only physical devices. Simulator entries cannot be added to the Apple Developer device list.
- Treat the certificate's display label as informational. Use `codesign` `TeamIdentifier`, application identifier, embedded provisioning profile, and entitlements as the authoritative signing proof.
- When the native Apple sheet opens but the app reports a plain HTTP error, test the exact built app API base URL at `/health` and `/v1/auth/apple`. A Render `x-render-routing: no-server` response means the hostname has no active service; do not debug Apple credentials or capabilities until the backend route is healthy.
- For this repo's current production deployment, keep Neon Auth off, populate Render's `DATABASE_URL`, `SESSION_SECRET`, and `OPENAI_API_KEY` through secret inputs, and leave optional LiveKit, Google, and WalletConnect values unset until those product paths are configured. Verify secrets by behavior and metadata only; never echo their values.
- Prove the Render recovery with all three signals: Dashboard says `Deploy live` for the intended commit, `/health` is `200` with PostgreSQL active, and `/v1/auth/apple` produces backend JSON rather than `x-render-routing: no-server`.
- Do not claim Sign in with Apple end-to-end readiness from a signed build or native authorization sheet alone. Require a real device credential exchange through the configured production backend and a persisted app session.
- Use `set -o pipefail` and filter large `xcodebuild` output for `error:`, signing identity, provisioning profile, `CodeSign`, and the final build/archive result. Preserve the real pipeline exit status.
- If Xcode creates or uses a provisioning profile and later reports Swift compiler errors, record provisioning as successful but final app signing as incomplete. Do not convert a source failure into an Apple-account failure.
- Never store device IDs, serial numbers, phone numbers, account emails, certificate hashes, or provisioning-profile UUIDs in repo skills or logs intended for reuse.
- Treat an Apple private key as compromised if its contents appear in any browser snapshot, terminal output, log, or chat transcript. Discard any unsaved provider edit, revoke the key in Apple Developer, permanently delete the downloaded file, create a replacement, and verify only masked provider metadata afterward.
- Store the active `.p8` outside the repository with directory mode `700` and file mode `600`; inject it through the production secret manager. Never print, re-open, screenshot, or commit its contents, and scan the repo for private-key markers before commit.
- When a Render branch change reports a successful Blueprint sync but the service still shows an older commit, use the service's **Manual Deploy → Deploy latest commit** action and verify the resulting live commit independently.
- If a release test fails with `Cannot find module` in an isolated worktree, restore dependencies with `npm ci` and rerun the same gate. Do not classify missing local dependencies as an auth or Apple-platform defect.
- If `xcodegen` changes tracked generated files unexpectedly, stop and reconcile `project.yml` before archiving. A locally patched `.pbxproj` is not a durable release fix.

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
- Never revoke or delete certificates, provisioning profiles, or Keychain identities without explicit authorization for the exact resource.
- If Apple rejects an identifier, do not claim partial creation. Verify absence, record the collision here, and choose a replacement only within the user's authority.
- Keep simulator and local-auth proof separate from real Apple sign-in, signed-device, and TestFlight proof.
- Do not mark `release/testflight-evidence.json` true until the corresponding live postcondition is verified.
- Do not enable capabilities merely because the membership includes them. Enable only implemented product requirements; unused services add provisioning, privacy, review, or compliance obligations.

## Proof tiers

- Report compile, development signing, archive, App Store/TestFlight, and release acceptance separately.
- App Store/TestFlight proof requires a distribution export with `get-task-allow=false`, a processed build, and the correct App Store record.
- Release acceptance requires installation through the intended external channel and completion of the required product journey. Never promote an earlier tier into a later one.

## Completion gates

- App ID exists under team `9UPQL479Z5`.
- Sign in with Apple is enabled on that App ID.
- App Store Connect app exists and exposes a numeric Apple ID.
- Repo bundle ID and Apple client-ID configuration match the saved App ID.
- Xcode exposes paid team `9UPQL479Z5`, and signed Release builds prove provisioning for macOS and iOS separately.
- The exported iOS candidate passes `verify:ios-release-candidate` against the actual signed `.app`, not a simulator or archive-only artifact.
- Render serves the intended reviewed commit, public `/privacy`, healthy production storage, and backend-owned Apple auth responses.
- External TestFlight completion requires Beta App Review approval, an invited external tester, a non-development-device install, and a completed core loop.
- `verify:release-config` and `verify:external-preflight` report truthfully; an external gate may remain incomplete for later infrastructure or TestFlight proof.
