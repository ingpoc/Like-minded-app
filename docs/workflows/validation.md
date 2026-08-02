# Validation

Global `AGENTS.md` owns instruction control. Commands and control owners only.

## Lazy retrieval

1. `npm run goal:next` — **work bucket first** (`session/work-bucket.json`), then `first_command`; it never preloads the optional decision graph

Only when that route is insufficient and decision context would change the work,
run `script/project_context.sh` explicitly; it selects a
Python 3.12+ runtime deterministically (`uv` / `PROJECT_CONTEXT_PYTHON` / installed
3.13 or 3.12 / Codex bundled Python) and fails concisely when none is available.
2. **One screen:** `npm run ledger:screen -- --platform ios|macos --screen <id> --section ui|controls|all`
3. **Gap audit only:** `npm run ledger:open` / `ledger:stale` — not for a single known screen
4. Touch open ledger JSON + active `PROGRESS.md` track section only

Do not load `GOAL.md`, `DESIGN.md`, full `PROGRESS.md`, `validation/README.md` status (none), mockup dirs, or source trees for status questions.

## Control Owner

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

`npm run verify:testing-ledger` is the complete testing-owner integrity boundary:
active route/prose validation, ledger tests, migration integrity, and progress
integrity. `npm run check` runs it automatically. Session orchestration consumes
its result plus the bounded `ledger:brief -- --receipt` output; it never writes flow
status or maintains a parallel test checklist.

## Commands (by need)

Default validation profile (override with env):

```bash
export LIKEMINDED_VALIDATION_USER=validation-gurusharan
export LIKEMINDED_VALIDATION_NAME="Gurusharan Gupta"
```

| Need | Command |
| ------ | --------- |
| Continue previous session | `npm run session:work` / `npm run session:stamp -- --screen <id> --platform ios\|macos --summary "…"` |
| Route | `npm run goal:next` |
| One screen ledger | `npm run ledger:screen -- --platform macos --screen <logical-id> --section flows\|controls\|all` |
| All open controls (gap) | `npm run ledger:open` / `ledger:stale` |
| Syntax | `npm run check` |
| API contract | `npm run smoke:mvp` |
| Release static | `npm run verify:release-config` |
| Exported release artifact | `npm run verify:release-candidate -- ios\|macos /path/to/App.app` (platform-specific Store-profile entitlements and exact Google callback are checked; macOS may omit false `com.apple.security.get-task-allow`) |
| Goal contract | `npm run verify:goal` |
| macOS captures | Exact testing-ledger card plus bundled `@Computer` screenshot/state evidence |
| macOS post-parallel batch | `npm run testing:ledger-batch-plan -- --platform macos --limit 10` → sequential bundled `@Computer` proof |
| macOS / iOS stale reproof | Platform batch plan → exact testing-ledger proof routes |
| iOS simulator | `npm run verify:simulator-local` |
| Local product loop | `npm run verify:local-product-loop` |
| Google OAuth readiness | `npm run verify:google-auth-config` |
| Render deploy preflight | `npm run deploy:render-preflight` |
| **One screen capture (locked)** | `./script/cross_platform_screen_validate.sh --screen <id> --platform ios\|both` |
| iOS batch captures | `npm run verify:ios-screens -- <screen-id> [<screen-id>…]` shares one build across a related slice; no IDs uses the default list, and `--stale-only` is ledger-driven reproof |
| iOS targeted proof reuse | After the first build/install in an unchanged source-local band, `LIKEMINDED_REUSE_IOS_INSTALL=1 npm run testing:ledger-run -- --platform ios --screen <id> --flow <id>` reuses the install only when source freshness and built/installed executable SHA-256 identity match for the explicit simulator; mismatch fails before interaction |

Session routing may use only a screen-specific concept plate (with placement plates limited to circle/community surfaces); it must fall back to that ledger's `mockup_ref`, never an unrelated generic concept.
| Seeded API | `npm run dev:api:validation` (reuses healthy `:8787` validation-db; `LIKEMINDED_FORCE_API_RESTART=1` to replace) |
| Reset seed | `npm run reset:validation-data` |
| macOS native proof (one screen) | `testing:ledger-run -- --platform macos --screen <id> --card-only` → canonical launch → bundled `@Computer` |
| Stale screen list | `node script/ledger_stale_screens.js --platform ios\|macos` |
| macOS validation window | Canonical launch defaults to 1200×760; resize only through the app's supported window controls |
| Phase checklist | `npm run phase:preflight -- <N>` |
| External gate | `npm run verify:external-preflight` |
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

