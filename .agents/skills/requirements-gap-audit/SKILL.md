---
name: requirements-gap-audit
description: "Use when the operator asks what is pending, whether the app is complete, which screens/flows/buttons are missing or broken, whether PROGRESS.md tracks requirements, or whether missing mockups should be generated. Defaults to scan mode; apply mode updates PROGRESS.md and may generate/store mockups only after explicit user approval."
allowed-tools: Bash
---

# requirements-gap-audit

> **Self-validate after edits:** `./scripts/validate.sh`

## Goal

Answer **what is still missing before claiming a surface is production-ready** — without re-discovering controls from source on every run.

**Repo doctrine (`AGENTS.md`):** lazy retrieval, lazy authoring, proactive prune, single control chain (JSON → PROGRESS → code).

**Control-status owner:** `validation/screens/*.json` (`flows[]` primary, `controls.{ios,macos}` detail).
**Roadmap owner:** unchecked items in `PROGRESS.md` tracks.
**Do not** rebuild a parallel backlog from `GOAL.md`, grep, or full app walks when ledgers already list pass/fail/pending/stale.

---

## Modes

- **scan** (default): read-only findings; propose `PROGRESS.md` additions; stop for approval.
- **apply**: only after explicit approval — update `PROGRESS.md`, optional mockups, fix smallest blockers, re-test touched controls only.

---

## Query router (pick one tier; do not preload all tiers)

| Tier | When | First commands | CUA / build |
|------|------|----------------|-------------|
| **A — Ledger status** | “What’s pending?”, “what’s left on macOS/iOS?”, backlog scan | `npm run goal:next` → `npm run ledger:open` → read **only** matching `PROGRESS.md` track section | **No** |
| **B — Single-screen proof** | Fix/verify one screen or one fail row | Tier A + **one** `validation/<platform>/*.json` + launch script for that screen | **Yes**, that screen only |
| **C — Full production audit** | “Every control”, “production-grade”, “full CUA coverage” | Tier A + runtime contract below | **Yes**, all non-pass rows in scope |

**Default to Tier A.** Escalate only when the user question or an open ledger row requires it.

---

## Tier A — minimum retrieval (high signal only)

Run in order; stop when the question is answered:

```sh
npm run goal:next
npm run ledger:brief                 # session anti-redo brief
npm run ledger:flow -- --platform macos --screen meet --flow rsvp-weekend --text  # one flow packet
npm run ledger:open                    # open + stale-pass rows
npm run ledger:stale                   # pass rows needing re-test after source change
npm run verify:ledger-progress
```

After CUA/manual proof on a flow (preferred) or control:

```sh
npm run ledger:record-flow -- --platform macos --screen meet --flow rsvp-weekend --result pass --evidence "..." --method CUA-click
# or control detail:
node script/ledger_record_control.js --platform macos --screen meet --control rsvp-sat-yes --result pass --evidence "..." --method CUA
npm run ledger:sync-flows -- --platform macos --screen meet
```

When Swift/source changes: `npm run ledger:refresh-hashes` then `npm run ledger:stale`.

Then read **only**:

- `goal.json` — active goal (not full `GOAL.md`)
- `PROGRESS.md` — **active track section only** (macOS or iOS), not all phases
- Individual `validation/screens/*.json` files **for open rows only** (`ledger:open` lists them)

### Tier A — do not load

- `GOAL.md`, `DESIGN.md`, `docs/product-direction.md`, `docs/workflows/validation.md` (unless Tier C visual dispute)
- `./script/project_context.sh query` when `goal:next` + `ledger:open` already route the track
- Full `PROGRESS.md` historical phases
- Mockup images or `mockups/**` listing (paths are in ledger JSON `mockup_ref`)
- Native source, API routes, seed scripts, `validation/README.md` (regenerate index only in apply)
- iOS tree when auditing macOS only (and vice versa)
- `Task`/`explore` subagents for status scans
- Builds, simulators, or CUA for controls already `pass` in JSON

**Trust `result: pass` rows** unless the user changed files listed in that screen’s `source_files` or asks for re-proof.

---

## Tier B — single-screen proof

1. Complete Tier A; pick **one** open ledger file.
2. Read **only** `source_files` from that JSON (not whole modules).
3. Launch: `./script/run_macos_manual_validation.sh <screen>` or iOS equivalent from `build-ios-app` skill.
4. CUA: `./script/macos_cua_screen.sh <screen>` (macOS).
5. Update **only** that JSON’s control `result` / `evidence`; run `npm run verify:ledger-progress` if `PROGRESS.md` changed.

---

## Tier C — full runtime audit

Use only when Tier A shows open rows **and** the user wants exhaustive proof.

1. Seed: `npm run dev:api:validation` + `npm run reset:validation-data`
2. For each **non-pass** control in scope (from `ledger:open`): CUA/manual test, persistence check when `backend_dependencies` exist
3. Visual parity: open `mockup_ref` from ledger JSON; window sizes via `./script/macos_audit_window_matrix.sh` (macOS)
4. Update JSON evidence; never mark `pass` without runtime proof

---

## Ledger fields (success criteria already live here)

Per **flow** in `validation/screens/*.json` (primary):

- `steps[]` — journey success criteria
- `validation.{ios,macos}.result` — `pass` | `fail` | `blocked` | `pending` | `not-applicable`
- `validation.*.evidence` — proof text (date + method)
- `validation.*.tested_source_hash` — stale when `source_files` change

Per **control** in `controls.{ios,macos}[]` (atomic regression):

- `expected` — per-control success criteria
- `result`, `evidence`, `blocker` — same semantics as flows

No separate control database. Do not re-inventory controls from Swift/JS when JSON exists.

---

## Output (scan)

```text
tier_used: A|B|C
ledger_summary: <from ledger:open>
findings: <only open rows + progress gaps>
recommended_next: <one screen or one fix>
re_test_required: <file paths or "none — ledger green for scope">
```

---

## Hard rules

1. **Ledger before source.** `npm run ledger:open` before any grep or codebase walk.
2. **Progressive disclosure.** Docs, mockups, source, backend — only for open rows or Tier C.
3. **No repeat CUA on `pass`.** Re-test only after code changes or explicit user request.
4. **One status owner.** JSON for control result; `PROGRESS.md` for roadmap checkboxes; `npm run verify:ledger-progress` binds them.
5. Default scan; ask before `PROGRESS.md` / mockup edits.
6. Subagents/explore only for Tier C disjoint slices (runtime vs backend), not Tier A.

## References

- [references/surface-scan-prompt.md](references/surface-scan-prompt.md)
- [scripts/requirements_surface_grep.sh](scripts/requirements_surface_grep.sh) — ledger summary helper, not a substitute for `ledger:open`
