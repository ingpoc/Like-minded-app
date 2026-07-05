# Validation

Global `AGENTS.md` owns instruction control. Commands and control owners only.

## Lazy retrieval

1. `npm run goal:next`
2. **One screen:** `npm run ledger:screen -- --platform ios|macos --screen <id> --section ui|controls|all`
3. **Gap audit only:** `npm run ledger:open` / `ledger:stale` — not for a single known screen
4. Touch open ledger JSON + active `PROGRESS.md` track section only

Do not load `GOAL.md`, `DESIGN.md`, full `PROGRESS.md`, `validation/README.md` status (none), mockup dirs, or source trees for status questions.

## Control owners

| What | Owner |
|------|--------|
| Control status, success criteria, evidence | `validation/{ios,macos}/*.json` |
| Roadmap checkbox | `PROGRESS.md` active track |
| Link index (no status) | `node validation/_generate.js` → `validation/README.md` |
| macOS proof routing | `docs/workflows/validation.md` § macOS proof |

**Actionable** = `fail`, `pending`, empty `controls`, `stale_pass` (hash mismatch), or `blocked` with automation-unavailable wording (not LiveKit/Apple infra).

`npm run verify:ledger-progress` — open controls need unchecked `PROGRESS.md` owners.

## Commands (by need)

| Need | Command |
|------|---------|
| Route | `npm run goal:next` |
| One screen ledger | `npm run ledger:screen -- --platform macos --screen <screen> --section ui\|controls\|all` |
| All open controls (gap) | `npm run ledger:open` / `ledger:stale` |
| Syntax | `npm run check` |
| API contract | `npm run smoke:mvp` |
| Release static | `npm run verify:release-config` |
| Goal contract | `npm run verify:goal` |
| macOS captures | `npm run verify:macos-screens` |
| macOS post-parallel batch | `npm run macos:validation-batch` (capture + sequential CUA; sole `:8787` owner) |
| iOS simulator | `npm run verify:simulator-local` |
| Seeded API | `npm run dev:api:validation` |
| Reset seed | `npm run reset:validation-data` |
| macOS CUA (one screen) | `./script/macos_audit_prepare.sh` → `./script/macos_cua_screen.sh <screen>` |
| macOS minimum window | `./script/macos_audit_window_matrix.sh small` = 1120×901 |
| Phase checklist | `npm run phase:preflight -- <N>` |
| External gate | `npm run verify:external-preflight` |
| Hash refresh | `npm run ledger:refresh-hashes` |
| Record CUA | `node script/ledger_record_control.js` / `ledger_stamp_screen.js` |

## Ledger fields

- Screen `source_hash` — from `source_files`; refresh after Swift edits.
- Screen `ui_validation` — visual pass/fail against `reference_mockup_ref`, `recent_screenshot_ref`, and `DESIGN.md`.
  - `validated`: what was checked for UI only.
  - `pending_validation`: UI checks still not run.
  - `requires_implementation`: missing UI surface/component.
  - `requires_fixing`: visible UI mismatch or unclear component.
  - Control behavior stays in `controls[]`, not `ui_validation`.
- Control `expected` — success criteria; `result` — pass/fail/blocked/pending.
- `last_tested_at`, `tested_source_hash`, `last_test_method` — set on proof; `pass` stale when hash differs.

## Rules

1. Fail/stub → keep unchecked `PROGRESS` owner in same session.
2. Never claim ledger-green while actionable rows exist (unless track owns them).
3. Update JSON + PROGRESS; do not add narrative status tables elsewhere.
4. While `macos_cua_screen.sh` exists, do not claim GUI automation unavailable in evidence.
5. Parallel macOS UI implementation per ledger JSON is OK; run `npm run macos:validation-batch` once after parallel workers (no concurrent CUA/capture).
6. `README.md` defers Phase 9 until `goal:next` shows clean tracks.

## Session alignment

Project hooks (`.cursor/hooks.json`): `sessionStart` injects compact `goal:next` output. Authoritative gate: `npm run verify:ledger-progress` (includes context-routing checks — no status tables in `validation/README.md`, no Phase 0–8 in `PROGRESS.md`).

## macOS proof (pick one)

| Situation | Command |
|-----------|---------|
| One screen, API up | `macos_audit_prepare.sh <screen>` → `macos_cua_screen.sh <screen>` |
| After parallel UI edits or `stale_pass` | `npm run macos:validation-batch` |
| Captures only | `npm run verify:macos-screens` |
| Stale controls only | `npm run macos:cua-reproof` |

Do not run capture/CUA in parallel across agents. Mockup path: ledger `mockup_ref` per screen.

## Delegated verification

`validation-release` agent (`gpt-5.4-mini`, medium) for read-heavy simulator/screenshot runs only. Main thread owns product decisions and file edits.

## Update this file when

Commands, ledger schema, or control-owner paths change—not for per-screen status (that lives in JSON).