**Proof tiers** (`flows[].proof.tier`): `capture` < `computer-use` < `api-persist` < `real-auth` / `real-livekit`.
`ledger:record-flow` rejects `pass` when `last_test_method` is below tier (unless `--force-tier`).

**Agent packet fields:** preconditions, success_signals, mockup_ref, baseline_screenshot (`platforms.*.recent_screenshot_ref`), proof_screenshot (`validation.*.screenshot_ref`), run command, record command.

## Agent validation workflow (hardened)

Phases follow workflow-hardening: **make it work → validate → simplify → optimize → automate**. Status lives in JSON only; agents must not re-discover controls from source when ledger already answers the question.

### Session start (do not redo pass work)

```bash
npm run goal:next
npm run ledger:brief          # counts + trust_pass rule
# Ledger flow testing (macOS native UI): @testing-ledger skill + bundled @Computer
npm run testing:ledger-next   # one open flow — do not use ledger:open as queue
```

### Bounded flow campaign

One agent owns one flow from proof through diagnosis, a coherent same-flow fix batch, deterministic checks, and full retest. File the failure before editing, use retained logs/screens/AX to identify all discoverable faults in that journey, release the runtime lock during source edits, mark the issue retest-ready, then rerun the entire flow. If the same blocker repeats unchanged through three evidence-based recovery cycles, checkpoint it rather than widening scope; continue when each cycle materially narrows a different cause.

Parallelize only independent work: one iOS flow owner and one macOS flow owner may run concurrently, and read-only/disjoint sidecars may audit harness or source slices. Never run two owners on the same platform. Sidecars do not seed, build, launch, prove, mutate the issue queue, or record the ledger. Shared seed/build/capture operations remain serialized by `cross_platform_validation_lock.sh`.

| Question | Command | Do **not** load |
| ---------- | --------- | ----------------- |
| Next flow to prove (macOS) | `npm run testing:ledger-next` | `ledger:open` full gap scan |
| What's open? | `npm run ledger:open` | Full source trees, mockup dirs |
| What's stale after edits? | `npm run ledger:stale` | All validation JSON |
| One screen route + sources | `npm run ledger:screen -- --platform ios\|macos --screen <id> --section route` | Controls, full ledger, other screens |
| One screen full flow packets | `npm run ledger:screen -- --platform ios\|macos --screen <id> --section flows` | Other screens |
| Record proof | `npm run ledger:record-flow` (preferred) or `ledger:record-control` | — |

**Trust `flows[].validation.*.result: pass`** unless `ledger:stale` lists the row or `source_files` changed (`tested_source_hash` ≠ current `platforms.*.source_hash`).

### Source-freeze before family drain

Keep the expensive proof order deterministic: freeze the flow outcomes, review
the proof branch for authoritative visible/persisted readback and complete source
hash coverage, run cheap checks plus the changed journey, batch known P0–P2
findings, then freeze product sources. Create
`output/validation/acceptance/<source-hash>/`, build/install once, and collect
standard/accessibility captures plus affected family proof from that identity.
A proof- or review-discovered source edit returns the screen to targeted
iteration and requires a new hash-keyed package. JSON ledger reports write their
complete buffered payload before exit; a truncated report is a harness failure.

### Status hierarchy (single chain)

| Layer | Owner | Purpose |
| ------- | ------- | --------- |
| **Primary** | `flows[].validation.{ios,macos}` | User journey pass/fail/pending/blocked |
| **Atomic** | `controls.{ios,macos}[]` | Per-button regression detail |
| **Visual** | `platforms.*.ui_validation` | Mockup parity (screen-level) |

After interaction/capture: stamp controls → `npm run ledger:sync-flows` (or `ledger:record-flow` which syncs controls). Never mark `pass` without `evidence`, `last_test_method`, `tested_source_hash`.

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
| **C — Batch closeout** | Multi-screen stale reproof | One platform batch plan; macOS is sequential bundled `@Computer` proof |

