---
name: testing-ledger
description: >-
  Like-minded drain adapter for validation/screens ledger: prove with bundled
  Computer on macOS
  or iOS capture, issue queue, fix/retest, record pass with tier enforcement.
  Default mode B sole-owner drain; A novice catalog-then-fix; C single-flow.
  Doctrine: ~/.agents/skills/testing-framework. Entry: testing:ledger-run.
  Triggers: testing ledger, validate pending flows, ledger Computer proof,
  iOS ledger proof, proof flows, testing-ledger skill, runtime validate ledger,
  fix and reverify flow, wild tester, novice test, discover issues, batch
  issues, keep proving, drain queue, multitask testing, fix agent coordination.
---

# testing-ledger

Thin **drain-lane** adapter for this repo. Multi-agent modes, locks, capsules, and coordinator rules live in **`~/.agents/skills/testing-framework`** — load that for doctrine; this file for commands and honesty gates.

> **Self-validate after edits.** Run `./scripts/validate.sh` from this skill directory.

| Binding | Value |
| --- | --- |
| Lane | **Drain / prove** (not customer-gate) |
| Default mode | **B** sole-owner prove+fix |
| Truth owner | `validation/screens/*.json` |
| Requirements owner | `GOAL.md` for ultimate scope; `flows[].proof` for testable outcomes |
| Design owner | `DESIGN.md` + `platforms.{ios,macos}.mockup_ref` |
| Journey inventory | `validation/screens/*.json` → `flows[]` |
| State coverage | `flows[].proof` + platform `ui_validation`; absent coverage is an open gap |
| Quality dimensions | Ledger owns functional/coherence proof; visual, UX, accessibility, resilience, and trust require their declared evidence routes |
| Evidence routes | [`references/quality-gates.md`](references/quality-gates.md) |
| Issue queue | `validation/testing-issue-queue.json` |
| Platforms | `ios`, `macos` (∥ OK) |
| Prove entry | `npm run testing:ledger-run -- --platform ios\|macos` |
| Record pass | `npm run ledger:record-flow -- --platform … --screen … --flow … --result pass …` |
| File issue | `npm run testing:ledger-issue -- …` |
| Mutex prove | `./script/testing_ledger_runtime_lock.sh --platform ios\|macos status` |
| Mutex shared | `./script/cross_platform_validation_lock.sh` (seed/build/capture) |
| Runtime identity | Resolve one simulator UDID/app bundle/user; export it to build, install, launch, `idb`, screenshot, and readback |
| Batch planner | `npm run testing:ledger-batch-plan -- --platform ios\|macos --limit 10` |
| Coverage history | `npm run ledger:brief -- --platform ios\|macos --all --json` (opt-in full inventory; compact brief by default) |
| Verification gate | `npm run verify:testing-ledger` — active prose/routes, schema, coverage contract, migration, and progress integrity |
| Orchestrator receipt | `npm run ledger:brief -- --receipt` — fingerprinted scalar debt only; never flow-level context or a second truth owner |
| Capsules | Match `testing-framework/references/capsules.md` (inline JSON on return) |
| Computer primitive | Bundled `@Computer` (`computer-use:computer-use`) for native macOS interaction |
| Session hops | Do **not** per-flow `$session-orchestrate` during drain |

## Ownership boundary with session-orchestrate

`testing-ledger` exclusively owns test inventory, missing-gap detection, source
freshness, proof tier, issue packets, flow status, and test closeout. It publishes
two deterministic interfaces: `verify:testing-ledger` for integrity and the
compact `ledger:brief -- --receipt` receipt for orchestration.

`session-orchestrate` may use that receipt to order product goals and decide
whether a proof campaign remains, but it must not copy flow status into another
ledger, edit `validation/screens/*.json`, select individual flows, or wrap a
drain in per-flow hops. Re-run the gate and refresh the compact receipt only when
`GOAL.md`, `DESIGN.md`, ledger/harness owners, or mapped product sources change,
or immediately before goal/phase completion. A failed gate or open required gap
stays with this owner; orchestration records only the owner command and current
receipt fingerprint.

