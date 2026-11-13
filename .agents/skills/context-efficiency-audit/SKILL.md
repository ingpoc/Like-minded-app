---
name: context-efficiency-audit
description: "Find and fix stale context, duplicate routing, misleading prose, and inefficient trigger paths that make future agents waste tokens. Use when the operator asks variants of: stale context, context efficiency, agents wasting tokens, incorrect prose/docs/decision graph/routing/trigger, future agents should know exactly what to retrieve, make a skill to uncover similar issues, or remove context that is worse than no context. Spawns the `cost_scan` subagent pinned to gpt-5.4-mini/medium for bounded read-only discovery; main agent owns edits and validation."
allowed-tools: Bash
---

# context-efficiency-audit — remove token-wasting context

> **Self-validate after edits.** Any change to this skill's files (SKILL.md, scripts/, references/, templates/, assets/) must be followed by `./scripts/validate.sh`. Hard findings -> create-skill Optimize lane.

Use this when stale or contradictory repo context is more dangerous than missing context. Align fixes with **`AGENTS.md` Context doctrine**: lazy load, single owners, proactive prune. The skill produces a compact issue list from a cheap scan, then the main agent applies the smallest confirmed fixes **and hardens routing so the same class cannot recur without a deterministic failure**.

## Operating contract

| Field | Decision |
| --- | --- |
| Primary archetype | agent orchestration |
| Secondary archetypes | deterministic script workflow |
| Operator trigger | "stale context", "context efficient", "agents wasting tokens", "incorrect prose/docs/context graph/routing/trigger", "know exactly what to retrieve", "create a skill for similar issues" |
| Output | ranked stale-context findings, recurrence plugs, negative-scenario plugs, validation evidence |
| Success evidence | harmful stale routes are removed or demoted; **routing/triggers/graders prevent the same gap class from recurring**; deterministic checks pass; future first command is explicit |
| Deterministic surface | `scripts/stale-context-grep.sh` for stale strings, paired ledger desync (`validation/*.json` vs `.md`), and dirty-vs-goal path-class hints; repo `npm run verify:ledger-progress` for ledger ↔ PROGRESS ownership |
| Judgment surface | deciding which findings are harmful, what owner surface should change, whether to delete/demote/rewrite, and which negative scenarios still evade the gate |
| Context loading | start with current task, `goal.json`, `git status` path classes, progress/route owners, and the deterministic grep; load deeper docs only for matched lines |

## Job (non-optional)

Finding inefficiencies is only half the job. Every fix pass must also:

1. **Recurrence check** — ask: if a future agent never runs this skill, will the normal route (`goal:next`, `AGENTS.md` triggers, `verify:goal`, phase preflight, owner docs) still prevent this class of waste?
2. **Recurrence plug** — if not, update the **active** routing surface (command, grader, trigger, owner doc, generator), not only the one-off stale string.
3. **Self-critic negative scenarios** — list how an agent could still recreate the inefficiency (evasion, overclaim, wiped evidence, competing owners, completed goal with open work) and plug each cheaply in the same pass.
4. Prefer **deterministic failure** (`npm run verify:*`, `goal:next` output) over prose-only warnings.

Do not close the audit while recurrence relies on “agents should remember to run `/context-efficiency-audit` again.”

## Main Flow

### Preflight

1. Confirm this is a build/fix request. If the user only asks "is anything stale?", scan and report without edits.
2. Run the narrow owner command first when one exists, usually `npm run goal:next`, `git status --short`, or the repo-declared entrypoint.
3. Run `scripts/stale-context-grep.sh <repo-root>` (optional `--detail`) before delegating. Read all three sections: `stale_string_hits`, `ledger_desync`, `dirty_vs_goal_hint`.
4. Read `ledger_progress_ok` / `open_tracks` / `ledger_*` lines from `goal:next` when present.

### Delegate

Spawn exactly one subagent unless the repo has clearly disjoint context owners.

Use `multi_agent_v1.spawn_agent` when available; otherwise the main agent performs the same read-only scan:

- `agent_type`: `cost_scan`
- model: omit it; this role is already pinned to `gpt-5.4-mini`
- reasoning: omit it; this role is already medium effort
- write scope: read-only
- prompt: use [references/cost-scan-prompt.md](references/cost-scan-prompt.md)

Why `cost_scan`: the job is bounded read-heavy comparison across docs, goals, status, routing prose, and scripts. `gpt-5.4-mini` is the right price/performance fit; stronger models are reserved for integration judgment or non-obvious implementation.

