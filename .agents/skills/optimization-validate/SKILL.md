---
name: optimization-validate
description: >-
  Record agent-workflow optimizations and validate them against later Cursor
  sessions using Musk algorithm (question → delete → simplify → automate).
  Use when the user asks to validate an optimization, check if routing/token
  fixes helped, rerun optimization audit, or record claims from an optimization
  session. Triggers: optimization validate, did the fix work, musk validate,
  session optimization registry.
allowed-tools: Bash
disable-model-invocation: true
---

# optimization-validate — record, validate, simplify

Musk loop for agent-workflow changes: **question the claim → measure sessions → delete what didn't help → simplify what did**.

## Owner

| What | Path |
| ------ | ------ |
| Registry (one row per wave) | `session/optimization-registry.json` |
| Validator | `npm run optimization:status` / `optimization:validate` |
| Transcripts | `CURSOR_TRANSCRIPT_ROOT` or auto-discover under `~/.cursor/projects/*like-minded*/agent-transcripts` |
| Grader | `npm run verify:optimization` |

Do not add parallel optimization ledgers or markdown status tables.

---

## When to run

| Trigger | Action |
| --------- | -------- |
| End of optimization / routing / context session | **Record** claims + commit |
| User reruns skill | **Status** → if pending, ask validate → **Validate** |
| User says "did it work?" | **Validate** last unvalidated row |
| Verdict `helped` | **Simplify** pass (delete ceremony) |
| Verdict `not_helped` / `partial` | **Fix** pass (one owner patch, re-record) |

---

## Flow (agent)

### 1. Status (always first)

```bash
npm run optimization:status
```

- **No rows** → ask user what optimization to record, then record.
- **Pending validation** (`validated_at: null`) → ask user:

  > Validate optimization `<id>` recorded at `<recorded_at>`? (yes/no)

  If `baseline_validation` exists but `validated_at` is null, note baseline already confirmed the problem — this run is **post-fix** (`--mode after`).

- **yes** → step 2. **no** → stop or record new wave if user directs.
- **Already validated** (`validated_at` set) → offer `--force` re-validate only if user asks.

### 2. Validate (deterministic mine + Musk judgment)

```bash
npm run optimization:validate -- --id <slug> --sessions 10          # post-fix (default)
npm run optimization:validate -- --mode baseline --sessions 10        # pre-fix proof only
npm run optimization:validate -- --mode after --sessions 10 --min-sessions 3
npm run optimization:validate -- --transcript-dir ~/.cursor/projects/<slug>/agent-transcripts
```

`--mode baseline` writes `baseline_validation` only — does **not** close the row. Only `--mode after` sets `validated_at`.

**Scoring (v2):**

- Failure signals mined from **user turns only** (frustration / re-teach)
- Success signals from **assistant turns** (echo is weak signal)
- **Behavioral:** tool trace — `Read GOAL.md`/`PROGRESS.md` before `ledger:screen`/`goal:next` = fail; `ledger:screen` without forbidden read = strong success
- **Verdict:** `helped` only if after fail-rate **< 50% of baseline** fail-rate AND behavior success ≥40% AND min 3 sessions / 5 user prompts
- `insufficient_data` / `no_data` — row stays pending

Script mines Cursor sessions relative to `recorded_at`:

| Verdict | Meaning |
| --------- | --------- |
| `helped` | after fail-rate < 50% baseline; behavioral success ≥40%; min sessions met |
| `partial` | mixed — failure signals or behavior not consistently better |
| `not_helped` | after worse than baseline or behavior regressions |
| `insufficient_data` | transcripts exist but below `--min-sessions` / `--min-user-prompts` |
| `no_data` | no transcripts after anchor — row stays **pending** |

Agent adds **human judgment** (not script-only):

- Did agents actually run `continue_command` / `forbidden_until_continue`?
- Did false visual "done" claims drop?
- Did user still re-teach product rules in chat?

### 3. Musk simplify (verdict = helped)

Delete before adding:

- Duplicate lines in hook / AGENTS / goal:next that repeat work bucket
- Manual `session:stamp` docs if auto-stamp covers 100% of sessions
- Registry rows that passed validation → mark `archived: true` in place (do not add sibling file)

Ship smallest follow-up PR: **one deletion or one grader**, not a new surface.

### 4. Musk fix (verdict = partial / not_helped)

One fix per failure cluster — patch the **owner** named in `musk.fix` from script output:

- Transcript still shows "we just completed…" → work bucket not injected at hook → fix `session_route.js`
- Still "still nowhere near" → proof not in first_command → wire `proof_command` earlier
- Still re-teaching placement → decisions not in compact hook → inject top 2 `work_decision_*` lines only

Re-record only if claims changed; otherwise update same registry row `validated_at` after fix.

---

## Record (end of optimization session)

```bash
npm run optimization:record -- \
  --id agent-routing-work-bucket-2026-07-10 \
  --session "<cursor-transcript-uuid>" \
  --claims "claim one;claim two;claim three" \
  --changes "path or command;path or command" \
  --failure-signals "still nowhere near;we just completed;Phase 9" \
  --success-signals "work_surface;continue_command;forbidden_until_continue"
```

**Record gate:** blocks new row while another is `validated_at: null` (use `--replace` to override).

Capture `anchor_session_id` from Cursor transcript folder — filters after-window to sessions **after** that ID.

---

## 10-sessions-ahead checklist (what validation must answer)

Imagine you are **10 sessions after** the optimization. Mine transcripts from `recorded_at` → now and answer:

1. **Session amnesia** — user still says "we just finished X last pass"? (failure)
2. **Wrong lane** — agent opens Phase 9 / full PROGRESS before screen work? (failure)
3. **False done** — "parity" / "done" without screenshot compare? (failure)
4. **Product re-teach** — same placement rules explained 3+ times in one session? (failure)
5. **Over-retrieval** — glob mockups / grep transcripts before `ledger:screen`? (failure)
6. **Continue contract** — `work_surface`, `continue_command`, `forbidden_until_continue` in hook output? (success)
7. **Proof discipline** — `ledger:record-flow` passes include screenshot + mockup evidence? (success)
8. **Ceremony creep** — new docs/skills duplicating work bucket? (failure → delete)

If 6–7 pass and 1–5 drop → **simplify**. If 1–5 persist → **one grader or hook fix**, not more prose.

---

## Do not

- Add a second registry or PROGRESS-style status prose
- Validate by opinion alone — run `optimization:validate` first
- Record every tiny edit — one row per **coherent optimization wave**
- Skip user confirm on re-validate when a pending row exists

---

## Self-validate

After editing this skill or `script/optimization_validate.js`:

```bash
node --check script/optimization_validate.js
node --check script/lib/optimization_validate_lib.js
node --check script/verify_optimization.js
npm run verify:optimization
npm run optimization:status
```
