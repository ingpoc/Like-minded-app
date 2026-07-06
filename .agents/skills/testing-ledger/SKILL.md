---
name: testing-ledger
description: >-
  Operate validation/screens ledger: pick next unvalidated flow, prove with macOS
  CUA or iOS capture, root-cause fix and retest loop, record pass with tier
  enforcement, add new flows with dedup. Token-efficient — one flow per turn.
  Multi-agent: exactly one macOS CUA tester at a time; all other macOS
  agents are code-fix only (no CUA, no prove scripts). Coordinator may run
  one macOS tester + one iOS tester in parallel (never two on same platform).
  Entry: testing:ledger-run (tester), testing:ledger-fix-run (fixer).
  Triggers: testing ledger, validate pending flows, ledger CUA proof,
  iOS ledger proof, proof flows, testing-ledger skill, runtime validate ledger,
  fix and reverify flow, wild tester, fix agent coordination.
---

# testing-ledger

Hardened workflow for `validation/screens/*.json`. **One open flow per agent turn.** Coordinator may run **one macOS tester + one iOS tester** in parallel — **never two agents on the same platform**.

## macOS CUA exclusivity

**Exactly one macOS CUA owner at a time** (tester XOR fixer holding runtime lock). All other macOS agents are **fix-only**: edit `fix_owner`, release lock, `mark-retest-ready` — **never** run CUA or prove scripts.

| Role | macOS runtime |
| --- | --- |
| **Tester** (sole CUA owner) | `testing:ledger-run -- --platform macos` → prove → record/issue |
| **Fixer** | `testing:ledger-fix-run` → edit one file → release lock → `mark-retest-ready` |
| **Everyone else** | Code changes only — **no** `testing:ledger-prove`, `macos_cua_screen.sh`, `macos_cua_*.sh`, or `testing:ledger-run` |

## Tester loop (3 lines)

1. `npm run testing:ledger-run -- --platform macos|ios` — merged card (target, PRE, PASS, prove) + runtime prove.
2. Pass → `npm run ledger:record-flow -- …`; fail → `npm run testing:ledger-issue -- …` (~12 lines to fixer).
3. Stop — do not fix in the same turn.

## Fixer loop (3 lines)

1. `npm run testing:ledger-fix-run -- --platform macos|ios` — claim + fix card (owner, lock, retest).
2. Read one `fix_owner`; smallest diff; release runtime lock.
3. `npm run testing:ledger-fix-next -- --mark-retest-ready <id>` — one issue per turn.

## Coordinator (once/session)

`./script/testing_ledger_session.sh preflight` — API health + `ledger:brief` counts. Spawn tester/fixer lanes; never `ledger:open` as work queue.

## Hard rules

1. **Non-validated first** — only `testing:ledger-run` / `testing:ledger-next` picks work.
2. **Trust pass** — do not re-test `pass` unless `ledger:stale` or queue says `stale-pass` / `tier-gap`.
3. **Root cause** — env/API → launch args → app logic → ledger. No symptom-only `pass`.
4. **Full retest after fix** — same flow via `testing:ledger-run`, not partial clicks.
5. **One flow per turn** — finish record or `fail` before another screen.
6. **New flows** — [`references/add-flow-criteria.md`](references/add-flow-criteria.md); `npm run testing:ledger-add-flow` when criteria met.
7. **Scripts only** — no improvised CUA JSON; `ledger:open` is gap-only (coordinator), not per-flow.

## Fix / retest loop

| Order | Check | Fix owner |
| --- | --- | --- |
| 1 | `:8787` / validation-db | `dev:api:validation`, `reset:validation-data` (once/session) |
| 2 | Launch args / `--mac-screen` | `MacScreens.swift` |
| 3 | Seed / user state | validation-gurusharan |
| 4 | Product bug | Swift + API; smallest diff |

Detail: [`references/fix-retest-loop.md`](references/fix-retest-loop.md)

## Context budget

| Load | Skip |
| --- | --- |
| `testing:ledger-run`, `testing:ledger-fix-run` | `ledger:flow`, `ledger:open`, GOAL, PROGRESS |
| One `fix_owner` on fix | Full skills, mockup dirs |

Detail: [`references/context-budget.md`](references/context-budget.md) · [`references/agent-coordination.md`](references/agent-coordination.md)

## Add flow (discovered in test)

```bash
npm run testing:ledger-add-flow -- --screen <logical-id> --flow-id <kebab-id> \
  --name "..." --step "User taps X" --control-macos <id> [--control-ios <id>] --dry-run
```

## Production gate

When queue empty: `npm run verify:production-ready`.

## References

| File | When |
| --- | --- |
| [`references/hardened-workflow.md`](references/hardened-workflow.md) | Iteration / inefficiency removal |
| [`references/add-flow-criteria.md`](references/add-flow-criteria.md) | Before adding flows |
| [`references/fix-retest-loop.md`](references/fix-retest-loop.md) | Failures during CUA |
| `@build-macos-app` | macOS build failures only |
| `@build-ios-app` | iOS build/capture failures only |
| `~/.agents/skills/macos-cua` | CUA harness debugging |
| `docs/workflows/validation.md` | Locks, parallel proof |
