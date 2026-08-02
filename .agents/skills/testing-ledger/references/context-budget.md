# Context budget (testing-ledger)

Global capsule/coordinator rules: `~/.agents/skills/testing-framework`.

## Flow owner (C)

Load until cause established:

1. `testing:ledger-run` card + retained log/screenshot/AX
2. Flow route in platform prove script
3. Ledger `fix_owner` + same-flow implicated sources
4. Build skill only if build/capture path fails

Smallest coherent batch that prevents the next known journey fail — no one-file cap.

## Batch owner (B)

Load the deterministic batch plan, one runtime tuple, shared source owners, and only
the first-failure artifacts accumulated for that band. Keep full prove logs on disk.
Do not load each flow's full ledger packet up front; open a targeted card only when
that flow is reached or fails. Retain the batch id and resume cursor across fixes.

## Novice (A)

Lean packet + [`novice-discover.md`](novice-discover.md) only. No GOAL/PROGRESS/full ledger/mockups/sibling catalogs.

## Sidecar

One question, one evidence surface, bounded files. Returns findings; owner integrates.

## Anti-redo

- Preflight / `ledger:brief`: once per session
- Seed reset: once per deterministic need, under shared lock
- Full build: only when binary stale or build under test
- Batch build/install: once per unchanged source hash and explicit runtime tuple; later iOS proofs may use `LIKEMINDED_REUSE_IOS_INSTALL=1` only after the proof script matches source-fresh built and installed executable hashes
- Batch discovery: 8–12 source-local flows by default; stop at locality boundary
- Quality evidence: co-capture in one visit, record functional/visual/AX/trust separately
- Full-flow proof: after coherent fix batch
- Failed full prove: one compact first-failure artifact + one discriminator before any replay
- Runtime tuple: retain UDID/window/profile, app id, source hash, binary identity, fixture/user
- Dependent steps: stop after failed prerequisite; do not retain cascading timeout noise
- Structured evidence: read one stable snapshot; torn JSON means lock/writer diagnosis, not product analysis
- Coordinator after return: hash/stale + lock — not full prove-log reload when stamps match
- No respawn on env hard block or live lock holder

## Parallelism

One owner/novice per platform (iOS ∥ macOS OK); ≤1 read-only sidecar. Shared resources serialized.