**macOS one screen:** request the exact `testing:ledger-run -- --platform macos --screen <id> --flow <id> --card-only` card, acquire its bounded lease, launch the canonical validation app, and use bundled `@Computer`. `dev:macos:validation -- voice-session` routes to functional `profileOnboarding`; select the Voice profile step through semantic UI. Only the legacy `profileVoiceStepPanel` hint uses the empty-profile preview flag. Target the canonical app by full path, inspect fresh semantic state after every action, and pass only from the declared destination/readback—not accepted input dispatch.

**iOS interactive flows:** `testing_ledger_prove_ios.sh` must route every `computer-use` flow explicitly and include it in the failure-enforced closeout case. AX matching normalizes Unicode and whitespace before comparison, so the Simulator's non-breaking-space `Apple Account Verification` label resolves to its tappable `Not Now` button. AX probes are tri-state: a substring match counts as present only when its positive-size frame intersects the Application frame; valid hidden/offscreen matches count as absence, while malformed or missing inventories are errors and never advance an absence streak. Readiness and unresolved/post-dispatch failures write both PNG and AX JSON under `output/validation/testing-ledger/ios/diagnostics/`; a dispatched tap is never replayed through another fallback. `chat/chat-call-headers` waits on the accessible chat body because IDB omits the visible SwiftUI navigation bar on the fixed validation simulator, then tries normalized identifier and label resolution before its three explicit toolbar points. Every point dispatch still has to expose a unique sheet-local marker that this simulator actually publishes in AX: `Scheduling a voice call`, `Scheduling a video call`, or `Mutual match from`. Every Done interaction targets the shared `call-sheet-done` identity and must observe three consecutive samples where that same sheet-local marker is absent; the persistent `Voice call`/`Video call` toolbar labels and background chat content are not dismissal proof. If normal and grace polling still see stale AX state, one durable screenshot refresh crosses the observed IDB cache boundary, waits the measured one-second AX settle, then applies the same rule across five refreshed samples. Each refreshed sample persists its exact matching fields, frames, and visibility under `output/validation/testing-ledger/ios/diagnostics/`; a failed refresh, inventory errors, or missing absence sequence fails. All six assertions must pass and an unobstructed `output/validation/ios-screens/chat.png` must be captured before the four controls are stamped. The proof process exits zero only when `flow_fail=0`; failure exits nonzero explicitly rather than inheriting the status of a final false shell condition. On any zero-exit proof, queue closeout matches the runner-selected platform/screen/flow (not only optional CLI filters), resolves every matching `retest_ready` packet, and is regression-tested by `npm run test:testing-ledger`.

Creation-form proofs must follow the rendered disclosure sequence. For Create Community, the themes flow expands `Add themes (optional)` before targeting `Community themes`; submit proves the required name-and-summary path without treating optional themes as a prerequisite.

When an iOS proof starts the validation API itself, it backgrounds an `exec`-owned server with closed stdin and redirected output. Do not background `npm run dev:api:validation` inside a subshell that must exit first; Bash waits for that job and deadlocks the proof before simulator launch.

Community Detail membership proof treats leaving as destructive: `Leave community` must expose `Leave this community?`, and only the destructive `Leave` confirmation may transition the screen back to `Join community`.

Community member access is membership-scoped. The Members tab shows a join requirement while signed out of the community; the `view-members` proof joins first when necessary and only then accepts the private roster route.

`circle-detail/circle-options-ios` uses the stable `circle-detail-back` AX identifier for deep-link readiness. The shared iOS AX probe matches both `AXIdentifier` and IDB's emitted `AXUniqueId`; omitting either field is a harness defect, not evidence that the app missed the identifier. Harness-class issue packets route directly to the platform proof script rather than a product source file. If that identifier never becomes visible, the proof writes the standard readiness PNG and AX JSON before failing; presentation copy is not the readiness contract.

`circle-detail/secondary-circle-selection` starts from the stable `secondary-circle-card-<id>` AI suggestion in Circles, confirms only inside Circle Detail, waits for the persisted `Your second circle` state, relaunches the signed-in app without reinstalling, and requires the same card to return with the `Your second circle` AX value before reopening it. iOS readiness keys off that stable card identifier rather than presentation-cased heading text; the proof then scrolls until the detail-only action is visibly reachable, captures the reopened selected detail state, and stamps only `make-secondary-circle`. Confirmation publishes `Saving second circle` as its AX value: once that accepted-action state appears, proof waits for the final state without replaying the request; if neither progress nor final state appears, the macOS proof may use one foreground point fallback from the same fresh target. The final reopen must prove the Circle Detail destination through `About this circle`, then require the selected secondary-circle state inside detail; the source-card `Your second circle` value alone cannot pass. A build or local success message alone cannot pass this flow.

