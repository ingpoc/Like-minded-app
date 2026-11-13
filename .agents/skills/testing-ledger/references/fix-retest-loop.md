# Fix / retest loop

## Classification

| Symptom | Class | First action |
| --- | --- | --- |
| Build/launch UI and AX/taps disagree | **Runtime identity** | Print the resolved UDID for build, install, launch, `IDB_UDID`, and capture; stop if any differ or more than one candidate is implicit |
| Click dispatch succeeds but the expected UI never appears | App, harness, or wrong runtime | Assert the semantic postcondition; run one direct click/readback diagnostic on the same explicit runtime before rebuilding |
| First prerequisite failed and later steps all time out | Harness control flow | Short-circuit dependent steps and retain only the first useful AX/screenshot/log artifact |
| Same full prove failed twice without changed evidence | Diagnosis loop | Switch to Mode C and change discriminator/class; do not rebuild and replay unchanged inputs |
| Tool call succeeds but the semantic state shows the wrong controls | **Harness false pass** | Repair exact `<screen>/<flow>` signals; accepted dispatch is never proof |
| `missing explicit … proof branch` | Harness gap | Implement branch that asserts the **user outcome**, then reprove |
| Connection / auth gate | Env | `curl :8787/health`; API + seed |
| Capture lands on wrong screen (Meet instead of Soulmate/Recap/Detail) | Launch args | `ios_launch_args_for_screen` / normalize + alias mirror in `cross_platform_screen_validate.sh` |
| Wrong window/display or collapsed app | Display | Relaunch canonical app, target its full path, and read fresh Computer state before product diagnosis |
| Native click dispatch and visible state disagree | Computer Use runtime | Use bundled `@Computer`; verify the semantic effect in the same app/window before another prove |
| Harness expects `Your room.` / UI shows `Your circle.` | Copy drift | Product wins — update prove expect strings |
| Menu shortcut has no observed effect | Harness | Use bundled Computer against the foreground canonical app and require destination readback |
| Control missing in Computer state | App or ledger | Verify rendered label; add `accessibilityIdentifier` if `control_ids` are correct |
| Click ok, wrong data | API / seed | `smoke:mvp`; seed script |
| Crash / assert | App bug | Swift fix |

## Root cause (not symptom)

| Avoid | Do instead |
| --- | --- |
| Trusting exit 0 without reading the prove log | Diff log labels vs flow PASS criteria |
| `--force-tier` to green ledger | Fix proof or tier |
| `pass` without the flow’s interaction assertions | Explicit prove branch + `testing:ledger-run` |
| Using a screenshot to “prove” an interaction | Capture is visual evidence only; interaction needs semantic postcondition proof |
| Skip rebuild after Swift edit | `xcodebuild` under lock |
| Patch harness copy when product decision changed | Align harness to product |

## Retest scope

After a fix, first run the cheapest targeted diagnostic that proves the repaired
postcondition on the same explicit runtime. Once it works, rerun the **same full flow**:

```bash
npm run testing:ledger-run -- --platform macos|ios --screen <id> --flow <id> --reprove
```

Operator discover rounds: after a fix batch, **retest fixed issues first**, then continue discovery.

Then `ledger:record-flow` with the tier method (or `fail` + evidence). Include `--screenshot-ref` and mockup compare text when `mockup_ref` is set.

## Fail recording

```bash
npm run ledger:record-flow -- --platform macos --screen <id> --flow <id> \
  --result fail --evidence "<dated Computer observation>" --method Computer-use
```

Leave `pending` only if blocked on env — fix env first.

## Launch-arg / capture alias hygiene

Logical ids (`soulmate-overview`, `past-meet-recap`, `community-detail`, `conversations`) must:

1. Map in `ios_launch_args_for_screen` (and normalize) to the real `--likeminded-start-*` flags.
2. Write or mirror PNGs under the **requested** logical name when the capture slug differs (avoid stale alias PNGs).

## iOS runtime identity preflight

Before an iOS prove, the adapter must resolve one simulator UDID and export it to
all nested commands. Build/install/launch and `validation/idb_ctl.sh` must not each
pick “first booted” independently. The prove log/capsule should record:

```text
udid=<explicit> bundle=<id> source_hash=<hash> binary=<path-or-hash> user=<fixture>
```

Fail before interaction if the installed bundle, AX tree, screenshot, or logs come
from a different UDID. This check is cheaper than diagnosing a false app failure.
