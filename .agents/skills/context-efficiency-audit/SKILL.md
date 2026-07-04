---
name: context-efficiency-audit
description: "Find and fix stale context, duplicate routing, misleading prose, and inefficient trigger paths that make future agents waste tokens. Use when the operator asks variants of: stale context, context efficiency, agents wasting tokens, incorrect prose/docs/decision graph/routing/trigger, future agents should know exactly what to retrieve, make a skill to uncover similar issues, or remove context that is worse than no context. Spawns the `cost_scan` subagent pinned to gpt-5.4-mini/medium for bounded read-only discovery; main agent owns edits and validation."
allowed-tools: Bash
---

# context-efficiency-audit — remove token-wasting context



Use this when stale or contradictory repo context is more dangerous than missing context. The skill produces a compact issue list from a cheap scan, then the main agent applies the smallest confirmed fixes.

## Operating contract

| Field | Decision |
|---|---|
| Primary archetype | agent orchestration |
| Secondary archetypes | deterministic script workflow |
| Operator trigger | "stale context", "context efficient", "agents wasting tokens", "incorrect prose/docs/context graph/routing/trigger", "know exactly what to retrieve", "create a skill for similar issues" |
| Output | ranked stale-context findings, minimal fixes, validation evidence |
| Success evidence | harmful stale routes are removed or demoted; deterministic checks pass; future first command is explicit |
| Deterministic surface | `scripts/stale-context-grep.sh` for obvious stale strings |
| Judgment surface | deciding which findings are harmful, what owner surface should change, and whether to delete, demote, or rewrite |
| Context loading | start with current task, `goal.json`, progress/route owners, and the deterministic grep; load deeper docs only for matched lines |

## Main Flow

### Preflight

1. Confirm this is a build/fix request. If the user only asks "is anything stale?", scan and report without edits.
2. Run the narrow owner command first when one exists, usually `npm run goal:next`, `git status --short`, or the repo-declared entrypoint.
3. Run `scripts/stale-context-grep.sh <repo-root>` to catch obvious stale strings before delegating.

### Delegate

Spawn exactly one subagent unless the repo has clearly disjoint context owners.

Use `multi_agent_v1.spawn_agent`:

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
3. Prefer one control owner. Do not add a new doc when an existing command or owner doc can answer the question.
4. Keep the diff small. Do not turn this into a broad docs refresh unless the user asked for that lane.

### Closeout

1. Rerun the deterministic grep for the fixed issue class.
2. Run the narrow validators for touched surfaces, commonly `npm run goal:next`, `npm run verify:goal`, `npm run check`, and docs lint.
3. Report remaining warnings separately from fixed harmful routes.
4. If a reusable first-command gap was fixed, save or update the tactical checkpoint only when the user asked for session save.

## Issue Taxonomy

Use the user's session prompts as the taxonomy:

- "Are there no new goals?" -> stale goal/progress prose or missing deterministic next-goal command.
- "Make sure to validate all screens..." -> broad validation requirement hidden behind a narrow resume route.
- "Was there any inefficient step..." -> incorrect prose, docs, decision graph, route contract, or trigger caused extra retrieval.
- "Recommendations..." -> missing owner command, duplicate owners, stale summary, or over-broad MCP/tool routing.
- "Stale context is more harmful than no context" -> remove/demote outdated routes instead of preserving them as equal current guidance.

## Hard Rules

1. **Cheap scanner, main judgment.** `cost_scan` finds candidates; the main agent decides and edits.
2. **Current routes only.** Historical mentions are acceptable only when explicitly labeled historical and not used as next-action routing.
3. **First command or delete.** If a surface cannot tell the next agent the first command, improve it or remove it from the active route.
4. **No broad rewrites by default.** Fix the harmful stale context class that triggered the skill.
5. **Model discipline.** Use `cost_scan` (`gpt-5.4-mini`) for scans; escalate only when implementation risk, not scanning volume, demands it.

## Cross-references

- [references/cost-scan-prompt.md](references/cost-scan-prompt.md) — bounded subagent prompt
- [scripts/stale-context-grep.sh](scripts/stale-context-grep.sh) — deterministic stale-string scan
- Related skills: `save-session`, `resume-session`, `session-introspection`

## Why this skill exists

This prevents agents from burning context on stale goals, obsolete tab names, duplicate design owners, generic checkpoints, and broad retrieval when a repo already has enough evidence to route narrowly.
