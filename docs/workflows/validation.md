# Validation

Global `AGENTS.md` owns instruction control. Commands and control owners only.

## Harness routing

Cursor Auto orchestrates. Classify internally; do not wait for the user to name a harness.

### Decision order (first match wins)

1. **Session boundary** — fresh turn, "what's next", gap → `npm run goal:next`; no LLM sidecar
2. **Deterministic proof** — ledger/build/verify script exists → run it; no LLM sidecar
3. **Build lane** — implement/fix/iterate → Cursor main thread
4. **Merge gate** — signals below → `codex-review` before commit/PR/push; fix P0/P1
5. **Parallel disjoint read** — large unrelated map while main has local work → `explore` only
6. **Stale routing audit** — competing owners / goal-vs-dirty → `cost_scan` (read-only)

### Merge-gate (`codex-review`)

Invoke when implementation for this slice is done **and** any of: next action is commit/PR/push; non-trivial diff (3+ files, or auth/API/schema/validation JSON); ship/merge intent.

Skip when still editing/failing; trivial typo/comment unless security/auth; already reviewed this diff since last source edit.

### Trivial-fix (no subagent)

Main thread when **all**: localized UI bug with screenshot/repro; at most 1-2 files and about 30 lines; compile check enough (no ledger stamp). Interrupt a stalled worker (over 5 min) and finish on main.

### Repo-specific lanes

| Lane | Harness |
| --- | --- |
| Ledger sole-owner drain | `@testing-ledger` Mode **B** (~8–12); main verifies hash/stale |
| Ledger flow owner (one hot flow) | `@testing-ledger` Mode **C** |
| macOS multi-screen closeout | Parallel implement; sequential bundled `@Computer` proof |

### Native validation parallelism

Two waves: parallel **code** per ledger JSON; **sequential proof** (seed → build → capture). Use `cross_platform_validation_lock.sh` for kills/launches/captures.

| Phase | Parallel? | Tool |
| --- | --- | --- |
| UI per screen | Yes — disjoint ledger JSON + platform slices | Subagents or main |
| `xcodebuild` (either) | **No** | `cross_platform_validation_lock.sh` |
| iOS screenshot / `simctl` | **No** | `cross_platform_screen_validate.sh` |
| macOS screenshot / Computer | **No** — one `LikemindedMac` | testing-ledger + `@Computer` |
| `reset:validation-data` | **No** — sole `:8787` | lock `seed` |
| API after `server.js` | No | `npm run smoke:mvp` |

Scripts own proof. Subagents own bounded sidecars. Main thread owns integration.

## Lazy retrieval

1. `npm run goal:next` — **work bucket first** (`session/work-bucket.json`), then `first_command`
2. **One screen:** `npm run ledger:screen -- --platform ios|macos --screen <id> --section ui|controls|all`
3. **Gap audit only:** `npm run ledger:open` / `ledger:stale` — not for a single known screen
4. Touch open ledger JSON + active `PROGRESS.md` track section only

Do not load `GOAL.md`, `DESIGN.md`, full `PROGRESS.md`, `validation/README.md` status (none), mockup dirs, or source trees for status questions.

## Control owners

| What | Owner |
| ------ | -------- |
| Logical screen + flow status (both platforms) | `validation/screens/*.json` |
| Flow pass/fail per platform | `flows[].validation.{ios,macos}` |
| Atomic UI controls (optional regression) | `controls.{ios,macos}[]` |
| Roadmap checkbox | `PROGRESS.md` active track |
| Link index (no status) | `node validation/_generate.js` → `validation/README.md` |
| Legacy archive (read-only) | `validation/_legacy/{ios,macos}/` |
| macOS proof routing | `docs/workflows/validation.md` § macOS proof |

**Actionable** = open `flows[]` with `fail`, `pending`, `stale-pass`, or infra `blocked` on both platforms where applicable.

`npm run verify:ledger-progress` — open flows need unchecked `PROGRESS.md` owners. Also fails on: sibling status tables, phase graveyard in PROGRESS, stale `route_contract` vs ledger, PROGRESS `stale_pass` checkboxes out of sync with JSON.

