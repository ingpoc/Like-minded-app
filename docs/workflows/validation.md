# Validation

Global `AGENTS.md` owns instruction control. Commands and control owners only.

## Lazy retrieval

1. `npm run goal:next`
2. `npm run ledger:open` — gap audits / pending work (`ledger:stale` after source edits)
3. Touch **only** open ledger JSON files + active `PROGRESS.md` track section

Do not load `GOAL.md`, `DESIGN.md`, full `PROGRESS.md`, mockup dirs, or source trees for status questions.

## Control owners

| What | Owner |
|------|--------|
| Control status, success criteria, evidence | `validation/{ios,macos}/*.json` |
| Roadmap checkbox | `PROGRESS.md` active track |
| Index (regenerate) | `node validation/_generate.js` → `validation/README.md` |
| macOS routing / intentional variations | `docs/references/macos-screen-audit.md` — **no status table** |

**Actionable** = `fail`, `pending`, empty `controls`, `stale_pass` (hash mismatch), or `blocked` with automation-unavailable wording (not LiveKit/Apple infra).

`npm run verify:ledger-progress` — open controls need unchecked `PROGRESS.md` owners.

## Commands (by need)

| Need | Command |
|------|---------|
| Route | `npm run goal:next` |
| Open controls | `npm run ledger:open` / `ledger:stale` |
| Syntax | `npm run check` |
| API contract | `npm run smoke:mvp` |
| Release static | `npm run verify:release-config` |
| Goal contract | `npm run verify:goal` |
| macOS captures | `npm run verify:macos-screens` |
| iOS simulator | `npm run verify:simulator-local` |
| Seeded API | `npm run dev:api:validation` |
| Reset seed | `npm run reset:validation-data` |
| macOS CUA | `./script/macos_audit_prepare.sh` → `./script/macos_cua_screen.sh <screen>` |
| Phase checklist | `npm run phase:preflight -- <N>` |
| External gate | `npm run verify:external-preflight` |
| Hash refresh | `npm run ledger:refresh-hashes` |
| Record CUA | `node script/ledger_record_control.js` / `ledger_stamp_screen.js` |

## Ledger fields

- Screen `source_hash` — from `source_files`; refresh after Swift edits.
- Control `expected` — success criteria; `result` — pass/fail/blocked/pending.
- `last_tested_at`, `tested_source_hash`, `last_test_method` — set on proof; `pass` stale when hash differs.

## Rules

1. Fail/stub → keep unchecked `PROGRESS` owner in same session.
2. Never claim ledger-green while actionable rows exist (unless track owns them).
3. Update JSON + PROGRESS; do not add narrative status tables elsewhere.
4. While `macos_cua_screen.sh` exists, do not claim GUI automation unavailable in evidence.
5. `README.md` defers Phase 9 until `goal:next` shows clean tracks.

## Delegated verification

`validation-release` agent (`gpt-5.4-mini`, medium) for read-heavy simulator/screenshot runs only. Main thread owns product decisions and file edits.

## Update this file when

Commands, ledger schema, or control-owner paths change—not for per-screen status (that lives in JSON).