### macOS Circle Detail explicit proof

Circle Detail interactions are exact-flow Computer proofs. A screen capture never stamps behavior; record only after the full `circle-detail/<flow>` contract passes.

- `message-circle` is a display outcome: require the exact accessible copy `Circle chat isn’t available in this MVP yet.`; do not claim Messages navigation. SwiftUI accessibility identifiers are not a portable macOS AX proof surface for static text.
- `placement-concern` opens `Circle options` to reveal the Placement concern form, types deterministic text into `Circle concern reason`, submits `Submit placement concern`, requires `Concern registered. Check Profile for re-interview.`, then authenticates and reads `GET /v1/me/placement`; pass only when `concernFlag` is `true` and `placementConcern` exactly matches the authored text. Stamp with `api-persist`.
- `upcoming-meet` is display-only: require accessibility label `Upcoming circle meetup`; do not click or claim a destination.
- `circle-detail-tabs` requires the exact clicked tab to expose AX value `Selected` after every click. Members must show the seeded backend `<count> members` plus exact `socialFormat`, never `members online`; Events must expose `Upcoming circle meetup`; Discussions and Resources must show their exact MVP-unavailable copy and reject the old fake thread/reply and guideline/prompt content. Stamp the five tab controls only after all assertions pass.
- `circle-share` clicks `Copy circle summary`, requires `Circle summary copied.`, then compares `pbpaste` with the seeded backend circle name and description. Reject `Join me`, invitation, link, and URL wording before stamping `share-circle`.

### macOS Profile and Soulmate exact proof

Profile, Signals, Soulmate, and Settings captures are snapshot-only. Redesigned journeys are owned by exact testing-ledger cards and bundled Computer proof:

- Profile evidence scope must show `Voice-informed signals`, the exact inference disclaimer, `Why this placement`, and the exact placement disclaimer. The signals summarize interview/activity evidence; placement reasons explain circle placement and are not proof of each personality inference.
- `profile-populated/review-signals` must open the Signals screen and expose `Done`; `profile-populated/re-interview` must open `AI profile interview`; `profile-signals/done` must return to Profile and expose `Voice-informed signals`.
- Soulmate is a mutual-match MVP, not a browse/feed fixture. `soulmate-discover/soulmate-real-roster` starts at `This week’s introduction`, opens one exact backend match, then requires `Mutual match`, the mutual-selection explanation, the selected person, and truthful interests or unavailable state. `soulmate-overview/save-introduction` must prove `Keep for later` → `Saved for later` with the same person still named → `Show introduction` restoring that person; no refresh/feed control belongs on the destination.
- `soulmate-match/match-back-to-soulmate` must return to `Your mutual matches`. `soulmate-match/message` must preserve the selected match name and open `Open conversation with <same name>`; a generic Messages destination is insufficient.
- `settings/settings-discovery-details` must show the saved-but-not-enforced disclaimer, select `Circles only`, `Circles and communities`, and `Mutual matches only`, set the inclusive age bounds to 18–80, save, and require authenticated API readback with `ageMin=18`, `ageMax=80`, and `visibility=matches_only` before stamping with `api-persist`.

The responsive capture matrix for these five macOS surfaces is 1120×901, 1200×760, and 1440×900. Each size requires a live capture comparison; compile success or one-size capture does not establish responsive parity.

macOS visual capture resolves the canonical app by full path and PID. It must not fall back to the shared display name or bundle ID; identity or focus failures stop proof.

State-changing flow proof must assert the post-mutation AX state, relaunch when persistence is part of the outcome, and restore seeded state when practical. The Communities browse-card membership proof uses the live Join/Leave button inventory for initial, toggled, persisted, and restored states (never a capped snapshot), captures `communitiesBrowse.png` from the same canonical window, then stamps `browse-join-leave`.

