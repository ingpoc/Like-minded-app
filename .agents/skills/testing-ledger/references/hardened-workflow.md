# Hardened workflow (workflow-hardening applied)

## Single entry chain

```bash
# Coordinator once/session
./script/testing_ledger_session.sh preflight

# Tester turn (one command)
npm run testing:ledger-run -- --platform macos|ios
# → merged card + prove → ledger:record-flow | testing:ledger-issue

# Fixer turn (one command)
npm run testing:ledger-fix-run -- --platform macos|ios
# → claim + fix card → edit fix_owner → mark-retest-ready
```

No alternate entry points. Do not use `ledger:open` as work queue — use `testing:ledger-run`.

## Bookends

| Bookend | Script | Once per |
| --- | --- | --- |
| Preflight + brief | `testing_ledger_session.sh preflight` | Session (coordinator only) |
| API + seed | `reset:validation-data` if health fails | Session |
| Build | `xcodebuild` lock per binary batch | 3+ flows same session |
| Closeout | `ledger:record-flow` | Each flow pass |

## Removed inefficiencies

| Removed | Replacement |
| --- | --- |
| `ledger:next` + `ledger:flow` per turn | `testing:ledger-run` merged card |
| `testing:ledger-fix-next` + manual lock hints | `testing:ledger-fix-run` |
| Full gap audit each turn | `testing:ledger-run` queue |
| `ledger:brief` per agent turn | Coordinator preflight only |
| `run_macos_manual_validation` in shell flows | `macos_launch` (no per-flow DB reset) |
| Duplicate issue + ledger fail state | Queue = handoff; ledger = status |

## Iteration stop rule

Stop a flow slice only when:

1. `ledger:record-flow` → `pass` with tier met, or
2. `fail` + `testing:ledger-issue` queued for fixer, or
3. `blocked` with infra `blocker`

Then `testing:ledger-run` — empty queue → `verify:production-ready`.

## Empty iteration (session done)

Two consecutive `testing:ledger-run --card-only` with no code changes → only `tier-gap` / `stale-pass` → `macos:cua-reproof` batch once.