## Commands (by need)

Default validation profile (override with env):

```bash
export LIKEMINDED_VALIDATION_USER=validation-gurusharan
export LIKEMINDED_VALIDATION_NAME="Gurusharan Gupta"
```

| Need | Command |
| ------ | --------- |
| Continue previous session | `npm run session:work` / `npm run session:stamp -- --summary "…"` |
| Route | `npm run goal:next` |
| One screen ledger | `npm run ledger:screen -- --platform macos --screen <logical-id> --section flows\|controls\|all` |
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
| Signed iOS export gate | `npm run verify:ios-release-candidate -- /absolute/path/to/export/Payload/Likeminded.app` |
| Hash refresh | `npm run ledger:refresh-hashes` |
| Record flow proof | `npm run ledger:record-flow` |
| Sync flows from controls | `npm run ledger:sync-flows` |
| Capture closeout | `npm run ledger:capture-closeout` |
| Refresh platform hashes | `npm run ledger:refresh-hashes` |
| Stamp stale reproof (batch) | `npm run ledger:stamp-stale` |
| Session brief (anti-redo) | `npm run ledger:brief` |
| Testing-ledger queue | `npm run testing:ledger-next` (`@testing-ledger` skill) |
| Testing-ledger session | `./script/testing_ledger_session.sh preflight\|next\|record` |
| Add discovered flow | `npm run testing:ledger-add-flow` (see skill `references/add-flow-criteria.md`) |
| One flow packet | `npm run ledger:flow -- --platform ios\|macos --screen <id> --flow <flow-id>` |
| Production gate | `npm run verify:production-ready` |
| Record control (legacy detail) | `node script/ledger_record_control.js` / `ledger_stamp_screen.js` |

### Production readiness (TestFlight MVP)

Contract: `validation/production-contract.json` — defines in-scope screens, out-of-scope features, and when **production-ready** is claimable.

| Need | Command |
| ------ | --------- |
| One flow agent packet | `npm run ledger:flow -- --platform ios\|macos --screen <id> --flow <flow-id>` |
| Text packet (compact) | add `--text` |
| Backfill `flows[].proof` | `npm run ledger:apply-proof` |
| Production gate (composite) | `npm run verify:production-ready` |

External TestFlight evidence uses `release/testflight-evidence.json` schema 2. It requires the processed iOS build number and upload time, approved external Beta App Review, the invite-only `Likeminded Early Access` group with public links disabled, first external installation, real Apple sign-in, LiveKit, cross-user isolation, and Apple-revoked account deletion proof.

**Proof tiers** (`flows[].proof.tier`): `capture` < `cua-click` < `api-persist` < `real-auth` / `real-livekit`.
`ledger:record-flow` rejects `pass` when `last_test_method` is below tier (unless `--force-tier`).
Screen/control stamping also fails closed by tier: a capture stamp cannot satisfy a click-tier control or overwrite stronger evidence, and flow sync preserves an equal-or-stronger fresh explicit flow record.
For annotated `source_files` entries such as `SomeView.swift (CirclesPrototypeView)`, hashing covers the complete Swift type declaration; edits anywhere inside that type make its proofs stale.

**Agent packet fields:** preconditions, success_signals, mockup_ref, baseline_screenshot (`platforms.*.recent_screenshot_ref`), proof_screenshot (`validation.*.screenshot_ref`), run command, record command.

Manual `@Computer` proofs span separate tool calls, so they must use `testing_ledger_runtime_lock.sh lease-acquire computer-prove`; retain the returned token and call `lease-release <token>` after recording the flow or bounded same-screen band. The lease holder expires after 30 minutes by default, preventing a crashed proof session from blocking the lane indefinitely.

For Computer calls, identify the validation app by its canonical full path from `script/macos_canonical_app.sh`: `<repo>/.build/macos/Build/Products/Debug/LikemindedMac.app`. Do not use `LikemindedMac` (not the visible app name), `Likeminded` (shared by multiple running apps), or the bundle ID (shared by multiple local build products).
Use the generated `RECORD_PASS` unchanged after saving the capture at its declared path; it already carries the screenshot and mockup-comparison evidence required by `ledger:record-flow`. A help read (`npm run session:stamp -- --help`) is non-mutating.