`testing:ledger-run` persists each child proof transcript at `output/validation/testing-ledger/<platform>/<screen>--<flow>.log` and includes that path in the run card. Default terminal output is a bounded result/duration summary; `--verbose` replays the full child stdout/stderr. Use the retained log for the issue's observed stage; do not infer the failure from missing stamps alone.

An explicit `testing:ledger-run -- --platform <platform> --screen <screen> --flow <flow>` may reselect an already-pass flow when the issue queue contains a matching `retest_ready` packet. For an operator-requested fresh same-function or visual comparison, add `--reprove`; it requires both exact selectors and cannot expose clean passes to untargeted queue selection. A requested target that cannot execute returns nonzero with a recovery hint instead of reporting an empty-queue success. When the proof exits zero, the runner resolves every matching retest-ready packet and records the durable proof-log path in each resolution.

Fixers normally claim the first open platform issue with `testing:ledger-fix-run -- --platform <platform>`. When a handoff names an exact packet, add `--issue-id <id>`; the selector preserves append order, claims only that open packet, and fails closed when the id is unavailable or belongs to another platform.

Flow-specific tab proof remains on the origin screen while exercising tabs: `community-detail-tabs` enters through a visible community card, proves Upcoming, Members, Resources, and Highlights, then returns to Upcoming. It does not follow nested destinations or stamp browse controls. Failures retain the Computer target, semantic state, and one screenshot.

Bundled Computer targets `<repo>/.build/macos/Build/Products/Debug/LikemindedMac.app` by full path. The display name and bundle ID are ambiguous across local builds; a missing canonical window or identity mismatch fails before proof.

Bundled Computer targets the canonical app by full path and requires fresh semantic state after launch, focus changes, and every action. If semantic state exposes only app/menu scaffolding, capture one screenshot and retry readiness once; empty state from both routes fails and never counts as a valid zero-control screen.

Community Detail setup uses one fresh Computer state to locate `Open <name> community` (with rendered seeded-name matching as fallback). After entering detail, tab assertions re-read live semantic state; Upcoming accepts either the empty-state action or the stable `Upcoming community event` value so API-provided titles remain dynamic. Nested View members, resources, and event rows remain separate exact ledger flows. A readiness failure retains one screenshot plus semantic-state summary, distinguishing blank/loading UI from accessibility extraction failure.

**iOS one screen:** `./script/cross_platform_screen_validate.sh --screen <logical-id> --platform ios` — capture auto-runs `ledger:capture-closeout` (screenshot ref + control stamp + flow sync). Before writing the PNG, the locked capture route detects the Simulator's normalized `Apple Account Verification` alert, taps its AX-visible `Not Now` action through the explicit simulator identity, and fails closed if the alert remains. Manual: `npm run ledger:record-flow`.

`community-members` capture uses the seeded `ai-builders` fixture, matching its interactive member-row proof. The validation user is allowed to read that private roster; `jazz-music` intentionally returns `membership_required` for the nonmember privacy boundary. Do not substitute circle ids such as `reflective-builders` as community fixtures. Roster proof requires returned member identity and the neutral `Community member` role; it never infers online activity or exposes gender from list position.

Soulmate selection proof starts with an empty choice set, taps one explicit row, requires `Confirm 1 choice`, and then verifies the persisted selected user. Preselected fixture rows and ambiguous `Submit` copy are not accepted consent evidence.

Meet history proof targets the `past-row` accessibility identifier and uses `ios_scroll_until_tappable`; AX presence alone is insufficient because SwiftUI may expose an off-screen row with coordinates outside the simulator viewport.

Profile sub-screen captures use the real Profile navigation destinations: `profile-edit` launches with `--likeminded-start-profile-edit`, and `profile-signals` with `--likeminded-start-profile-signals`. They are not duplicate validation-only views. The `profile-edit` snapshot route records visual evidence only; `profile-update-text`, `profile-update-voice`, and `save` remain explicit interaction flows. Typed-update proof enters text, saves it through `PATCH /v1/me/profile`, dismisses the sheet, and re-finds the persisted summary before stamping. Voice proof uses the existing debug-only preview boundary to review or remove captured signals, commits the voice-derived summary through `PATCH /v1/me/profile`, requires the returned `Voice profile saved` receipt, relaunches and refetches the exact persisted summary, and separately reopens without preview to retain the fail-closed `Nothing was recorded or changed` state. Return stamps only after the Profile destination postcondition.

