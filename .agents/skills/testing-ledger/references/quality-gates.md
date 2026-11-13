# Like-minded quality-gate adapter

Global doctrine: `~/.agents/skills/testing-framework`. This reference binds that
doctrine to existing Like-minded owners without creating a second ledger.

## Owner map

| Contract | Repo owner |
| --- | --- |
| Ultimate product outcome and scope | `GOAL.md` |
| Active roadmap | Active track in `PROGRESS.md` |
| Product design and experience language | `DESIGN.md` |
| Screen, platform, source, mockup, and current validation status | `validation/screens/*.json` |
| Functional journeys and pass signals | `flows[]` and `flows[].proof` in each screen JSON |
| Current visual evidence | `platforms.*.recent_screenshot_ref`, `ui_validation`, and `visual_parity` |
| Discovered gaps | `validation/gap-flows-registry.json` and `validation/testing-issue-queue.json` |
| Production scope | `validation/production-contract.json` |

Do not add a Markdown pass/fail table. Update the JSON owner when evidence changes.

## Gate sequence

### 0 — Test readiness

Before implementing or proving a screen family, confirm:

- the user outcome and applicable negative/recovery paths are represented by flows;
- `flows[].proof.success_signals` describe outcomes, not dispatched input;
- `DESIGN.md` defines what is immediately visible and progressively disclosed;
- each platform slice names current sources and a `mockup_ref` or an explicit reason;
- applicable default, loading, empty, error, offline, permission, dense/long-content,
  and accessibility states are covered by flows or recorded as gaps;
- every applicable quality dimension below has an evidence owner.
- every proof branch requires authoritative visible or persisted readback, fails
  closed, and has a regression test when a preview/debug route could manufacture
  success;
- the source-hash owner includes every state, view, and API seam that can change
  the claimed behavior.

Missing coverage is filed as a gap. Tests must not invent product decisions.

### 1 — Static and targeted semantic proof

Run cheap syntax/unit checks and the changed journey's targeted proof before the
final runtime acquisition. Then use:

```bash
npm run ledger:screen -- --platform ios|macos --screen <id> --section route
npm run testing:ledger-run -- --platform ios|macos --screen <id> --flow <id>
```

The flow pass proves only its declared functional/coherence signals at the required
tier. Require visible or persisted readback; launch, click, HTTP 200, build, and
generic screen capture are not outcome proof.

### 2 — Freeze one acceptance package

After test readiness and targeted proof pass, batch all known P0–P2 fixes and
freeze the product-source diff. Create
`output/validation/acceptance/<source-hash>/` with a compact manifest of the
source/build fingerprint, runtime identity, artifacts, and app-owned viewport.
Do not overwrite a `latest` package or begin blind review while the proof contract
or source is still changing.

```bash
npm run verify:acceptance-packet -- output/validation/acceptance/<source-hash>
```

Only a packet that passes this current-source, artifact-hash, media-type, and
dimension check may be handed to reviewers.

### 3 — Visual design capture

Capture through the locked repo script, then compare the live pixels with the
platform `mockup_ref` and `DESIGN.md`:

```bash
./script/cross_platform_screen_validate.sh --screen <id> --platform ios|both
```

Review hierarchy, typography, spacing rhythm, density, alignment, components,
immediate versus progressive disclosure, clipping, long content, relevant window
sizes, and the standard plus accessibility captures. Record current evidence in
the platform `ui_validation` / `visual_parity` fields. Missing fields remain open.
Do not drain the full affected screen-family flows before the first blind visual
and UX pass; a review-discovered source edit would stale that work. After dual
visual and UX acceptance, run those proofs from the same built/installed binary
and explicit runtime identity where the repository route supports reuse.

### 4 — UX journey

Give a fresh reviewer one user mission and only the visible app. Do not show source,
fixtures, control ids, prove branches, or previous findings. Record comprehension,
discoverability, feedback, cancellation, recovery, and trust failures as issue
capsules. A control drain cannot pass this gate.

### 5 — Accessibility, resilience, and trust

Use accessibility captures plus runtime interaction proof for reading/focus order,
labels and values, scaled content, contrast, targets, reduced motion, non-colour
cues, and keyboard/focus behaviour where applicable. Exercise relevant loading,
empty, error, offline, permission, timeout, retry, consent, privacy, reporting,
blocking, and destructive-action paths. Record separate evidence per dimension.

### 6–7 — Fix and independent re-review

Use Mode A when breadth is unknown. Freeze discovery, verify evidence, and cluster
findings by requirement, content, token, component, state, feature, API, fixture,
harness, or environment owner. Apply one coherent fix batch, run targeted proof,
then the full affected journey. Finally run a context-reset UX/visual discovery pass
without revealing the prior issue list.

### 8 — Frozen release

Close only when required `journey × state × dimension` cells have current evidence,
P0/P1 findings are closed, accepted lower-severity debt has an owner, locks and
temporary state are clean, and a subsequent full review on unchanged source finds
no new material issue. `verify:production-ready` remains necessary but cannot infer
missing visual, UX, accessibility, resilience, or trust acceptance.

## Efficient execution

Use contract → proof-branch review → static → targeted runtime → source freeze →
one immutable capture/functional packet → blind UX → accessibility/trust →
affected-journey regression → frozen full gate. Consolidate a review wave before
one coherent fix batch, then create a new fingerprint-keyed packet. Parallelize
only read-only review or disjoint platform work; serialize seed, build, launch,
capture, and each platform runtime mutex.
