# Agent coordination (tester / fixer / coordinator)

Lean handoffs — one command per turn, one issue per turn.

## Dual-lane coordinator (iOS ∥ macOS)

```
Coordinator (once/session: testing:ledger-session preflight)
 ├── macOS — exactly ONE CUA tester OR one fixer (never both; never two testers)
 └── iOS   — exactly ONE tester OR one fixer (parallel with macOS OK)
Shared serial: reset:validation-data (once/session), xcodebuild → cross_platform_validation_lock.sh
```

**macOS CUA rule:** at most **one** agent may hold `testing_ledger_runtime_lock.sh --platform macos`. That agent is the sole tester (prove path). Every other macOS agent is **fix-only** — no CUA, no prove scripts, no `macos_cua_screen.sh`.

Never spawn two agents on the **same** platform. At most **two** runtime subagents total: one macOS + one iOS.

`testing:ledger-next` interleaves screens (round-robin within rank/tier) — coordinators should expect macOS targets to rotate across screens, not drain `auth` first.

## Per-role load (hard caps)

| Role | Max commands | Max files | Entry |
| --- | --- | --- | --- |
| **Tester** | 3 | 0 | `testing:ledger-run` → `ledger:record-flow` or `testing:ledger-issue` |
| **Fixer** | 2 | 1 (`fix_owner`) | `testing:ledger-fix-run` → edit owner → `mark-retest-ready` |
| **Coordinator** | 2 | 1 (queue JSON) | `testing:ledger-session preflight` → spawn lanes |

## Tester loop (3 lines)

1. `npm run testing:ledger-run -- --platform macos|ios` — merged card + prove (lock acquired by prove script).
2. Pass → `npm run ledger:record-flow -- …`; fail → `npm run testing:ledger-issue -- …`.
3. Stop — never fix in the same turn.

## Fixer loop (3 lines)

1. `npm run testing:ledger-fix-run -- --platform macos|ios` — claims queue issue + fix card (~12 lines).
2. Acquire lock → read **one** `fix_owner` → smallest Swift diff → release lock.
3. `npm run testing:ledger-fix-next -- --mark-retest-ready <id>` — one issue per turn.

## NEVER (all roles)

- `ledger:open` after `testing:ledger-run` / `testing:ledger-next` (queue is sole work picker)
- `ledger:flow` when run card already printed PRE/PASS (merged into `testing:ledger-run`)
- `ledger:brief` per turn (coordinator preflight only)
- `GOAL.md`, full `PROGRESS.md`, `mockups/**` walks, full `@build-ios-app` / `@testing-ledger` skill re-read
- `run_macos_manual_validation.sh` inside shell flows (resets DB) — use `macos_launch` without reset; seed once/session

## NEVER (fix-only agents — not the platform CUA tester)

Fixers and parallel implement workers must **not** compete for runtime proof resources:

- `npm run testing:ledger-run` / `testing:ledger-prove` / `testing:ledger-prove-ios`
- `./script/macos_cua_screen.sh`, `macos_cua_*.sh`, `macos_validation_batch.sh`, `verify_macos_screens.sh`
- `./script/testing_ledger_prove_flow.sh`, `./script/testing_ledger_prove_ios.sh`
- `./script/cross_platform_screen_validate.sh` (iOS capture lane — tester only)
- Acquiring `testing_ledger_runtime_lock.sh` for prove (fixer may acquire briefly for `fixer` role while editing, then **release** before `mark-retest-ready`)

Only the **designated platform tester** runs prove scripts. Coordinator spawns at most **one** macOS CUA tester per wave.

## Coordinator

- **Once/session**: `./script/testing_ledger_session.sh preflight` (`:8787` health + `ledger:brief` counts).
- **Per-platform runtime lane**: one owner per platform (tester **XOR** fixer).
- Resume tester only when queue issue has `retest_ready: true`.
- Queue owner: `validation/testing-issue-queue.json` (handoff). Ledger JSON = status only.

## Resource mutex

| Lane | Lock | Competes with |
| --- | --- | --- |
| macOS runtime | `testing_ledger_runtime_lock.sh --platform macos` | other macOS agents only |
| iOS runtime | `testing_ledger_runtime_lock.sh --platform ios` | other iOS agents only |
| Shared | `cross_platform_validation_lock.sh` (seed, xcodebuild, simctl) | both platforms |

Pipeline per platform: tester fail → `testing:ledger-issue` → **STOP** → fixer → `mark-retest-ready` → tester retest via `testing:ledger-run`.

## iOS lane card (no full skill)

- Build: `xcodebuild` via `cross_platform_validation_lock.sh`
- Prove: `npm run testing:ledger-run -- --platform ios`
- Capture owner: `cross_platform_screen_validate.sh`
- Read `@build-ios-app` only when build/capture flags fail — not at turn start

## Commands

```bash
npm run testing:ledger-run -- --platform macos
npm run testing:ledger-fix-run -- --platform ios
npm run testing:ledger-issue -- --screen auth --flow auth-privacy-link --platform macos --observed "..."
./script/testing_ledger_session.sh preflight   # coordinator only
```