Parenthesized source hints such as `(ProfileEditView)` hash from the matching Swift type declaration, not an earlier call site containing the same name. This keeps current-source proof sensitive to edits inside the owned screen slice.

The `community-detail/community-detail-tabs` `computer-use` flow deep-links to the seeded Jazz Music detail, scrolls the tab row into view, and requires distinct rendered content after tapping Upcoming, Members, Resources, and Highlights before stamping the four controls.

Logical IDs must resolve to their launch arguments as well as their capture slug; `voice-session` launches Profile with `--likeminded-start-voice-session` rather than falling through to Meet.

Preview-only screens may override automatic control stamping with an empty allowlist in `ios_screen_stamp_map.js`; `voice-session` captures layout but leaves live audio, persistence, and dismissal flows pending runtime proof.

Live iOS voice proof uses the server-issued ephemeral Realtime secret and direct SDP exchange. Preview capture never exercises that network path.

**Capture closeout (both platforms):** `npm run ledger:capture-closeout -- --platform ios|macos --screen <id> --screenshot <path> [--stamp auto|--stale-only]`

### Anti-patterns (agents must avoid)

- Using `ledger:open` as the per-turn work queue — use `testing:ledger-next`
- Grep/Swift walk to inventory buttons when `ledger:open` already lists gaps
- Re-run Computer interaction on `pass` flows without a stale signal
- Source-code gap audit when `gap-flows-registry.json` + `ledger:apply-gaps` owns backlog
- Writing status tables to README, PROGRESS, or sibling `.md` ledgers
- Parallel runtime/capture/Computer proof on the same platform; parallelism belongs to the other platform or read-only/disjoint sidecars, with shared operations under validation locks
- Letting a same-name `LikemindedMac` from another worktree remain alive: target the canonical workspace app by full path.
- Deleting testing-ledger lock files manually: `release` clears dead-PID owners while still refusing to displace a live tester or fixer.
- Rejecting a Stage Manager thumbnail before display alignment: focus activates and AX-raises the canonical executable, alignment restores/verifies its logical window, then the AX-backed PID resolver maps that logical window to its real CGWindow ID and enforces the full-size post-alignment gate.
- Treating one pre-call cleanup as exclusive ownership: hold the bounded testing lease for the complete same-screen Computer band.

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

When a visible no-op is deliberately removed, remove its control from the screen ledger and `validation/gap-flows-registry.json`, then regenerate proof packets so no card can recreate or wait for the deleted control.

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
  - `flows[].validation.ios|macos` — `result`, `evidence`, `last_tested_at`, `last_test_method`, `tested_source_hash`
  - `flows[].destinations[]` — handoff to other logical screens
  - `flows[].control_ids` — links to atomic controls
- `controls.ios[]` / `controls.macos[]` — atomic UI elements (regression detail)
- Platform `source_hash` — stale when Swift edits change source_files
- `ui_validation` / `visual_parity` — per-platform visual pass (under `platforms.*`)

`npm run ledger:brief -- --platform <p>` is the compact breadth/debt view. Add `--all --json` only when auditing the complete per-flow history, including last-tested time and current/tested source hashes. Inside an equal status/tier bucket, queue selection prefers never-tested and oldest-tested evidence before recent repeats.

## Ledger fields (legacy — archived)

## Rules

1. Fail/stub → keep unchecked `PROGRESS` owner in same session.
2. Never claim ledger-green while actionable rows exist (unless track owns them).
3. Update JSON + PROGRESS; do not add narrative status tables elsewhere.
4. Bundled `@Computer` availability is determined by a fresh app-state read; do not infer it from legacy helper files.
5. Parallel UI implementation per ledger JSON is OK; **sequential proof** after (see § Parallel screen validation) — not concurrent build/capture/seed.
6. `README.md` defers Phase 9 until `goal:next` shows clean tracks.

## Session alignment

Project hooks (`.cursor/hooks.json`): `sessionStart` injects compact `goal:next` output. Testing-owner gate: `npm run verify:testing-ledger`; its embedded progress check includes context-routing checks—no status tables in `validation/README.md`, no Phase 0–8 in `PROGRESS.md`.