For queue closeout, keep one stable seed/build/launch for an 8–12-flow same-screen band and record each flow before moving to the next. Stop on the first failure. Reproofs and harness retries do not count as new coverage; after two pre-product harness failures, repair and independently validate the harness before reopening the product surface.

The session work bucket resumes a native screen through the compact `testing:ledger-run --screen … --card-only` route. Use `ledger:screen --section all` only for explicit schema diagnosis; it is not a normal continuation command.
Auto-stamp consults the authoritative testing-ledger selector before preserving a screen. When that screen has no open flow, the bucket advances to the next open flow instead of pinning completed validation work because its ledger evidence is dirty.
The macOS launch argument comes from the same `macScreenForLogical` map as the testing-ledger card; source-symbol hints such as `communityDetailScreen` are never treated as runtime route names.
An authoritative `ledger:record-flow --result pass` atomically resolves matching open, fixing, or retest-ready issue capsules. Product failures described through fresh AX/Computer readback remain app-class findings unless the observation names a concrete harness symptom.

Harness-class issue capsules route to the runtime/adapter owner rather than a product screen source. The shared issue queue is written by temporary-file rename so concurrent readers never treat a torn capsule as product evidence.

## Agent validation workflow (hardened)

Phases follow elon-algorithm: **make it work → validate → simplify → optimize → automate**. Status lives in JSON only; agents must not re-discover controls from source when ledger already answers the question.

### Session start (do not redo pass work)

```bash
npm run goal:next
npm run ledger:brief          # counts + trust_pass rule
# Ledger flow testing (macOS CUA): @testing-ledger skill
npm run testing:ledger-next   # one open flow — do not use ledger:open as queue
```

| Question | Command | Do **not** load |
| ---------- | --------- | ----------------- |
| Next flow to prove (macOS) | `npm run testing:ledger-next` | `ledger:open` full gap scan |
| What's open? | `npm run ledger:open` | Full source trees, mockup dirs |
| What's stale after edits? | `npm run ledger:stale` | All validation JSON |
| One screen detail | `npm run ledger:screen -- --platform ios\|macos --screen <id> --section flows` | Other screens |
| Record proof | `npm run ledger:record-flow` (preferred) or `ledger:record-control` | — |

**Trust `flows[].validation.*.result: pass`** unless `ledger:stale` lists the row or `source_files` changed (`tested_source_hash` ≠ current `platforms.*.source_hash`).

### Status hierarchy (single chain)

| Layer | Owner | Purpose |
| ------- | ------- | --------- |
| **Primary** | `flows[].validation.{ios,macos}` | User journey pass/fail/pending/blocked |
| **Atomic** | `controls.{ios,macos}[]` | Per-button regression detail |
| **Visual** | `platforms.*.ui_validation` | Mockup parity (screen-level) |

After CUA/capture: stamp controls → `npm run ledger:sync-flows` (or `ledger:record-flow` which syncs controls). Never mark `pass` without `evidence`, `last_test_method`, `tested_source_hash`.

### Success criteria (where it lives)

| Field | Location | Meaning |
| ------- | ---------- | --------- |
| Journey steps | `flows[].steps[]` | What the user does |
| Atomic expectation | `controls.*.expected` | Per-control success |
| Proof | `flows[].validation.*.evidence` | Dated method + outcome |
| Infra skip | `flows[].validation.*.blocker` | Apple sign-in, LiveKit only |

### Proof tiers (pick one; default Tier A)

| Tier | When | Commands |
| ------ | ------ | ---------- |
| **A — Status scan** | Session start, "what's pending?" | `goal:next` → `ledger:brief` → `ledger:open` |
| **B — One screen** | Fix/verify one open flow | Tier A + `ledger:screen` + platform proof script |
| **C — Batch closeout** | Multi-screen stale reproof | `validation:wave2-reproof` or `macos:validation-batch --stale-only` |

