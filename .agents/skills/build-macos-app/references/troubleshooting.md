# Troubleshooting — macOS build / validate

| Symptom | Cause | Fix |
| --- | --- | --- |
| `DoodleCover` won't compile | `DoodleArt` not in Mac target | Add `Sources/DoodleArt` in `project.yml` → `xcodegen generate` |
| Built iOS sim instead of Mac | Wrong destination/scheme | `-scheme LikemindedMac` + `-destination 'platform=macOS'` |
| `--mac-screen` ignored | Stale app instance | Kill via lock: `macos_kill_if_lock_holder` inside `macos-app` lock |
| Blank / auth-gated UI | API down | `curl /health`; `npm run dev:api:validation` |
| Wrong PNG / full desktop | Ad-hoc capture targeted the wrong window | Relaunch the canonical app from the ledger card and recapture with bundled `@Computer` |
| Port 8787 busy | Prior API listener | Use the validation lock and keep one `npm run dev:api:validation` owner for the batch |
| Empty AX tree / wrong app target | Parallel proof or a non-canonical app instance | Drain a source-local `testing:ledger-batch-plan` sequentially and target the canonical full app path |
| Community card white line at hero | `MacPalette.surface` on full card | Surface on text footer only; hero `DoodleCover` top-aligned `scaledToFill` |
| Catalyst confusion | Wrong mental model | Native macOS target — `SUPPORTS_MACCATALYST: NO` on iOS target |
| Hand-edited `.xcodeproj` drift | Bypassed XcodeGen | Edit `project.yml` only → `xcodegen generate` |
| `stale_pass` after Swift edit | Hash mismatch | Re-run the ledger card with bundled `@Computer`, then record the flow with the current source hash |
| Multi-monitor misclick | Wrong window/display target | Use semantic labels in bundled `@Computer`; confirm the canonical app path before acting |

## Debug-only capture

Use the exact testing-ledger card and bundled `@Computer` for a single screen. Do not use improvised Quartz one-liners in validation loops.