## macOS proof (pick one)

See § Parallel screen validation for locks and two-wave model. iOS single-screen: `cross_platform_screen_validate.sh --platform ios`.

| Situation | Command |
| ----------- | --------- |
| One screen, API up | exact testing-ledger card → canonical launch → bundled `@Computer` |
| After parallel UI edits (full macOS closeout) | `npm run testing:ledger-batch-plan -- --platform macos --limit 10` |
| Captures only | Capture during the exact bundled Computer flow visit; do not stamp behavior from capture alone |
| Stale controls only (macOS) | `npm run testing:ledger-batch-plan -- --platform macos --limit 10` → bundled `@Computer` |
| Stale controls only (iOS) | `npm run verify:ios-screens -- --stale-only` |
| Both platforms stale | Create one batch plan per platform; serialize shared build/seed resources |

Do not run capture/Computer proof in parallel across agents. Mockup path: ledger `mockup_ref` per screen.

When testing proves a flow is obsolete, remove its live control, screen-ledger
flow/control entries, gap-registry entry, and proof branch together. Close the
append-only issue with `testing:ledger-fix-next -- --mark-resolved <id>
--resolution "..."`; do not create a retest target for a deleted flow. The old
Circles `browse-expand` flow is retired: placed users see AI secondary
suggestions plus all remaining read-only Circle types and cannot browse/select
a primary circle.

## Parallel screen validation

### Two-wave model (default for multi-screen work)

| Wave | Parallel? | Work |
|------|-----------|------|
| **1 — Code** | Yes | Disjoint Swift edits per `validation/screens/*.json` + ledger hash/notes |
| **2 — Proof** | **No** | One `reset:validation-data` (if needed) → one iOS build → one macOS build → **sequential** captures |

Do **not** spawn one agent per screen for build+capture+fix. Parallel UI agents + concurrent `xcodebuild` / `simctl launch` / `open` caused SIGKILL, wrong PNGs, and corrupt seed data in practice.

After wave 1 finishes: run targeted iOS proofs or plan a macOS source-local band with `testing:ledger-batch-plan`, then prove it sequentially with bundled `@Computer`.

### Locks (macOS uses `lockf`; Linux uses `flock`)

Never raw `pkill`, `open`, or `simctl launch` without `./script/cross_platform_validation_lock.sh`. Never bare `pkill -9 LikemindedMac` — use `macos_kill_if_lock_holder` from `script/macos_canonical_app.sh` (holder sets `LIKEMINDED_HOLDS_MACOS_APP_LOCK=1`).

| Resource | Lock | Serialize |
| ---------- | ------ | ----------- |
| `api` | `:8787` validation API start/stop | yes |
| `seed` | `npm run reset:validation-data` | yes |
| `ios-sim` | `simctl launch` / booted simulator app | yes |
| `macos-app` | `LikemindedMac` launch / `macos_kill_all` | yes |
| `macos-capture` | canonical-window screenshot capture | yes |
| `xcodebuild-ios` | iOS build (`.build/ios-simulator`) | yes |
| `xcodebuild-macos` | macOS build (`.build/macos`) | yes |

```bash
# Wrapper (preferred)
./script/cross_platform_validation_lock.sh with_lock ios-sim bash -c '...'

# Paired acquire/release (same caller shell; keyed by caller session)
./script/cross_platform_validation_lock.sh acquire macos-app
# ...launch/capture work...
./script/cross_platform_validation_lock.sh release macos-app

# Single-screen entry (skips API/seed when :8787 healthy on validation-db)
./script/cross_platform_screen_validate.sh --screen 07-meet --platform ios
./script/cross_platform_screen_validate.sh --screen 04-profile-populated --platform both
```

Lock files: `/tmp/likeminded-validation-locks/` (600s wait). Persistent `acquire`/`release` pairs are scoped to the caller session (`LIKEMINDED_LOCK_SESSION_ID` can override it); prefer `with_lock` for one command. macOS `--mac-screen` resolves via bash cases in `cross_platform_screen_validate.sh` (profile screens) then ledger `source_files` parenthetical (e.g. `(meetOverview)`).

### Seed + API timing