## Framework gate routing

`testing:ledger-run` proves a declared flow at its required tier. It does **not**
turn that result into visual-design, UX, accessibility, resilience, or trust
acceptance. Use the same screen ledger as the status owner, with distinct evidence:

| Framework gate | Repo route |
| --- | --- |
| Test readiness | `DESIGN.md` + screen `flows[].proof`; missing criterion stays open |
| Functional/coherence | `testing:ledger-run` + authoritative visible/persisted readback |
| Visual design | Current standard screenshot vs `mockup_ref` and `DESIGN.md`; record platform `ui_validation` / `visual_parity` |
| UX journey | Fresh visible-UI mission; never infer from control drains |
| Accessibility/trust | Accessibility capture and interaction proof plus applicable privacy/safety criteria |
| Fix/re-review | Root-cause batch → targeted retest → full affected journey → fresh review |
| Frozen release | All required dimensions current on one source hash; no missing UI criteria |

Exact evidence and stop rules: [`references/quality-gates.md`](references/quality-gates.md).

## Mode map (repo names → global)

| Global | Repo | When |
| --- | --- | --- |
| **B** | Sole-owner drain | Queue closeout / keep proving / multitask — **default** |
| **A** | Novice discover | Catalog before edits; file+continue, no novice edits |
| **C** | Single-flow | One known `screen/flow` or hot fix |

Doctrine + mode router: `~/.agents/skills/testing-framework`. Repo dispatch: [`references/agent-coordination.md`](references/agent-coordination.md) · [`references/novice-discover.md`](references/novice-discover.md).

## Commands

```bash
# Coordinator once/session
./script/testing_ledger_session.sh preflight

# Mandatory integrity boundary; also runs from npm run check
npm run verify:testing-ledger

# Compact breadth/debt summary; full per-flow time/hash only for coverage audits
npm run ledger:brief -- --platform ios|macos
npm run ledger:brief -- --platform ios|macos --all --json

# One-screen context: compact route, sources, and current/stale flow state
npm run ledger:screen -- --platform macos|ios --screen <screen> --section route

# Pick + prove (queue). Optional: --screen X --flow Y [--reprove]
npm run testing:ledger-run -- --platform macos|ios

# Mode B: deterministic source-local batch plan (1..12; default 10)
npm run testing:ledger-batch-plan -- --platform macos|ios --limit 10

# After fix
npm run testing:ledger-fix-next -- --mark-retest-ready <issue-id>
npm run testing:ledger-run -- --platform macos|ios --screen <s> --flow <f>

# Add flow (criteria: references/add-flow-criteria.md)
npm run testing:ledger-add-flow -- --screen <id> --flow-id <kebab> --name "…" \
  --step "…" --control-macos <id> [--control-ios <id>] --dry-run

# Queue empty
npm run verify:production-ready
```

Fresh comparison of a current pass: `--screen` + `--flow` + `--reprove` (both selectors required). Untargeted policy unchanged; `--verbose` for terminal replay.

Obsolete control: delete from code, ledger, gap registry, proof routing →
`npm run testing:ledger-fix-next -- --mark-resolved <id> --resolution "…"`.

## Mode B batch lifecycle

Default to one deterministic source-local band of **8–12 flows**, but stop at the
locality boundary rather than padding with unrelated work. Mode B owns the complete
cycle in one session:

1. Plan with `testing:ledger-batch-plan`; retain its batch id, runtime tuple, source files, and resume cursor.
2. Build/install once for the current source hash and explicit runtime identity. For later targeted iOS proofs in that unchanged band, set `LIKEMINDED_REUSE_IOS_INSTALL=1`; the proof owner must independently prove source freshness and exact built/installed executable hashes before any interaction, or fail closed.
3. Prove each planned flow; stop that flow at its first failed semantic postcondition and retain one compact artifact.
4. Finish bounded discovery before editing unless a failure blocks every remaining flow in the band.
5. Cluster failures by shared root cause and `fix_owner`; fix one coherent cluster.
6. Retest fixed flows first, then affected complete journeys; resume at the saved cursor.
7. Co-capture screenshot, AX, persisted state, and trust observations during one runtime visit where possible, but record each quality judgment independently.

