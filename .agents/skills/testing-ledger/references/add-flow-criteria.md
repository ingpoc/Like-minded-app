# Add flow criteria

Use `npm run testing:ledger-add-flow` only when **all** are true.

## Must be true

| # | Criterion |
| --- | --- |
| 1 | **User journey** — a distinct outcome (not a duplicate of existing flow on same screen) |
| 2 | **Not in ledger** — `flow-id` absent on **all** screens (`testing:ledger-add-flow` checks globally) |
| 3 | **Implemented** — control exists in Swift for at least one platform |
| 4 | **Evidence** — you attempted runtime proof and it is not covered by an existing flow’s `control_ids` |
| 5 | **Spec** — at least one `--step` **or** one `--control-macos` / `--control-ios` |
| 6 | **Kebab id** — globally unique, e.g. `settings-sign-out-cancel` |

## Dedup checks (before add)

```bash
npm run ledger:flow -- --platform macos --screen <id> --flow <candidate-id> --text  # expect fail
rg '"id": "<candidate-id>"' validation/screens/   # expect no match
npm run ledger:screen -- --platform macos --screen <id> --section flows | rg <candidate-id>
```

If an existing flow’s `control_ids` already cover the button, **extend that flow** (edit JSON) — do not add a parallel flow.

## After add

- Flow starts `pending` with `proof` from `ledger:apply-proof` defaults
- Re-run proof with `testing-ledger` workflow
- Do not mark `pass` in the same turn as add without current native interaction proof

## Do not add

- Pure visual notes (use `ui_validation` on screen)
- Infra-only blockers (use `blocked` + `blocker` on existing auth/livekit flows)
- Duplicate tab-navigation / back flows already on `app-shell`