**macOS one screen:** `macos_cua_preflight.sh` → `macos_audit_prepare.sh <screen>` → `macos_cua_screen.sh <screen>` (stamps controls + syncs flows).

**iOS one screen:** `./script/cross_platform_screen_validate.sh --screen <logical-id> --platform ios` — capture auto-runs `ledger:capture-closeout` (screenshot ref + control stamp + flow sync). Manual: `npm run ledger:record-flow`.

Profile sub-screen captures use the production Profile navigation destinations: `profile-edit` launches with `--likeminded-start-profile-edit`, and `profile-signals` launches with `--likeminded-start-profile-signals`.

**Capture closeout (both platforms):** `npm run ledger:capture-closeout -- --platform ios|macos --screen <id> --screenshot <path> [--stamp auto|--stale-only]`

### Anti-patterns (agents must avoid)

- Using `ledger:open` as the per-turn work queue — use `testing:ledger-next`
- Grep/Swift walk to inventory buttons when `ledger:open` already lists gaps
- Re-run CUA on `pass` flows without stale signal
- Source-code gap audit when `gap-flows-registry.json` + `ledger:apply-gaps` owns backlog
- Writing status tables to README, PROGRESS, or sibling `.md` ledgers
- Parallel capture/CUA across agents (use validation locks)

## Ledger template (schema v2)

Copy before adding a screen or flow:

| Template | Path |
| ---------- | ------ |
| New logical screen | `validation/screens/_template.screen.json` |
| New flow object | `validation/screens/_template.flow.json` |
| Gap backlog (batch apply) | `validation/gap-flows-registry.json` → `npm run ledger:apply-gaps` |

### Adding a flow (checklist)

1. Pick `logical_screen_id` where the user **starts** the journey (`origin`).
2. Copy `_template.flow.json`; set globally unique `id` (kebab-case).
3. Fill `control_ids.ios` and/or `control_ids.macos` (empty + `not-applicable` on the other side).
4. Set `validation.{platform}.result` to `pending` until runtime proof; never `pass` without evidence.
5. Add matching rows to `controls.{ios,macos}[]` on the same screen file.
6. Use `destinations[]` when the flow hands off to another logical screen.
7. Run `npm run ledger:open` — new `pending` flows should appear.

### Validation result values

| `result` | When |
| ---------- | ------ |
| `pending` | Implemented in app; not runtime-validated yet |
| `pass` | Proven with evidence + `last_test_method` + `tested_source_hash` |
| `blocked` | Infra only (Apple sign-in, LiveKit) — set `blocker` |
| `not-applicable` | No control on that platform for this flow |
| `fail` | Runtime proof failed |

## Ledger fields (schema v2 — `validation/screens/<id>.json`)

- `logical_screen_id` — canonical screen slug (e.g. `meet`, `onboarding`)
- `platforms.ios` / `platforms.macos` — source files, mockup, entry points, `ledger_legacy_id` (e.g. `07-meet`)
- `flows[]` — **primary status owner** for user journeys originating on this screen
  - `flows[].id` — globally unique flow id
  - `flows[].validation.ios|macos` — `result`, `evidence`, `last_test_method`, `tested_source_hash`
  - `flows[].destinations[]` — handoff to other logical screens
  - `flows[].control_ids` — links to atomic controls
- `controls.ios[]` / `controls.macos[]` — atomic UI elements (regression detail)
- Platform `source_hash` — stale when Swift edits change source_files
- `ui_validation` / `visual_parity` — per-platform visual pass (under `platforms.*`)

## Ledger fields (legacy — archived)

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
| ----------- | --------- |
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
| **1 — Code** | Yes | Disjoint Swift edits per `validation/screens/*.json` + ledger hash/notes |
| **2 — Proof** | **No** | One `reset:validation-data` (if needed) → one iOS build → one macOS build → **sequential** captures |

Do **not** spawn one agent per screen for build+capture+fix. Parallel UI agents + concurrent `xcodebuild` / `simctl launch` / `open` caused SIGKILL, wrong PNGs, and corrupt seed data in practice.