### Main-Agent Fix

1. Review subagent findings against live files. Do not trust derived context alone.
2. Fix only harmful current-routing issues:
   - delete when the surface is obsolete,
   - demote to "historical" when it is useful history but bad routing,
   - rewrite when it is the active owner surface.
3. **For each fixed class, update the recurrence owner** (grader, `goal:next`, `AGENTS.md` trigger, `docs/workflows/validation.md`, generator, or skill) so the class fails closed next time.
4. **Self-critic:** write down negative scenarios that still evade the plug; implement the cheapest plugs in the same pass (expand regex, add desync check, reject empty ledgers, reject completed goal with broken ownership, surface `open_tracks` on `goal:next`).
5. Prefer one control owner. Do not add a new doc when an existing command or owner doc can answer the question.
6. Keep the diff small. Do not turn this into a broad docs refresh unless the user asked for that lane.

### Closeout

1. Rerun the deterministic grep for the fixed issue class.
2. Run `./scripts/validate.sh` when this skill’s files changed; otherwise run `npm run goal:next`, `npm run verify:goal`, `npm run check`, and docs lint as needed.
3. Report in three buckets: **fixed**, **recurrence plugs**, **remaining warnings** (with why they are acceptable or what still cannot be deterministically gated).
4. If a reusable first-command gap was fixed, save or update the tactical checkpoint only when the user asked for session save.

## Issue Taxonomy

Use the user's session prompts as the taxonomy:

- "Are there no new goals?" -> stale goal/progress prose or missing deterministic next-goal command.
- "Make sure to validate all screens..." -> broad validation requirement hidden behind a narrow resume route.
- "Was there any inefficient step..." -> incorrect prose, docs, decision graph, route contract, or trigger caused extra retrieval.
- "Recommendations..." -> missing owner command, duplicate owners, stale summary, or over-broad MCP/tool routing.
- "Stale context is more harmful than no context" -> remove/demote outdated routes instead of preserving them as equal current guidance.

Also treat these as first-class (observed in live sessions):

- Dirty path class vs `goal.json` (agents follow Phase N while dirty work is another track).
- Route scripts whose `after_dirty_resolved` ignores dirty path class.
- Competing status owners (PROGRESS vs audit table vs validation MD vs JSON).
- Duplicate ledger surface (sibling `validation/**/*.md` when JSON is the sole owner — delete MD).
- Generators/templates/skills that re-emit superseded placeholders or wrong mockup maps.
- Historical narrative in owner docs that still reads as current.
- Mockup extras treated as required gaps when product intentionally made them non-goals.
- Open `validation/*.json` fail/pending/stale-blocked without unchecked PROGRESS owners.
- Checked phase “manual proofs complete” / “functional parity” that still reads as ledger-green.
- Evasion: empty `controls: []`, wiped ledger dirs, `blocked` with “automation unavailable”, `goal.json` completed while ownership fails.

## Hard Rules

1. **Cheap scanner, main judgment.** `cost_scan` finds candidates; the main agent decides and edits.
2. **Current routes only.** Historical mentions are acceptable only when explicitly labeled historical and not used as next-action routing.
3. **First command or delete.** If a surface cannot tell the next agent the first command, improve it or remove it from the active route.
4. **Recurrence or it is not done.** A one-off prose fix without a route/grader plug is incomplete for this skill.
5. **Self-critic before closeout.** Name at least the top evasion paths for the class you fixed and plug or explicitly accept them.
6. **No broad rewrites by default.** Fix the harmful stale context class that triggered the skill.
7. **Model discipline.** Use `cost_scan` (`gpt-5.4-mini`) for scans; escalate only when implementation risk, not scanning volume, demands it.

## Cross-references

- [references/cost-scan-prompt.md](references/cost-scan-prompt.md) — bounded subagent prompt
- [scripts/stale-context-grep.sh](scripts/stale-context-grep.sh) — stale strings, ledger desync, dirty-vs-goal hints
- [scripts/validate.sh](scripts/validate.sh) — skill self-validate (grep + `verify:ledger-progress` + `goal:next`)
- Repo gates: `npm run verify:ledger-progress`, `npm run verify:goal`, `npm run goal:next`
- Related skills: `session-introspection`, `create-skill`, `requirements-gap-audit`

## Why this skill exists

This prevents agents from burning context on stale goals, obsolete tab names, duplicate design owners, generic checkpoints, and broad retrieval when a repo already has enough evidence to route narrowly — and from needing this skill again for the same failure class.
