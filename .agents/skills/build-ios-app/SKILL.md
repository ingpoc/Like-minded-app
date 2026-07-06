---
name: build-ios-app
description: >-
  Likeminded iOS build/run/validate for SwiftUI LikemindedApp (apps/ios-macos).
  Triggers: iOS simulator, xcodebuild Likeminded, simctl launch, validate:screen,
  verify:ios-screens, mockup parity, placement loop. Skip for macOS
  (build-macos-app) or backend-only.
---

# Build iOS App — Likeminded

`Likeminded` target — source `apps/ios-macos/Sources/LikemindedApp/`. Spec: `project.yml` (never hand-edit `.xcodeproj`).

## When to use / skip

**Use:** iOS SwiftUI, API wiring, simulator validation, onboarding/placement/meet/soulmate flows, LiveKit.

**Skip:** macOS (`build-macos-app`), backend-only, non-visual infra.

## Context (lazy)

1. `npm run goal:next` — note open iOS screen or `ledger:stale`.
2. **One** ledger: `npm run ledger:screen -- --platform ios --screen <id>` (full stem, e.g. `22-settings-info`).
3. **One** mockup: ledger `mockup_ref` only — not `mockups/ios/` walks.
4. Command routing: `docs/workflows/validation.md` § iOS capture hygiene.

## Workflow lanes (pick one)

Do **not** improvise `simctl` capture loops. Run the script for the lane.

| Lane | When | Command |
| --- | --- | --- |
| **Dev run** | Local debug, no ledger proof | `./script/build_and_run.sh run` (see [`references/launch-args.md`](references/launch-args.md) for deep links) |
| **One-screen proof** | Capture + PNG after UI edit | `npm run validate:screen -- --screen <ledger-id> --platform ios` |
| **Stale reproof batch** | Swift edits; hash mismatch | `npm run verify:ios-screens -- --stale-only` |
| **Legacy smoke batch** | Broad capture; no ledger stamp | `npm run verify:ios-screens` |
| **Auth/placement smoke** | Not ledger reproof | `./script/verify_simulator_local.sh` |

**Optional:** MCP `ios-simulator` tools for ad-hoc debug only when the plugin is available — validation proof stays on repo scripts.

## Pass signals

| Layer | Pass |
| --- | --- |
| API | `curl -fsS http://127.0.0.1:8787/health` → `dbPath` contains `validation-db` |
| Build | `build_and_run.sh build` or `xcodebuild … -scheme Likeminded` exit 0 |
| Capture | PNG at `output/validation/ios-screens/<slug>.png`, size ≥ 10KB |
| Control | Ledger `controls[].result=pass` + `tested_source_hash` = `source_hash` |
| UI | `ui_validation.result=pass` vs ledger `mockup_ref` + `DESIGN.md` |
| Batch | `verify:ios-screens` exit 0; `--stale-only` stamps stale rows |

Mockup compare **before** claiming pass: **match** / **intentional variation** / **gap** → `visual_parity.notes`.

## Iteration (phases 2–5)

After any fix, rerun the **full lane** — not only the failing step.

```
run lane → collect pass/fail + timings → failure | inefficiency → root cause → retest full → repeat
```

| Situation | Loop |
| --- | --- |
| One screen | `validate:screen` until PNG + controls pass |
| Stale batch | `verify:ios-screens -- --stale-only` until no stale_pass on touched files |
| Wrong screen in PNG | Fix deep-link in `RootView` / launch args → full capture again |

**Build skip:** `validate:screen` skips xcodebuild when the canonical `.app` exists, sources are not newer than the binary, and `LIKEMINDED_FORCE_IOS_BUILD` is unset. It still runs `build_and_run.sh install` (~2s) so the simulator gets the fresh binary. Override: `LIKEMINDED_FORCE_IOS_BUILD=1` (rebuild) or `LIKEMINDED_SKIP_IOS_BUILD=1` (skip build **and** install step — batch sets this after its one upfront build).

**Stop when:** consecutive full runs pass **and** the last full iteration was **empty** (no failure, inefficiency, simplify, optimize, or automate debt — see workflow-hardening § Empty last iteration).

## Preflight → build → run

```bash
curl -fsS http://127.0.0.1:8787/health          # or: npm run dev:api:validation + reset:validation-data
(cd apps/ios-macos && xcodegen generate)        # after project.yml edits

./script/build_and_run.sh build                 # prints SIMULATOR_ID=… — use explicit UDID, not booted
./script/build_and_run.sh run                   # dev: build + install + launch (no deep links)

# One-screen validation (preferred proof):
npm run validate:screen -- --screen 07-meet --platform ios
```

**Deep-link capture:** use `validate:screen` — not `build_and_run.sh run` alone (auto-launches without `--likeminded-start-*`).

**Logs:** `./script/build_and_run.sh logs` or `log stream --predicate 'process == "Likeminded"'`

## Per-screen checklist

1. Ledger JSON + `mockup_ref` + open controls
2. `RootView` route for `--likeminded-start-*` (see [`references/capture.md`](references/capture.md))
3. `build_and_run.sh build` or proof via `validate:screen`
4. Compare PNG to `mockup_ref`; stamp via ledger scripts when controls proven

## Hard rules

- **Ledger owns status** — `validation/screens/*.json`; no parallel pass/fail tables.
- **Scripts, not improvisation** — locked `cross_platform_screen_validate.sh` for proof.
- **Explicit simulator UDID** — from `build_and_run.sh build`; never `booted` with multiple sims.
- **Sequential proof** — one build/capture chain at a time; `cross_platform_validation_lock.sh`.
- **`LIKEMINDED_API_BASE_URL`** in Info.plist — never hardcode URLs in Swift.
- **Validation data** — `npm run dev:api:validation` + `npm run reset:validation-data`.

## Progressive disclosure

| Load when | File |
| --- | --- |
| Launch / deep-link flags | [`references/launch-args.md`](references/launch-args.md) |
| Capture routing, waits, UserDefaults fallback | [`references/capture.md`](references/capture.md) |
| Build failed / blank PNG / API | [`references/troubleshooting.md`](references/troubleshooting.md) |
| Source tree / LiveKit / auth | [`references/layout.md`](references/layout.md) |
| All npm proof commands | `docs/workflows/validation.md` |

## Related

- `build-macos-app` — macOS surface.
- `AGENTS.md` — `verify:simulator-local`, `verify:ios-screens`.
