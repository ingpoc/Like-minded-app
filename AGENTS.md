# Like-minded-app Repo Instructions

## Inheritance Contract

- Global baseline: `/Users/gurusharan/.codex/AGENTS.md`
- Control owner: global `AGENTS.md`
- Local file declares only repo scope, routing, boundaries, and validation

## Scope

- Like-minded-app workspace: SwiftUI iOS/macOS, Node API, local JSON store, validation ledgers, TestFlight path.
- `GOAL.md` — ultimate product goal (scope disputes only).
- `PROGRESS.md` — roadmap checkboxes (active track section only during work).
- `goal.json` — per-session goal, graders, routing.
- `session/work-bucket.json` — **continue previous session** (screen, ledger, mockups, `continue_command`); auto-stamp via hooks; optional `npm run session:stamp`.
- `session/optimization-registry.json` — optimization waves for `@optimization-validate` skill (`npm run optimization:status`, `npm run verify:optimization`).
- `validation/screens/*.json` — **control status owner** (schema v2: `flows[]` + `controls.{ios,macos}`; legacy archive: `validation/_legacy/{ios,macos}/`).
- `validation/production-contract.json` — **production scope contract** (TestFlight MVP; `npm run verify:production-ready`).

## Context doctrine (repo)

Inherits global **Context doctrine** (`~/.codex/AGENTS.md`).

**Control chain here:** `validation/screens/*.json` (status) → `PROGRESS.md` active track (roadmap) → code. No sibling `validation/**/*.md` ledgers or pass/fail tables.

### First commands (stop when the question is answered)

| Lane | Run | Do not preload |
| ------ | ----- | ---------------- |
| Any session | `npm run goal:next` | Full `PROGRESS.md`, `GOAL.md` |
| Native UI (one screen) | `npm run ledger:screen -- --platform ios\|macos --screen <id>` + `source_files` | All validation JSON, mockup dirs |
| Gap / all open controls | `npm run ledger:open` (`ledger:stale` after source edits) | Source trees, mockup images |
| Backend route | `services/api/src/server.js` family | Native UI docs |
| Phase N | `npm run phase:preflight -- N` | Entire phase history |
| Claim track/goal done | `npm run verify:ledger-progress` | — |
| macOS CUA (one screen) | `macos_cua_preflight.sh` → `macos_audit_prepare.sh` → `macos_cua_screen.sh <screen>` |
| macOS ledger flow proof | `@testing-ledger` → `npm run testing:ledger-run -- --platform macos` → `ledger:record-flow` |
| iOS ledger flow proof | `@testing-ledger` → `npm run testing:ledger-run -- --platform ios` → `ledger:record-flow` |
| macOS post-parallel / stale | `npm run macos:validation-batch` (full) or `npm run macos:cua-reproof` when `ledger:stale` shows macOS `stale_pass` only |

`./script/project_context.sh query --task "…"`: **only** if `goal:next` is insufficient, `decision_count > 0`, or boundary/decision-graph work. **Skip when zero decisions.**

`workflow --docs-dir … summary <slug>`: **only** when the trigger names one slug **and** that lane is not already covered. Never load multiple summaries for one task.

## Session start

1. `npm run goal:next` → **work bucket first** (previous session surface + ledger + mockups), then `first_command`; stop when answered.
2. `git status --short` before edits; `npm run verify:ledger-progress` before claiming track/goal complete.
3. **Session end (automatic):** `.cursor/hooks.json` runs `session:stamp-auto` on `preCompact` and `sessionEnd`. Optional override: `npm run session:stamp -- --screen <id> --summary "…"`.

Next-goal: smallest full-session surface (one screen family, endpoint family, or track)—not a single checkbox unless it is the only blocker.

## Trigger map (compact)

- **API running** before build/run: `curl -s http://127.0.0.1:8787/health`
- **Seeded native validation**: `npm run dev:api:validation` + `npm run reset:validation-data`; mockup paths from ledger JSON `mockup_ref`, not directory walks
- **iOS UI**: `@build-ios-app` skill; `Sources/LikemindedApp`; mockups only for visual work
- **macOS UI**: `@build-macos-app` skill; `Sources/LikemindedMac`; `script/macos_canonical_app.sh` for one binary path
- **Ledger flow testing**: `@testing-ledger` skill; `npm run testing:ledger-run [-- --platform ios|macos]` (queue); do not use `ledger:open` as work queue
- **Backend**: `services/api/src/server.js`; same `LIKEMINDED_API_BASE_URL` on both natives
- **Boundary / stack change** (rare): `workflow summary project-spine` **or** `project_context query`, not both by default
- **Decision graph** (rare): `workflow summary context-graph`
- **Do not repeat** retrieval already done for the same task unless the task changed or evidence contradicts loaded context

## Harness routing (autopilot — agent classifies, user does not)

Cursor Auto is the always-on orchestrator. **Classify every turn internally**; never wait for the user to name a harness, subagent, or Codex profile.

### Decision order (first match wins)

1. **Session boundary** — fresh turn, "what's next", gap audit → `npm run goal:next`; **no LLM sidecar**
2. **Deterministic proof** — ledger, build, verify script exists → run it; **no LLM sidecar**
3. **Build lane** — implementing, fixing, iterating, build failing, task incomplete → **Cursor main thread** (Read → edit → build loop)
4. **Merge gate** — signals below → **`codex-review` subagent** before commit/PR/push; integrate findings; fix P0/P1; then proceed
5. **Parallel disjoint read** — large unrelated map while main thread has local work → `explore` subagent only
6. **Context-efficiency audit** — stale routing / competing owners / goal-vs-dirty mismatch → `cost_scan` subagent (read-only)

### Merge-gate signals (auto-invoke `codex-review`)

