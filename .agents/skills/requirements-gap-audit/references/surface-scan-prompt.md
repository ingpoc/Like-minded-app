# surface scan prompt

Read-only gap scan. **Default: Tier A (ledger status).** Do not edit files in scan mode.

## Tier pick

- **A** — status / backlog → ledger open rows + active roadmap section only
- **B** — one screen → one ledger JSON + CUA that screen
- **C** — full production → all non-pass rows in scope + runtime contract

## Tier A (run first; stop if answered)

```sh
npm run goal:next
npm run ledger:open                 # or --platform=ios|macos
npm run verify:ledger-progress      # when claiming track health
```

Read only open `validation/*/*.json` files listed by `ledger:open`, plus the matching `PROGRESS.md` track section.

**Do not:** `GOAL.md`, `DESIGN.md`, product docs, mockup dirs, source trees, `project_context` query, builds, CUA, subagents.

## Tier B

Tier A + one ledger file + `source_files` from that JSON + launch/CUA for that screen only.

## Tier C

Tier A + seed validation API + CUA every non-pass control in scope + visual `mockup_ref` compare when disputed.

## Findings (open rows only)

- `fail` / `pending` / `blocked` / stale `pass` (source changed)
- roadmap item missing for an open ledger row
- missing mockup when `mockup_missing: true` or visual_parity open

## Output

```text
tier_used: A|B|C
open_controls: ...
findings: ...
recommended_next: ...
re_test_required: ...
```

Ground every finding in ledger JSON, runtime observation, or an explicit user requirement — not invented scope.
