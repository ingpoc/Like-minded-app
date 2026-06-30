# Agent Simulation

## Control Owner

Workflow for testing whether an agent can run any repo workflow with the right context and without repeated work.

Use this only when the main agent believes a workflow needs validation before simplification or optimization.

## When To Use

Use simulation when changing or validating:
- `AGENTS.md`
- `goal.json` or `goal.template.json`
- `save-session` or `resume-session`
- context graph behavior
- validation or release workflows
- project agents or delegation policy
- any workflow where the next agent may repeat proof, over-retrieve, invent surfaces, or miss the first command

Do not use simulation for one-step deterministic edits or when direct verification already answers the risk.

## Method

Use cheap read-only sidecars with `cost_scan`. Pick the smallest simulation shape that tests the workflow risk.

Known session-boundary pattern:

1. Fresh-session simulation:
   - start from repo instructions only
   - follow Session Start
   - report first commands, context loaded, next action, avoided work, and friction

2. Resume-session simulation:
   - run `resume-session` first
   - follow the checkpoint route contract
   - report first commands, context loaded, next action, avoided work, and friction

The main thread keeps decisions. Sidecars only report.

Other workflow simulations can use one or more sidecars with role prompts that match the workflow being tested. Examples:
- release-validator simulation for a release checklist
- implementation-worker simulation for a build workflow
- review-agent simulation for a code review workflow
- context-retrieval simulation for a docs or decision-graph workflow

## Prompt Shape

Fresh-session prompt:

```text
Read-only simulation. In <repo>, act like a fresh-session agent starting with no checkpoint. Follow repo Session Start instructions as written, but do not edit files. Run only safe read-only commands. Report: commands run, key outputs, friction/ambiguity/inefficiency from session start to deciding next action, whether any proof would be rerun or skipped, and what could still be simplified.
```

Resume-session prompt:

```text
Read-only simulation. In <repo>, act like a resume-session agent. Run/read resume-session checkpoint first, then follow repo resume/session-start instructions, but do not edit files. Run only safe read-only commands. Report: commands run, key outputs, friction/ambiguity/inefficiency from resume to deciding next action, whether the checkpoint prevents repeated work, and what could still be simplified.
```

Generic workflow prompt:

```text
Read-only simulation. In <repo>, act like an agent trying to run <workflow>. Follow the documented workflow as written, but do not edit files. Run only safe read-only commands. Report: commands run, key outputs, context loaded, first decision point, friction/ambiguity/inefficiency, repeated-work risk, and what could still be simplified.
```

## Pass Criteria

The workflow is healthy when sidecars:
- converge on the expected next action or decision
- load only the needed context
- do not rerun completed proof unless inputs changed
- do not create or suggest duplicate scripts, docs, workflows, or agents
- identify the same blocker or stop condition

If only a stronger model can navigate the workflow, simplify the workflow.

## Fix Loop

If the simulations find friction:
1. patch the owner surface, not the sidecar prompt
2. remove duplicate routing or prose
3. move active state to the real owner
4. make first command and stop condition explicit
5. rerun the smallest useful simulation with `cost_scan`

## Output Contract

Report:
- sidecar model/profile used
- simulation shape used
- next action or decision reached by each sidecar
- repeated-work risk
- over-retrieval risk
- simplifications made or intentionally skipped