Invoke when **any** is true and implementation for this slice is done:

- Your next planned action is `git commit`, `gh pr create`, or push
- Build/verify for the changed surface passed and diff is non-trivial (3+ files, or auth/API/schema/validation JSON)
- User intent is ship/merge/PR (including informal: "commit", "open a PR", "ready to merge") — **do not require** the phrase "code review"

Skip `codex-review` when:

- Still editing, debugging, or build/verify failing
- Trivial diff (single typo, comment-only) unless it touches security/auth
- Already ran `codex-review` on the same diff since the last source edit

After `codex-review`: fix blocking P0/P1 yourself or report blockers; do not commit with open P0/P1.

### Lane → harness map

| Lane | Harness | Model |
| ------ | --------- | ------- |
| Session start / gap | Deterministic scripts | — |
| **Trivial UI fix** (single file, &lt;~30 lines, user screenshot, no ledger proof) | **Cursor main thread** — no subagent | Auto |
| Build (Swift, API, UI) | Cursor Auto main | Auto |
| Ledger flow proof (macOS) | `@testing-ledger` → `testing:ledger-run -- --platform macos` → `ledger:record-flow` | Auto |
| Ledger flow proof (iOS) | `@testing-ledger` → `testing:ledger-run -- --platform ios` → `ledger:record-flow` | Auto |
| **Wild tester** | `testing:ledger-run [--platform ios\|macos]` → fail → `testing:ledger-issue`; **exactly one macOS CUA owner**; iOS parallel OK; never two testers on same platform | Auto |
| **Fix agent** | `testing:ledger-fix-run -- --platform ios\|macos` → one `fix_owner` → release lock → `--mark-retest-ready`; **fix-only — no CUA, no prove scripts, no macos_cua_screen.sh** | Auto |
| **Test coordinator** | **One macOS CUA tester max** (+ optional one iOS tester); spawn fix-only workers for queue issues; never fix + tester on same platform; shared seed/build via `cross_platform_validation_lock.sh` | Auto |
| Runtime proof | Cursor Auto + `macos_cua_screen.sh`, `npm run verify:*` | — |
| **macOS multi-screen closeout** | Parallel **implement** workers per ledger JSON; **sequential** `./script/macos_validation_batch.sh` for capture+CUA | Auto |
| Operator UI audit | Cursor Auto + `requirements-gap-audit` | Auto |
| Merge gate review | `codex-review` → Codex `scan_fast` then `verify_review` | mini → gpt-5.4 |
| Architecture ambiguity in review | `codex-review` escalates to `deep_reason` / `gpt55_escalation` | per policy |
| Stale routing audit | `cost_scan` | gpt-5.4-mini |
| 1–2 tool calls | Cursor Auto direct | Auto |

### Trivial-fix lane (no subagent)

Use the **main thread** when **all** are true:

- One localized bug (clip, padding, alignment, copy) with a clear screenshot or repro
- Touch ≤1–2 files and ≲30 lines; no new controls or API contracts
- Build compile check is enough; no ledger/CUA stamp required before shipping the fix

Do **not** spawn a background worker for these. If a subagent stalls &gt;5 minutes on such a task, interrupt it and fix on the main thread.

### Native validation parallelism (iOS + macOS)

**Two waves:** parallel **code** per ledger screen; **sequential proof** (seed → build → capture). See `docs/workflows/validation.md` § Parallel screen validation.

| Phase | Parallel? | Tool |
| ------- | ----------- | ------ |
| UI implementation per screen | Yes — disjoint ledger JSON + platform source slices | Subagents or main thread |
| `xcodebuild` (either platform) | **No** — one derived-data owner | `cross_platform_validation_lock.sh` |
| iOS screenshot / `simctl launch` | **No** | `cross_platform_screen_validate.sh` |
| macOS screenshot / CUA | **No** — one `LikemindedMac` instance | `verify_macos_screens.sh` or `macos_validation_batch.sh` |
| `reset:validation-data` | **No** — sole `:8787` owner | lock `seed` |
| API contract after `server.js` edit | No | `npm run smoke:mvp` |

Use `./script/cross_platform_validation_lock.sh` for all kills/launches/captures. After parallel UI workers finish: `npm run validate:screen -- --screen <id> --platform ios|both` per screen, `npm run verify:ios-screens -- --stale-only` for iOS stale-pass, or `npm run macos:cua-reproof` for macOS stale-pass.

Scripts own proof. Subagents own bounded sidecars. Main thread owns integration and final judgment.

## Session alignment (project hooks)

- `.cursor/hooks.json` → `sessionStart` runs `npm run goal:next` compact route via `script/session_route.js`.
- `npm run verify:ledger-progress` / `verify:goal` → fail if duplicate context surfaces return (status tables, phase graveyard, sibling ledgers).

## Project agents

`.codex/agents/` — bounded parallel work only; main thread owns integration.

## Repo rules

- Keep this file compact; details in `docs/workflows/` per lane.
- `apps/ios-macos/project.yml` — XcodeGen owner; never hand-edit `.xcodeproj`.
- iOS → `LikemindedApp/`; macOS → `LikemindedMac/`.
- Command/script changes: update `docs/workflows/validation.md` + `docs/references/project-context.md` in the same change—**edit, don't add** parallel docs.
- No sibling `validation/**/*.md` ledgers; JSON only.

## Cursor Cloud specific instructions

- Linux VM, no Swift/Xcode → only the Node API (`services/api`, local JSON) runs; native iOS/macOS build/run/validate is unavailable.
- Before any backend run/test or build/validate attempt, load only `docs/workflows/setup.md` → "Cursor Cloud (Linux, no Xcode)" for the can/cannot list, run command, and Linux-safe vs Xcode-only script tables.