- Single owner of `:8787` during seed + capture. Stop API before seed if `reset:validation-data` fails mid-run against a live server.
- Simulator auth gate (“Could not connect to the server”) often means `:8787` was killed mid-prove — not a wrong plist URL. `run_validation_api.sh` reuses a healthy validation-db listener (`LIKEMINDED_FORCE_API_RESTART=1` to replace). iOS prove re-checks/starts validation-db immediately before signed-in launch (after xcodebuild waits) and relaunches once on auth/connection error. Real Apple/Google/wallet sign-in needs `APPLE_AUTH_BYPASS=0` and matching `GOOGLE_*` / `WALLETCONNECT_*` env; use `--likeminded-dev-auth-bypass` only for seeded capture.
- `curl -s http://127.0.0.1:8787/health` → `dbPath` must contain `validation-db` before native capture; check `livekit`, `googleAuth`, `walletAuth` when testing those flows.

### Ledger lookup

Use full ledger id: `npm run ledger:screen -- --platform ios --screen 22-settings-info` (exact file stem). Fuzzy match without the numeric prefix can hit the wrong settings ledger.

### iOS capture hygiene

- Auth gate capture: `--screen auth-gate` (unsigned; `--likeminded-reset-auth-session` only). `--screen auth` uses dev bypass → signed-in Meet, not the gate.
- Target one simulator UDID from `./script/build_and_run.sh` — not `booted` when multiple simulators are running. `validation/idb_ctl.sh` must preserve that explicit `IDB_UDID` through its `simctl` screenshot fallback.
- Prefer build-only + explicit `simctl launch` with validation args; `./script/build_and_run.sh run` auto-launches without deep links.
- `verify:ios-screens` builds **once** then sets `LIKEMINDED_SKIP_IOS_BUILD=1` per screen; single `validate:screen` auto-skips xcodebuild when `.build/ios-simulator/.../Likeminded.app` is fresh (still installs to sim) — `LIKEMINDED_FORCE_IOS_BUILD=1` to force rebuild.
- Wait **15–60s** after launch for dev-auth before screenshot.
- When `simctl` drops `--likeminded-start-*` args, use `LIKEMINDED_VALIDATION_SCREEN` UserDefaults fallback (see `build-ios-app` skill).

### macOS Computer hygiene

- `macos_launch` (via `script/macos_canonical_app.sh`) rebuilds when `LikemindedMac` / `Shared` Swift or `project.yml` is newer than `.build/macos/.../LikemindedMac.app` — same freshness contract as iOS. Force with `MACOS_FORCE_BUILD=1` / `LIKEMINDED_FORCE_MACOS_BUILD=1`; skip with `LIKEMINDED_SKIP_MACOS_BUILD=1`.
- Hold the testing-ledger lease across the complete same-screen Computer band with `testing_ledger_runtime_lock.sh --platform macos lease-acquire computer-prove`, retain its token, and finish with the matching `lease-release`. Seed/build/capture mutations remain serialized by `cross_platform_validation_lock.sh`.
- Re-apply `--mac-screen` after dev sign-in (`MacRootView.onChange(of: isSignedIn)`).
- Put **`--mac-screen <name>` before other launch flags** (order-sensitive; wrong order → no capturable window).
- Auth welcome: **no** dev bypass; `--likeminded-reset-auth-session --mac-screen welcome --likeminded-validation-welcome`.
- Settings how-it-works: `--mac-screen settingsSoulmate --mac-settings-pane howItWorks` only (dual `--likeminded-start-settings-info` + pane can yield 0 windows).
- Capture and interact with the canonical app path returned by the launch card. Use bundled `@Computer` semantic element targeting first; coordinates are a bounded fallback only when the current screenshot proves the target.
- **Multi-monitor:** keep the launched canonical window fixed for the whole same-screen band. Re-read app state after any display move or focus loss; do not reuse coordinates across geometry changes.
- **Computer evidence:** keep one compact screenshot/state artifact per failed semantic postcondition; accepted dispatch alone is never evidence.
- **Session start:** canonical-window readiness is checked once and may receive one bounded retry. Broader retry loops are forbidden.

## Delegated verification

`validation-release` agent (`gpt-5.4-mini`, medium) for read-heavy simulator/screenshot runs only. Main thread owns product decisions and file edits.

## Update this file when

Commands, ledger schema, or control-owner paths change—not for per-screen status (that lives in JSON).
