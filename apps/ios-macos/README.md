# iOS/macOS App

SwiftUI prototype source for the native Likeminded app shell.

## Current Status

The native surface now contains a multi-file prototype under `Sources/LikemindedApp` with mock screens for:

- Today home and reflection
- Communities
- Matches
- Consent-aware chat
- Privacy settings

An `XcodeGen` project spec now lives at `project.yml`, and `../../script/build_and_run.sh` is the canonical simulator build-and-run entrypoint.

## Prototype Direction

- Mobile-first tab experience with intentional mock content.
- Voice onboarding, compatibility explanations, and privacy controls are visible as product concepts even though no backend SDK is wired.
- The UI reflects the current architecture contract: AI interprets, backend controls, database persists.

## Run In Simulator

Generate the project and run the prototype with:

```sh
./script/build_and_run.sh
```

Override the default simulator if needed:

```sh
SIMULATOR_NAME="iPhone 17" SIMULATOR_OS="26.2" ./script/build_and_run.sh
```

## Next Native Decisions

- Decide whether the shared `ios-macos` surface should stay unified or split into iOS-first and macOS-specific scene variants.
- Wire the prototype to the mock API routes now that a simulator loop exists.
- Add assets, launch polish, and test targets once the first runnable surface is stable.
