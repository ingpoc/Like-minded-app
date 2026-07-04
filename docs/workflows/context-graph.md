# Context Graph

Workflow for the repo-local durable decision graph.

## Control Owner

Owner for:
- accepted decision storage, retrieval, trace/history, supersession, and structural health
- save-time decision capture policy

Should not contain:
- global Codex routing doctrine owned by `/Users/gurusharan/.codex/AGENTS.md`
- reusable `save-session` or `resume-session` skill behavior
- beta tracking policy owned by the global beta registry
- generated viewer, export, or reporting artifacts

## Minimum System

Keep:
- `./script/project_context.sh` as the only repo entrypoint
- `tools/project-context/` as the CLI implementation
- `.context-graph/graph.db` as the only canonical database
- `.context-graph/schema.sql` as the schema reference
- this workflow doc as the only context-graph operating route
- `tools/project-context/tests/` as regression proof

Do not add required HTML viewers, exports, project-specific miner agents, raw session imports, local beta wrappers, or duplicate DB files.

## Decision

| Situation | Action |
|---|---|
| Normal repo lane | **Skip** — `goal:next` + lane workflow suffice |
| Precedent for current task | `./script/project_context.sh query --task "…"` only if `decision_count > 0` |
| Full audit (rare) | `./script/project_context.sh active` |
| Agent needs precedence or override history | Run `./script/project_context.sh history --decision-key <key>` |
| Agent needs the why behind a decision | Run `./script/project_context.sh trace --decision-key <key>` |
| Agent needs explicit links around a decision | Run `./script/project_context.sh related --decision-key <key>` |

SessionStart, if enabled, may query active decisions only. It must not mine, validate, review, promote, render artifacts, or run beta logic.

## Trust Rules

- The graph stores accepted decision traces only; raw sessions and rejected candidates are not durable graph state.
- Save-time capture should reject duplicate control-surface doctrine that already belongs in global `AGENTS.md`, local `AGENTS.md`, workflow docs, reference docs, reusable skills, hooks, or `goal.template.json`.
- If a candidate decision has a better owner, move it there and do not store it as active context.

## Context Graph Principles (inspired by Foundation Capital's "Context Graphs: AI's Trillion-Dollar Opportunity")

The graph does not store rules ("what should happen in general"). It stores decision traces ("what happened in this specific case, why it was allowed to happen"). Before adding any decision to the graph, ask:

1. Is this a durable product decision (not a meta-system rule)? → If meta → belongs in AGENTS.md, skills, or workflow docs, not the graph.
2. Does this explain "why" something happened, not just "what"? → Rules tell the agent what should happen; traces capture what actually happened and why.
3. Would a future agent making a different decision benefit from knowing this precedent? → If yes, store it. If no → reject.
4. Is this stitched to evidence from the current session or live repo files? → Accepted entries must trace back to evidence.

Reference: https://foundationcapital.com/ideas/context-graphs-ais-trillion-dollar-opportunity

## Decision Admission Gate

Save a decision only when it is a durable trace with a future routing effect. It must include:
- a stable `decision_key`
- category and scope
- owner surface
- what was decided
- why that choice was made
- evidence source
- reuse condition
- supersede target, when replacing a prior decision

Eligible decisions:
- product, architecture, validation, privacy, release, or workflow precedent that changes future behavior
- owner-boundary decisions that prevent duplicate docs, scripts, workflows, agents, or hooks
- validation boundaries that say what proof is complete, what artifacts prove it, and when to rerun it
- conflict resolutions where live files, docs, memory, or prior decisions disagreed
- external blockers with exact evidence required before the next agent can complete the lane

Reject:
- raw progress notes, command logs, or "I ran X"
- temporary implementation details without future routing value
- duplicate doctrine already owned by AGENTS.md, workflow docs, reference docs, skills, hooks, or `goal.template.json`
- generic preferences with no repo-specific evidence
- failed attempts unless the failure established a reusable constraint
- summaries that say what changed but not why the chosen path should guide future work

## Add Or Supersede

Before recording a decision:
1. Query by task and category: `./script/project_context.sh query --task "<decision topic>"`.
2. Search likely keys and terms: `./script/project_context.sh search "<owner or topic>"`.
3. If a matching active decision exists with the same owner, category, and scope, supersede it only when the new evidence changes the decision, narrows it, or corrects it.
4. If the existing decision is still correct and the new fact is only execution progress, reject the candidate.
5. If the new decision covers a different scope or owner, add it with a distinct key.

Use the same `decision_key` lineage when superseding. Create a new key only when the subject, owner surface, or scope is genuinely different.

## Validation

Use:

```sh
./script/project_context.sh doctor
./script/project_context.sh record-decision /path/to/accepted-decision.json
./script/project_context.sh categories
./script/project_context.sh query --task "current task"
./script/project_context.sh trace --decision-key <key>
./script/project_context.sh related --decision-key <key>
./script/project_context.sh audit-active
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python3 -m pytest tools/project-context/tests -q
```

## Output Contract

Report:
- active decision count
- available categories
- task query and relevant active decisions returned
- decision trace/history used, when applicable