Mode A remains discover-only. Mode C remains one difficult blocker. Do not invent
unsupported batch flags; the planner selects locality, while targeted
`testing:ledger-run --screen … --flow …` commands remain the proof/record owner.

## Mutex / parallelism (repo)

| Resource | Rule |
| --- | --- |
| macOS prove / Computer | Exactly one owner; one canonical app and Computer session |
| iOS prove / sim | Exactly one owner; may run beside macOS |
| Contested prove lock | **Stop** — verify holder; cull non-holder twins; never wait-loop / second prove |
| Seed / xcodebuild / capture | `cross_platform_validation_lock.sh` only |

Release platform prove lock before source edits that are not in-band fix→retest.

## Hard rules (repo honesty)

1. **Queue only** — `testing:ledger-run` / `testing:ledger-next` picks work; `ledger:open` is gap-only for coordinator.
2. **Trust pass** unless `ledger:stale`, queue `stale-pass` / `tier-gap`, or operator `--reprove`.
3. **Root cause order** — harness honesty → env/API → launch args → app → ledger.
4. **Fail closed** — every `computer-use` interaction flow needs exact `<screen>/<flow>` success signals. macOS uses the generated testing-ledger card plus bundled `@Computer`; iOS uses its explicit proof script. A generic screen capture never proves behavior.
5. **Read the prove log** — confirm this flow’s labels before trusting `exit_status=0`. False pass is P0.
6. **Full retest** after fix via `testing:ledger-run` (entire flow).
7. **Mode discipline** — do not mix A/B/C in one owner turn. A: no edits in novice. B: prove+fix in-band. C: finish record/checkpoint before another screen.
8. **Delegated ≠ fact** — verify catalogs against proof log/PNG + current hash vs `tested_source_hash`.
9. **Hash restale expected** after product/AX edit — re-drain `stale-pass`; don’t treat “just proved” as durable across the family.
10. **Tier-gap ≠ broken** — wrong method still needs honest prove at required tier; never fake-record.
11. **Env hard blocks** — e.g. `real-auth` when `/health` has `googleAuth:false` / `walletAuth:false` → checkpoint; do not respawn.
12. **Owned routes only** — macOS actions use bundled `@Computer` from the exact run card; iOS actions use the declared proof script. Do not invent an alternate native driver.
13. **No quality-by-proxy** — a flow pass is functional evidence only; record each
    other applicable dimension independently.
14. **Missing is open** — absent platform `ui_validation` / `visual_parity`, state
    coverage, design reference, or success signal is a gap, never an implicit pass.
15. **Fresh re-review** — after finding acceptance, run a context-reset visible-UI
    review without exposing the old issue list; fixed findings alone are not an empty iteration.
16. **One iOS identity** — resolve a concrete simulator UDID once. Pass that same
    UDID to Xcode destination, `simctl install/launch`, `IDB_UDID`, AX reads, taps,
    screenshots, and logs. Never mix an implicit “first booted” device with an
    independently resolved build destination.
17. **Fail the dependency chain early** — if route readiness or one interaction’s
    semantic postcondition fails, capture the first useful AX/screenshot and stop
    dependent clicks. A sequence of predictable timeout misses is not extra evidence.
18. **Cheap discriminator before another prove** — after one full-flow failure,
    check runtime identity, source/binary freshness, and one direct semantic action
    before rebuilding or rerunning the full flow. Two unchanged failures require Mode C.
19. **Atomic ledger evidence** — screen JSON, issue queue, stamps, and generated
    reports must be updated under their owner lock with atomic replace. Malformed or
    changing JSON during validation is a harness/contention failure, not an app gap.
20. **Scroll on the empty edge** — iOS scripted swipes use `idb_ctl.sh` edge-lane
    commands, then verify the target is inside the tappable viewport. Center-lane
    gestures can be consumed by fields, sliders, and cards while `idb` still exits 0.
