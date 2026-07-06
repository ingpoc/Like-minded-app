# Validation

Global `AGENTS.md` owns instruction control. Commands and control owners only.

## Lazy retrieval

1. `npm run goal:next`
2. **One screen:** `npm run ledger:screen -- --platform ios|macos --screen <id> --section ui|controls|all`
3. **Gap audit only:** `npm run ledger:open` / `ledger:stale` — not for a single known screen
4. Touch open ledger JSON + active `PROGRESS.md` track section only

Do not load `GOAL.md`, `DESIGN.md`, full `PROGRESS.md`, `validation/README.md` status (none), mockup dirs, or source trees for status questions.

## Control owners

| What | Owner |
|------|--------|
| Control status, success criteria, evidence | `validation/{ios,macos}/*.json` |
| Roadmap checkbox | `PROGRESS.md` active track |
| Link index (no status) | `node validation/_generate.js` → `validation/README.md` |
| macOS proof routing | `docs/workflows/validation.md` § macOS proof |

**Actionable** = `fail`, `pending`, empty `controls`, `stale_pass` (hash mismatch), or `blocked` with automation-unavailable wording (not LiveKit/Apple infra).

`npm run verify:ledger-progress` — open controls need unchecked `PROGRESS.md` owners. Also fails on: sibling status tables, phase graveyard in PROGRESS, stale `route_contract` vs ledger, PROGRESS `stale_pass` checkboxes out of sync with JSON.

## Commands (by need)

Default validation profile (override with env):

```bash
export LIKEMINDED_VALIDATION_USER=validation-gurusharan
export LIKEMINDED_VALIDATION_NAME="Gurusharan Gupta"
```

| Need | Command |
|------|---------|
| Route | `npm run goal:next` |
| One screen ledger | `npm run ledger:screen -- --platform macos --screen <screen> --section ui\|controls\|all` |
| All open controls (gap) | `npm run ledger:open` / `ledger:stale` |
| Syntax | `npm run check` |
| API contract | `npm run smoke:mvp` |
| Release static | `npm run verify:release-config` |
| Goal contract | `npm run verify:goal` |
| macOS captures | `npm run verify:macos-screens` |
| macOS post-parallel batch | `npm run macos:validation-batch` (full capture + CUA) |
| macOS / iOS stale reproof | `npm run macos:validation-batch -- --stale-only --cua-only` · `npm run verify:ios-screens -- --stale-only` · `npm run validation:wave2-reproof` |
| iOS simulator | `npm run verify:simulator-local` |
| Local product loop | `npm run verify:local-product-loop` |
| Google OAuth readiness | `npm run verify:google-auth-config` |
| Render deploy preflight | `npm run deploy:render-preflight` |
| **One screen capture (locked)** | `./script/cross_platform_screen_validate.sh --screen <id> --platform ios\|both` |
| iOS batch captures | `npm run verify:ios-screens` (default list) or `--stale-only` for ledger-driven reproof |
| Seeded API | `npm run dev:api:validation` |
| Reset seed | `npm run reset:validation-data` |
| macOS CUA (one screen) | `macos_cua_preflight.sh` → `macos_audit_prepare.sh` → `macos_cua_screen.sh <screen>` |
| Stale screen list | `node script/ledger_stale_screens.js --platform ios\|macos` |
| macOS minimum window | `./script/macos_audit_window_matrix.sh small` = 1120×901 |
| Phase checklist | `npm run phase:preflight -- <N>` |
| External gate | `npm run verify:external-preflight` |
| Hash refresh | `npm run ledger:refresh-hashes` |
| Record CUA | `node script/ledger_record_control.js` / `ledger_stamp_screen.js` |

## Ledger fields

- Screen `source_hash` — from `source_files`; refresh after Swift edits.
- Screen `ui_validation` — visual pass/fail against `reference_mockup_ref`, `recent_screenshot_ref`, and `DESIGN.md`.
  - `validated`: what was checked for UI only.
  - `pending_validation`: UI checks still not run.
  - `requires_implementation`: missing UI surface/component.
  - `requires_fixing`: visible UI mismatch or unclear component.
  - Control behavior stays in `controls[]`, not `ui_validation`.
- Control `expected` — success criteria; `result` — pass/fail/blocked/pending.
- `last_tested_at`, `tested_source_hash`, `last_test_method` — set on proof; `pass` stale when hash differs.

## Rules

1. Fail/stub → keep unchecked `PROGRESS` owner in same session.
2. Never claim ledger-green while actionable rows exist (unless track owns them).
3. Update JSON + PROGRESS; do not add narrative status tables elsewhere.
4. While `macos_cua_screen.sh` exists, do not claim GUI automation unavailable in evidence.
5. Parallel UI implementation per ledger JSON is OK; **sequential proof** after (see § Parallel screen validation) — not concurrent build/capture/seed.
6. `README.md` defers Phase 9 until `goal:next` shows clean tracks.

## Session alignment

Project hooks (`.cursor/hooks.json`): `sessionStart` injects compact `goal:next` output. Authoritative gate: `npm run verify:ledger-progress` (includes context-routing checks — no status tables in `validation/README.md`, no Phase 0–8 in `PROGRESS.md`).

## macOS proof (pick one)

See § Parallel screen validation for locks and two-wave model. iOS single-screen: `cross_platform_screen_validate.sh --platform ios`.

| Situation | Command |
|-----------|---------|
| One screen, API up | `macos_cua_preflight.sh` → `macos_audit_prepare.sh <screen>` → `macos_cua_screen.sh <screen>` |
| After parallel UI edits (full macOS closeout) | `npm run macos:validation-batch` |
| Captures only | `npm run verify:macos-screens` |
| Stale controls only (macOS) | `npm run macos:cua-reproof` (= `--stale-only --cua-only`) |
| Stale controls only (iOS) | `npm run verify:ios-screens -- --stale-only` |
| Both platforms stale | `npm run validation:wave2-reproof` |

