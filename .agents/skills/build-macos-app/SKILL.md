---
name: build-macos-app
description: >-
  Likeminded macOS build/run/validate for SwiftUI LikemindedMac (apps/ios-macos).
  Triggers: macOS build, xcodebuild LikemindedMac, --mac-screen validation,
  mockup parity, testing-ledger macOS proof. Skip for iOS
  (build-ios-app) or backend-only.
---

# Build macOS App — Likeminded

> **Self-validate after edits.** Run the project skill through the strict `create-skill` audit and `workflow lint`.

`LikemindedMac` target — source `apps/ios-macos/Sources/LikemindedMac/`. Spec: `project.yml` (never hand-edit `.xcodeproj`).

## When to use / skip

**Use:** macOS SwiftUI, API wiring, `--mac-screen` validation, mockup parity, design system.

**Skip:** iOS (`build-ios-app`), backend-only, non-visual infra.

## Context (lazy)

1. `npm run goal:next` — note open macOS screen or `ledger:stale`.
2. **One** ledger: `npm run ledger:screen -- --platform macos --screen <id>`.
3. **One** mockup: ledger `mockup_ref` only — not `mockups/macos/` walks.
4. Command routing detail: `docs/workflows/validation.md` § macOS proof.

## Workflow lanes (pick one)

Do **not** improvise capture or desktop automation. Use the ledger card and bundled `@Computer`.

| Lane | When | Command |
| --- | --- | --- |
| **Dev build** | Compile / debug one screen | Preflight below → `xcodebuild` → `open --args` (see [`references/launch-args.md`](references/launch-args.md)) |
| **One-flow proof** | Stamp one flow after UI edit | `npm run testing:ledger-run -- --platform macos --screen <id> --flow <flow> --card-only` → canonical launch from the card → bundled `@Computer` → `ledger:record-flow` |
| **Post-parallel closeout** | After disjoint Swift edits | `npm run testing:ledger-batch-plan -- --platform macos --limit 10` → sequential, source-local bundled `@Computer` proof |

## Pass signals

| Layer | Pass |
| --- | --- |
| API | `curl -fsS http://127.0.0.1:8787/health` |
| Build | `xcodebuild … -scheme LikemindedMac -destination 'platform=macOS'` exit 0 |
| Capture | Fresh bundled `@Computer` capture at the ledger `recent_screenshot_ref` |
| Control | Ledger `controls[].result=pass` + `tested_source_hash` = `source_hash` |
| UI | `ui_validation.result=pass` vs ledger `mockup_ref` + `DESIGN.md` |
| Batch | `testing:ledger-batch-plan` is empty for the touched source-local band |

Mockup compare **before** CUA: classify **match** / **intentional variation** / **gap**; record in `visual_parity.notes`.

## Iteration (phases 2–5)

After any fix, rerun the **full lane** — not only the failing step.

```
run lane → collect pass/fail + timings → failure | inefficiency → root cause → retest full → repeat
```

| Situation | Loop |
| --- | --- |
| One screen | Repeat the ledger card → canonical launch → bundled `@Computer` → record loop; recompile if Swift changed |
| Post-parallel | Drain one source-local `testing:ledger-batch-plan` sequentially until empty |
| Captures drift | Recapture with bundled `@Computer` → compare `mockup_ref` → fix or document an intentional difference |

**Stop when:** consecutive full runs pass **and** the last full iteration was **empty** (no failure, inefficiency, simplify, optimize, or automate debt — see workflow-hardening § Empty last iteration).

## Preflight → build → run

```bash
curl -fsS http://127.0.0.1:8787/health          # or: npm run dev:api:validation
(cd apps/ios-macos && xcodegen generate)        # after project.yml edits

xcodebuild \
  -quiet \
  -project apps/ios-macos/Likeminded.xcodeproj \
  -scheme LikemindedMac \
  -destination 'platform=macOS' \
  -derivedDataPath .build/macos \
  build

open -F -n .build/macos/Build/Products/Debug/LikemindedMac.app --args \
  --likeminded-reset-auth-session \
  --likeminded-dev-auth-bypass \
  --likeminded-dev-auth-token "${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}" \
  --likeminded-dev-auth-name "${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}" \
  --mac-screen <screen>
```

**Kill/relaunch (validation only):** lock holder via `cross_platform_validation_lock.sh` + `macos_kill_if_lock_holder` — never bare `pkill` from parallel agents.

**Logs:** `log stream --level debug --style compact --predicate 'process == "LikemindedMac"'`

## Per-screen checklist

1. Ledger JSON + `mockup_ref` + open `requires_fixing` / controls
2. Swift in `MacScreens.swift` (or `MacDesignSystem`)
3. `xcodebuild` compile
4. Proof via **lane table** above (not ad-hoc `screencapture` or legacy CUA)
5. **Capture vs reference** — `output/validation/macos-screens/<screen>.png` compared to ledger/concept `mockup_ref` **before** claiming parity or done; fix gaps and recapture if mismatch
6. `ui_validation.result=pass` only when plate + `DESIGN.md` agree

## Hard rules

- **Ledger owns status** — `validation/screens/*.json`; no parallel pass/fail tables.
- **Scripts, not improvisation** — no hand-built Quartz capture one-liners in agent loops.
- **Sequential proof** — one `xcodebuild` / one app instance for capture+CUA batch; see `validation.md` § Parallel.
- **`LIKEMINDED_API_BASE_URL`** in Info.plist — never hardcode URLs in Swift.
- **Native macOS** — not Catalyst; scheme `LikemindedMac`, `-destination 'platform=macOS'`.
- **Validation data** — `npm run dev:api:validation` + `npm run reset:validation-data` → `data/validation-db`.
- **Signing-log privacy** — use `xcodebuild -quiet` for routine builds. If verbose signing diagnostics are required, preserve `pipefail` and redact account emails, certificate hashes, and provisioning-profile UUIDs before output; never persist the raw log.

## Progressive disclosure

| Load when | File |
| --- | --- |
| `--mac-screen` / launch recipes | [`references/launch-args.md`](references/launch-args.md) |
| Fixture plates vs API | [`references/fixtures.md`](references/fixtures.md) |
| Build failed / wrong window / capture | [`references/troubleshooting.md`](references/troubleshooting.md) |
| Source tree / bundle / LiveKit | [`references/layout.md`](references/layout.md) |
| Semantic proof / multi-monitor | Testing-ledger card + bundled `@Computer` |
| All npm proof commands | `docs/workflows/validation.md` |

## Related

- `build-ios-app` — iOS surface.
- `AGENTS.md` trigger map — current testing-ledger and canonical-app routes.
