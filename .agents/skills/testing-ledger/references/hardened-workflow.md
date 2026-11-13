# Hardened workflow (repo entry chain)

Modes A/B/C: `~/.agents/skills/testing-framework`. This file lists **Like-minded entry points** and removed inefficiencies.

## Single entry chain

```bash
./script/testing_ledger_session.sh preflight   # coordinator once/session

# Mode B (default drain) — sole-owner prove+fix per platform
npm run testing:ledger-batch-plan -- --platform macos|ios --limit 10
# → build/install once → targeted prove band → cluster/fix → retest → resume cursor

# Mode A — novice discover (no edits) → main batch-fix → retest-first
# Spec: novice-discover.md

# Mode C — single-flow
npm run testing:ledger-run -- --platform macos|ios
# → pass: record | fail: issue → same-flow fix → mark ready → full retest
```

Do not use `ledger:open` as work queue — use `testing:ledger-run`.

## Bookends

| Bookend | Script | Once per |
| --- | --- | --- |
| Preflight + brief | `testing_ledger_session.sh preflight` | Session (coordinator) |
| API + seed | `reset:validation-data` if health fails | Session |
| Batch plan | `testing:ledger-batch-plan` | Source-local Mode B band |
| Build/install | `xcodebuild` under shared lock | Once per unchanged source hash/runtime tuple |
| Closeout | `ledger:record-flow` | Each flow pass |

## Removed inefficiencies

| Removed | Replacement |
| --- | --- |
| `ledger:next` + `ledger:flow` per turn | `testing:ledger-run` merged card |
| Find-one → fix-one loop | Mode A catalog → batch fix, or Mode B in-band |
| Random queue traversal | Deterministic source-local batch plan + saved resume cursor |
| Per-flow rebuild/reinstall | One fresh binary per batch source hash/runtime tuple |
| Separate runtime visit per quality dimension | Co-capture once; record judgments independently |
| Full prove log in prompt | Compact capsule; full log stays on disk unless mismatch/failure |
| Tester-to-fixer chat handoff (single-flow) | One Mode C owner through retest |
| Full gap audit each turn | `testing:ledger-run` queue |
| `ledger:brief` per agent turn | Coordinator preflight only |
| `run_macos_manual_validation` in shell flows | `macos_launch` (no per-flow DB reset) |
| macOS run card lacks exact flow signals | Fail closed: repair the ledger packet before Computer interaction |

## Honesty gate (before record)

Prove log must show this flow’s controls/outcomes. Generic screen sweeps ≠ pass.

## Iteration stop

1. `ledger:record-flow` → `pass` with tier met, or
2. same blocker 3× unchanged → checkpoint, or
3. `blocked` infrastructure

Then `testing:ledger-run`; empty queue → `verify:production-ready`.

## Empty iteration

Two consecutive `testing:ledger-run --card-only` with no code changes → only `tier-gap` / `stale-pass` → make one source-local batch plan and reuse the same Computer visit.

## Drain efficiency (Mode B)

| Pattern | Do |
| --- | --- |
| Contested lock | Stop; verify holder; cull twins |
| Hash restale | Re-queue `stale-pass`; re-drain family |
| Tier-gap on green stamp | Prove at required method |
| Env hard block | Checkpoint; do not burn owners |
| Pre-prove hygiene | `/health` → `validation-db`; `bash -n` after prove-script edits |
| Repeated iOS flow proofs, unchanged band | `LIKEMINDED_REUSE_IOS_INSTALL=1`; reuse only after source-fresh built/installed SHA-256 match and explicit UDID/bundle/user tuple |

An iOS reuse identity, freshness, installation, or hash mismatch is terminal for that
proof invocation and must occur before launch or interaction. Build/install normally
when beginning a band or after any implicated source/project change; do not turn a
failed reuse check into an implicit fallback that could conceal the wrong runtime.

Coordinator: [`agent-coordination.md`](agent-coordination.md).