Do not run capture/CUA in parallel across agents. Mockup path: ledger `mockup_ref` per screen.

## Parallel screen validation

### Two-wave model (default for multi-screen work)

| Wave | Parallel? | Work |
|------|-----------|------|
| **1 — Code** | Yes | Disjoint Swift edits per `validation/{ios,macos}/*.json` + ledger hash/notes |
| **2 — Proof** | **No** | One `reset:validation-data` (if needed) → one iOS build → one macOS build → **sequential** captures |

Do **not** spawn one agent per screen for build+capture+fix. Parallel UI agents + concurrent `xcodebuild` / `simctl launch` / `open` caused SIGKILL, wrong PNGs, and corrupt seed data in practice.

After wave 1 finishes: `./script/cross_platform_screen_validate.sh --screen <id> --platform ios|both` per screen, `npm run verify:ios-screens -- --stale-only` for iOS stale-pass, or `npm run macos:validation-batch -- --stale-only --cua-only` for macOS stale-pass.

### Locks (macOS uses `lockf`; Linux uses `flock`)

Never raw `pkill`, `open`, or `simctl launch` without `./script/cross_platform_validation_lock.sh`. Never bare `pkill -9 LikemindedMac` — use `macos_kill_if_lock_holder` from `script/macos_canonical_app.sh` (holder sets `LIKEMINDED_HOLDS_MACOS_APP_LOCK=1`).

| Resource | Lock | Serialize |
|----------|------|-----------|
| `api` | `:8787` validation API start/stop | yes |
| `seed` | `npm run reset:validation-data` | yes |
| `ios-sim` | `simctl launch` / booted simulator app | yes |
| `macos-app` | `LikemindedMac` launch / `macos_kill_all` | yes |
| `macos-capture` | `screencapture` + CUA window focus | yes |
| `xcodebuild-ios` | iOS build (`.build/ios-simulator`) | yes |
| `xcodebuild-macos` | macOS build (`.build/macos`) | yes |

```bash
# Wrapper (preferred)
./script/cross_platform_validation_lock.sh with_lock ios-sim bash -c '...'

# Single-screen entry (skips API/seed when :8787 healthy on validation-db)
./script/cross_platform_screen_validate.sh --screen 07-meet --platform ios
./script/cross_platform_screen_validate.sh --screen 04-profile-populated --platform both
```

Lock files: `/tmp/likeminded-validation-locks/` (600s wait). macOS `--mac-screen` resolves via bash cases in `cross_platform_screen_validate.sh` (profile screens) then ledger `source_files` parenthetical (e.g. `(meetOverview)`).

### Seed + API timing

- Single owner of `:8787` during seed + capture. Stop API before seed if `reset:validation-data` fails mid-run against a live server.
- Simulator auth gate (“Could not connect to the server”) often means `:8787` was killed by another agent — not a wrong plist URL. Real Apple/Google/wallet sign-in needs `APPLE_AUTH_BYPASS=0` and matching `GOOGLE_*` / `WALLETCONNECT_*` env; use `--likeminded-dev-auth-bypass` only for seeded capture.
- `curl -s http://127.0.0.1:8787/health` → `dbPath` must contain `validation-db` before native capture; check `livekit`, `googleAuth`, `walletAuth` when testing those flows.

### Ledger lookup

Use full ledger id: `npm run ledger:screen -- --platform ios --screen 22-settings-info` (exact file stem). Fuzzy match without the numeric prefix can hit the wrong settings ledger.

### iOS capture hygiene

- Target one simulator UDID from `./script/build_and_run.sh` — not `booted` when multiple simulators are running.
- Prefer build-only + explicit `simctl launch` with validation args; `./script/build_and_run.sh run` auto-launches without deep links.
- `verify:ios-screens` builds **once** then sets `LIKEMINDED_SKIP_IOS_BUILD=1` per screen; single `validate:screen` auto-skips xcodebuild when `.build/ios-simulator/.../Likeminded.app` is fresh (still installs to sim) — `LIKEMINDED_FORCE_IOS_BUILD=1` to force rebuild.
- Wait **15–60s** after launch for dev-auth before screenshot.
- When `simctl` drops `--likeminded-start-*` args, use `LIKEMINDED_VALIDATION_SCREEN` UserDefaults fallback (see `build-ios-app` skill).

### macOS capture hygiene

- Re-apply `--mac-screen` after dev sign-in (`MacRootView.onChange(of: isSignedIn)`).
- Put **`--mac-screen <name>` before other launch flags** (order-sensitive; wrong order → no capturable window).
- Auth welcome: **no** dev bypass; `--likeminded-reset-auth-session --mac-screen welcome --likeminded-validation-welcome`.
- Settings how-it-works: `--mac-screen settingsSoulmate --mac-settings-pane howItWorks` only (dual `--likeminded-start-settings-info` + pane can yield 0 windows).
- Capture by **PID window id** (`macos_cua_focus_window.sh`). Run `macos_cua_preflight.sh` if `cua-driver` calls timeout.
- **Multi-monitor:** defaults in `macos_cua_preflight.sh` (`MACOS_CUA_DISPLAY=DELL`, `MACOS_CUA_LOCAL_COORDS=1`). Align: `macos_cua_focus_window.sh`. Contract: `~/.agents/skills/macos-cua/references/displays.md`.

## Delegated verification

`validation-release` agent (`gpt-5.4-mini`, medium) for read-heavy simulator/screenshot runs only. Main thread owns product decisions and file edits.

## Update this file when

Commands, ledger schema, or control-owner paths change—not for per-screen status (that lives in JSON).
