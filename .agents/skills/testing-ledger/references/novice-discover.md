# Novice discover (Mode A — repo)

Global catalog-then-fix doctrine: `~/.agents/skills/testing-framework` Mode **A**.
For queue closeout prefer Mode **B** sole-owner (`SKILL.md`).

## Efficiency contract

```text
Novice (per platform)          Coordinator
─────────────────────          ───────────
prove many flows               (waits)
fail: file + CONTINUE
no product/harness edits
return catalog          ───►   verify logs/PNGs
                               batch fix → mark retest-ready
                        ◄───   respawn
retest fixed ids FIRST
then discover more
until issues=[]                stop when clean
```

## Lean discover packet

```text
role: novice discover owner
platform: macos|ios
mode: discover-only | retest-then-discover
retest_first: [issue-id or screen/flow, ...]   # required in retest-then-discover
coverage_stop: ≥N proofs OR scope drained
first_command: npm run testing:ledger-run -- --platform <p>
continue_past_failure: true
no_edits: true
return_schema: below (also global capsules Mode A)
stop: coverage_stop; do not fix; do not stop at first issue
```

No GOAL/PROGRESS, full ledger, mockups, or sibling-platform state.

## Return schema

```text
platform: macos|ios
round: discover-only | retest-then-discover | N
flows_attempted: [{screen, flow, result, evidence_path}, ...]
retested_fixes: [{id, result, evidence}, ...]
issues: [{
  id_or_temp, severity, screen, flow_or_journey,
  summary, evidence_path, suspected_class, owner_hint
}, ...]
new_or_remaining_issues: [...]
coverage_note: …
```

`suspected_class`: `false_pass` | `missing_branch` | `launch_args` | `wrong_display` | `seed` | `app` | `copy` | `obsolete`.

## Round B (every later round)

1. `retest_first` ids via `testing:ledger-run --screen … --flow …` before new tips.
2. Then discover-only for remaining open/fail/pending.
3. Return `retested_fixes` + `new_or_remaining_issues`.
4. Stop when `new_or_remaining_issues: []` and retests pass or honestly checkpointed/obsolete-resolved.

## Main batch-fix rules

1. Verify each row against cited log/PNG.
2. Order: harness honesty → env → launch → display → seed → product.
3. Prefer one coherent batch clearing same-class issues.
4. Obsolete: delete owners → `--mark-resolved` (no retest).
5. Mark retest-ready only for flows that still exist.

## Anti-patterns

| Anti-pattern | Do instead |
| --- | --- |
| Fix inside novice after first fail | File + continue |
| Fix from catalog without opening logs | Verify evidence |
| Respawn without retesting fixes | Round B mandatory |
| Two novices on same platform | One runtime owner |
| Generic macOS screenshot as flow proof | Exact run card plus semantic Computer readback |
| Declare clean while issues[] non-empty | Keep Round B |