21. **Breadth before repetition** — within the same failure/status/tier bucket, the queue selects never-tested and oldest-tested screens/flows before recent evidence. Do not override it with `--reprove` merely because a surface is familiar.
22. **Inventory is declared, not assumed** — the ledger can timestamp only flows present in `flows[]`. At feature/release boundaries, compare requirements and reachable journeys to the full `ledger:brief --all --json` inventory; add every missing outcome with `testing:ledger-add-flow` before claiming coverage.
23. **One test truth owner** — orchestration consumes the compact receipt and gate result only. It never writes flow status or maintains a parallel test checklist; any mismatch is repaired here first.

## Pre-proof readiness and source-freeze gate

Before an expensive build/capture, full screen-family drain, or blind review:

1. Freeze the applicable `flows[].proof` outcomes and negative/recovery states.
2. Review the proof branch itself: success must require authoritative visible or
   persisted readback, fail closed, and include every state/source owner in the
   screen hash. A preview flag, dispatched action, build, or screenshot is not
   readiness evidence.
3. During UI iteration, use targeted proof only for the changed journey. Collect
   all known P0–P2 findings before one coherent source batch.
4. When the targeted proof and cheap checks pass, freeze the product diff and
   create `output/validation/acceptance/<source-hash>/`; never overwrite a
   mutable review packet.
5. Build/install once for that hash, then produce standard/accessibility
   captures and the affected family proof from the same binary/runtime identity.

If proof or review reveals another source edit, return to targeted iteration,
invalidate the affected package, and refreeze under the new hash. Do not repeatedly
reprove sibling flows or spawn a fresh reviewer pair for each individual finding.

## Fix order

| Order | Check | Owner |
| --- | --- | --- |
| 0 | Runtime identity mismatch / multiple candidates | One explicit UDID/window/profile through every layer |
| 1 | False pass / missing branch | `testing_ledger_prove_{flow,ios}.sh` |
| 2 | `:8787` / validation-db | `dev:api:validation`, `reset:validation-data` |
| 3 | Launch args / logical-id | `cross_platform_screen_validate.sh`, `--mac-screen` |
| 4 | Display / wrong window | Canonical full app path + fresh bundled Computer state |
| 5 | Seed / user | validation-gurusharan |
| 6 | Product / copy | Swift + API (Circles: `Your circle.` not `Your room.`) |

Detail: [`references/fix-retest-loop.md`](references/fix-retest-loop.md)

## Context budget

Load: run card, retained failure artifacts, flow route, coherent owners.
Skip: `ledger:flow`, `ledger:open` as work queue, GOAL, PROGRESS, mockup dirs, sibling drain logs.
Coordinator after return: hash/stale + lock status — not full prove-log reload when stamps match.
Detail: [`references/context-budget.md`](references/context-budget.md)

## References

| File | When |
| --- | --- |
| `~/.agents/skills/testing-framework` | Modes A/B/C, capsules, lanes, bootstrap |
| [`references/agent-coordination.md`](references/agent-coordination.md) | Packets, sole-owner verify loop, mutex map |
| [`references/novice-discover.md`](references/novice-discover.md) | Mode A packets + return schema |
| [`references/hardened-workflow.md`](references/hardened-workflow.md) | Entry chain, removed inefficiencies |
| [`references/add-flow-criteria.md`](references/add-flow-criteria.md) | Before adding flows |
| [`references/fix-retest-loop.md`](references/fix-retest-loop.md) | Computer failure diagnosis |
| [`references/quality-gates.md`](references/quality-gates.md) | Framework lifecycle, dimension evidence, and closeout |
| `~/.agents/skills/testing-framework/references/runtime-proof-efficiency.md` | Runtime identity, fail-fast proof, retry budget, compact failure capsules |
| `@build-macos-app` / `@build-ios-app` | Build failures only |
| `docs/workflows/validation.md` | Locks, parallel proof |
