# Context budget (testing-ledger)

## Per-role retrieval

| Role | Commands (max) | Files (max) |
| --- | --- | --- |
| Tester | `testing:ledger-run` → `ledger:record-flow` or `testing:ledger-issue` | 0 |
| Fixer | `testing:ledger-fix-run` → `mark-retest-ready` | 1 (`fix_owner`) |
| Coordinator | `testing:ledger-session preflight` | 0 (queue JSON only if spawning fixer) |

## NEVER preload

- `GOAL.md`, full `PROGRESS.md`, `validation/README.md`, `ledger:open` inventory
- `ledger:flow` after `testing:ledger-run` (PRE/PASS already on run card)
- `ledger:brief` every turn — coordinator preflight once/session only
- `mockups/**` — use `mockup_ref` from run card only
- All `validation/screens/*.json`
- Full `@build-ios-app` / `@testing-ledger` skill — use iOS lane card in `agent-coordination.md`
- `grep` / `explore` for button inventory

## On fix only

- Read **one** `fix_owner` path from fix card
- `npm run smoke:mvp` only if flow `backend[]` changed

## Session anti-redo

- Seed DB once/session (`reset:validation-data` in coordinator preflight or first prove)
- macOS shell flows: `macos_launch` without per-flow DB reset
- Do not re-run `ledger:open` after each pass — `testing:ledger-run` picks next

## iOS lane card (5 lines)

1. Entry: `npm run testing:ledger-fix-run -- --platform ios` or `testing:ledger-run -- --platform ios`
2. Build lock: `./script/cross_platform_validation_lock.sh`
3. Capture: `cross_platform_screen_validate.sh --screen <id> --platform ios`
4. Record: `ledger:record-flow --method screenshot`
5. Load `@build-ios-app` only on build/capture failure
