# Troubleshooting — macOS build / validate

| Symptom | Cause | Fix |
| --- | --- | --- |
| `DoodleCover` won't compile | `DoodleArt` not in Mac target | Add `Sources/DoodleArt` in `project.yml` → `xcodegen generate` |
| Built iOS sim instead of Mac | Wrong destination/scheme | `-scheme LikemindedMac` + `-destination 'platform=macOS'` |
| `--mac-screen` ignored | Stale app instance | Kill via lock: `macos_kill_if_lock_holder` inside `macos-app` lock |
| Blank / auth-gated UI | API down | `curl /health`; `npm run dev:api:validation` |
| Wrong PNG / full desktop | `screencapture` without window id | Use `npm run verify:macos-screens` — not ad-hoc capture |
| Port 8787 busy | Prior API listener | `verify_macos_screens.sh` kills listener; expect single API owner in batch |
| Empty AX tree / wrong CUA target | Parallel agents + capture | Sequential `macos:validation-batch` after parallel UI |
| Community card white line at hero | `MacPalette.surface` on full card | Surface on text footer only; hero `DoodleCover` top-aligned `scaledToFill` |
| Catalyst confusion | Wrong mental model | Native macOS target — `SUPPORTS_MACCATALYST: NO` on iOS target |
| Hand-edited `.xcodeproj` drift | Bypassed XcodeGen | Edit `project.yml` only → `xcodegen generate` |
| `stale_pass` after Swift edit | Hash mismatch | Re-run proof lane; refresh `tested_source_hash` via CUA script |
| Multi-monitor CUA misclick | Primary-only coords | See `macos-cua/references/displays.md` — `MACOS_CUA_DISPLAY` + `LOCAL_COORDS` |

## Debug-only capture

Prefer `npm run verify:macos-screens -- <screen>` for a single PNG. Do not use improvised Quartz one-liners in agent validation loops.