After wave 1 finishes: `./script/cross_platform_screen_validate.sh --screen <id> --platform ios|both` per screen, `npm run verify:ios-screens -- --stale-only` for iOS stale-pass, or `npm run macos:validation-batch -- --stale-only --cua-only` for macOS stale-pass.

### Locks (macOS uses `lockf`; Linux uses `flock`)

Never raw `pkill`, `open`, or `simctl launch` without `./script/cross_platform_validation_lock.sh`. Never bare `pkill -9 LikemindedMac` — use `macos_kill_if_lock_holder` from `script/macos_canonical_app.sh` (holder sets `LIKEMINDED_HOLDS_MACOS_APP_LOCK=1`).

| Resource | Lock | Serialize |
| ---------- | ------ | ----------- |
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

- Auth gate capture: `--screen auth-gate` (unsigned; `--likeminded-reset-auth-session` only). `--screen auth` uses dev bypass → signed-in Meet, not the gate.
- Target one simulator UDID from `./script/build_and_run.sh` — not `booted` when multiple simulators are running.
- Prefer build-only + explicit `simctl launch` with validation args; `./script/build_and_run.sh run` auto-launches without deep links.
- `verify:ios-screens` builds **once** then sets `LIKEMINDED_SKIP_IOS_BUILD=1` per screen; single `validate:screen` auto-skips xcodebuild when `.build/ios-simulator/.../Likeminded.app` is fresh (still installs to sim) — `LIKEMINDED_FORCE_IOS_BUILD=1` to force rebuild.
- Wait **15–60s** after launch for dev-auth before screenshot.
- When `simctl` drops `--likeminded-start-*` args, use `LIKEMINDED_VALIDATION_SCREEN` UserDefaults fallback (see `build-ios-app` skill).
- Focused iOS proof launches include `--likeminded-clear-validation-screen`; this removes any stored fallback before applying the current deep-link arguments so a prior chat/recap capture cannot hijack the next screen.
- For fixture-backed rows that can move while async data loads, use a bounded semantic tap retry and verify the destination; do not fail or pass from one stale AX coordinate.
- iOS proof build freshness includes both `Sources/LikemindedApp` and `Sources/Shared`; a newer shared Swift file must force a rebuild before interaction.

### macOS capture hygiene

- Re-apply `--mac-screen` after dev sign-in (`MacRootView.onChange(of: isSignedIn)`).
- Put **`--mac-screen <name>` before other launch flags** (order-sensitive; wrong order → no capturable window).
- Auth welcome: **no** dev bypass; `--likeminded-reset-auth-session --mac-screen welcome --likeminded-validation-welcome`.
- Settings how-it-works: `--mac-screen settingsSoulmate --mac-settings-pane howItWorks` only (dual `--likeminded-start-settings-info` + pane can yield 0 windows).
- Capture by **PID window id** (`macos_cua_focus_window.sh`). Run `macos_cua_preflight.sh` if `cua-driver` calls timeout. Pointer sanity: `npm run macos:cua-pointer-smoke`.
- **Multi-monitor:** `MACOS_CUA_FOLLOW_WINDOW=1` (default with `MACOS_CUA_NO_FRAME=1`) — overlay follows LikemindedMac window display via `macos_cua_align_displays.py`. Pin with `MACOS_CUA_FORCE_DISPLAY=1 MACOS_CUA_DISPLAY=DELL`. Align once: `macos_cua_focus_window.sh`; batch clicks use `MACOS_CUA_SKIP_OVERLAY=1`. Pointer: one glide (`move_cursor`, overlay-local) + cursorless AX `element_index` click (default); `MACOS_CUA_PIXEL_CLICK=1` forces desktop pixel clicks for no-AX surfaces only. Contract: `~/.agents/skills/macos-cua/references/displays.md`.

## Delegated verification

`validation-release` agent (`gpt-5.4-mini`, medium) for read-heavy simulator/screenshot runs only. Main thread owns product decisions and file edits.

## Update this file when

Commands, ledger schema, or control-owner paths change—not for per-screen status (that lives in JSON).
