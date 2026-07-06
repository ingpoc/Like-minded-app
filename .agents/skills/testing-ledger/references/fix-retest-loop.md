# Fix / retest loop

## Classification

| Symptom | Class | First action |
| --- | --- | --- |
| Connection / auth gate | Env | `curl :8787/health`; API + seed |
| Wrong screen / blank window | Launch | Shell flows: no `--mac-screen` (deep-link lock). Else `macos_audit_prepare.sh` |
| Menu ⌘1-5 miss via CUA | Harness | `cua_menu_shortcut` (osascript foreground) — not `cua key` background |
| Control missing in CUA | App or ledger | Verify label in app; add `accessibilityIdentifier` in Swift if ledger `control_ids` are correct |
| Click ok, wrong data | API / seed | `smoke:mvp`; seed script |
| Crash / assert | App bug | Swift fix |

## Root cause (not symptom)

| Avoid | Do instead |
| --- | --- |
| `--force-tier` to green ledger | Fix proof or tier |
| `pass` without CUA | Run `macos_cua_screen.sh` |
| Skip rebuild after Swift edit | `xcodebuild` under lock |
| Patch copy only when layout broken | Fix layout/state in Swift |

## Retest scope

After **any** fix, rerun **full lane** for the same flow:

```bash
./script/macos_cua_preflight.sh
./script/macos_audit_prepare.sh <mac_screen>
./script/macos_cua_screen.sh <mac_screen>
```

Then `ledger:record-flow` with `--method CUA-click` (or `fail` + evidence).

## Fail recording

```bash
npm run ledger:record-flow -- --platform macos --screen <id> --flow <id> \
  --result fail --evidence "2026-07-06 CUA: <what failed>" --method CUA-click
```

Leave `pending` only if blocked on env — fix env first.
