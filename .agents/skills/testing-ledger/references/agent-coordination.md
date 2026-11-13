# Agent coordination (repo adapter)

Global modes/roles/capsules: `~/.agents/skills/testing-framework`. This file is **Like-minded dispatch only**.

## Mode choice (operator → mode)

| Operator ask | Mode |
| --- | --- |
| keep proving, drain queue, multitask, close ledger | **B** sole-owner drain (**default**) |
| novice test, find everything, batch issues before edits | **A** novice discover |
| fix this flow / this screenshot | **C** single-flow |

Never find-one → fix-one on the coordinator while a sole owner could hold the platform. Never `$session-orchestrate` hop per flow during a drain.

## Runtime lanes

```text
Coordinator (preflight + verify/spawn on completion)
 ├── macOS — one sole owner OR one novice; one bundled Computer session
 ├── iOS   — one sole owner OR one novice; may run beside macOS
 └── sidecar — read-only; no runtime/queue/ledger mutation
Shared serial: reset:validation-data, xcodebuild, launch/capture → cross_platform_validation_lock.sh
```

`testing:ledger-next` interleaves screens. Mode B first runs
`testing:ledger-batch-plan` to select an 8–12 flow source-local band, then retains
that batch id and resume cursor through discovery, clustering, fix, and retest.
Hash restale after an in-band fix is normal only inside the affected dependency cone.

### Mode B batch boundary

- One explicit runtime tuple and one build/install per unchanged source hash.
- Discover the bounded band before edits unless one failure blocks the remaining band.
- Ledger first failures, then cluster by root cause and `fix_owner`; do not find-one → fix-one.
- Retest fixed ids first, then affected journeys, then resume the saved cursor.
- Do not pad a small coherent band with unrelated screens merely to reach eight.

## Sole-owner drain — on every owner completion

```text
verify claimed flows (result=pass AND not stale vs current platform hash)
  → if holder dead: release stale lock
  → cull prove twins (keep lock-holder pid only)
  → if lock free AND tip actionable: spawn ONE sole owner
  → if contested / live holder: do nothing
```

Verify with `ledger_screens` (`flowValidation` + `isFlowStale` + `hashPlatformSlice`). Spot-check claimed prove branches / AX (`rg` + `bash -n`).

### Actionable vs stop tips

| Tip class | Action |
| --- | --- |
| `stale-pass` / `tier-gap` with working env | Spawn sole owner; prefer `testing:ledger-run` (no untargeted `--reprove`) |
| Missing prove branch / AX / control | Owner fixes product or harness, then proves — not N/A |
| Same blocker 3× unchanged | Checkpoint; continue other tips or stop slice |
| Env wall (`real-auth` + `googleAuth:false`, …) | **Stop** — do not respawn |
| Contested lock | Confirm holder; leave it |

### Lean sole-owner packet

Include: platform, batch id, ordered source-local flows, resume cursor, runtime tuple, open issue ids, hash caveat if family restaled, “other platform owned — do not touch”, return schema (global Mode B capsule).
Exclude: chat history, GOAL, sibling drain narratives, mockup walks.

### Friction (session-proven)

| Friction | Response |
| --- | --- |
| Product edit restales family | Re-drain; next packet names family + hash |
| Coordinator re-implements after good drain | Verify stamps only, then spawn |
| Second prove while lock held | Contested stop; cull twins only |
| `:8787` wrong db | Restart `dev:api:validation`; require `validation-db` in `/health` |
| iOS driver/Computer cannot drive control | Product accessibility (labels, identifiers, button wrappers) — do not loosen proof |
| Concept UI missing ledger control | Restore control + prove branch |
| Orphan app/sim, lock free | Kill orphan before next spawn |

## Single-flow (Mode C) — lean packet

platform, exact `screen/flow`, first command, proof-log path, stop conditions, owned source slice. Optional `--reprove` only when operator asks for fresh comparison of a clean pass.

Loop: `testing:ledger-run` → fail: issue + same-flow batch → release lock → claim/fix → `--mark-retest-ready` → full retest → record/checkpoint before switching flows.

## Novice discover (Mode A)

Packets + return schema: [`novice-discover.md`](novice-discover.md). Capsule shape also in global `capsules.md` (Mode A).

## Sidecars

At most one by default. Question + narrow files only. Never prove/seed/build/queue mutate.

## Never

- `ledger:open` / `ledger:flow` as work queue after `testing:ledger-run`
- Reload GOAL/PROGRESS/mockups for a bounded flow
- Sidecar or discover-novice product edits in discover-only
- Hold prove lock during non-in-band source edits
- Treat a generic screenshot or accepted Computer dispatch as flow proof
- Trust issue lists without opening cited log/PNG
- Respawn discover without retesting fixed ids first

## Mutex map

| Resource | Owner |
| --- | --- |
| Platform runtime | `testing_ledger_runtime_lock.sh` |
| Seed/API/build/capture | `cross_platform_validation_lock.sh` |
| Issue queue | Exact claim/update commands |
| Proof decision | Main after verify + full retest (or clean A round) |
