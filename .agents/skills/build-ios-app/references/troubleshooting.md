# Troubleshooting — iOS build / validate

| Symptom | Cause | Fix |
| --- | --- | --- |
| Hand-edited `.xcodeproj` | Bypassed XcodeGen | Edit `project.yml` → `xcodegen generate` |
| Simulator not booted | Skipped build script | `build_and_run.sh` boots; or `simctl boot <UDID>` |
| Blank / tiny PNG (&lt;10KB) | Dev-auth not finished | `IOS_CAPTURE_WAIT=30` or `60`; check API `/health` |
| Wrong screen in PNG | Missing/wrong deep link | Fix `ios_launch_args_for_screen` + `RootView`; use `validate:screen` not `run` |
| Auth gate “Could not connect” | `:8787` killed mid-seed | Single API owner; `npm run dev:api:validation` |
| Port 8787 conflict | Second validation API | Stop prior instance before `verify_simulator_local.sh` |
| SIGKILL / wrong sim | Parallel `xcodebuild` / `simctl` | `cross_platform_validation_lock.sh` only |
| LiveKit resolve fail | First SPM fetch | Network on first build |
| `booted` wrong device | Multiple simulators | `SIMULATOR_ID` from `build_and_run.sh build` |
| Stale_pass after Swift edit | Hash mismatch | `verify:ios-screens -- --stale-only` |
| Slow multi-screen batch | Was: rebuild every screen | Fixed: `verify:ios-screens` one build + `LIKEMINDED_SKIP_IOS_BUILD=1` per capture |
| Slow single-screen re-capture | Was: full xcodebuild every call | Fixed: auto-skip when binary fresh; `LIKEMINDED_FORCE_IOS_BUILD=1` to rebuild |
| Small PNG after skip-build | Stale sim install / early capture | Fresh path runs `install` before launch; raise `IOS_CAPTURE_WAIT` |

## Debug-only

MCP `ios-screenshot` / `ios_ui_describe` — ad-hoc inspection, not ledger proof.
