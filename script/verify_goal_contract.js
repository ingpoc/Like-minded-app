#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function commandSet(goal) {
  return new Set(goal.deterministic_graders.map((grader) => grader.command));
}

function assertGoalShape(file, goal) {
  assert.equal(goal.schema_version, 1, `${file}: schema_version must be 1`);
  assert.ok(["pending", "active", "completed"].includes(goal.status), `${file}: status must be pending, active, or completed`);
  assert.ok(goal.goal || goal.purpose, `${file}: goal or purpose is required`);
  assert.equal(goal.ultimate_goal_source, "GOAL.md", `${file}: ultimate goal must point to GOAL.md`);
  assert.equal(goal.progress_source, "PROGRESS.md", `${file}: progress source must point to PROGRESS.md`);
  assert.ok(goal.workflow_refs?.includes("docs/workflows/validation.md"), `${file}: validation workflow ref is required`);

  const commands = commandSet(goal);
  for (const command of [
    "npm run check",
    "npm run smoke:mvp",
    "npm run verify:release-config",
    "npm run verify:goal",
    "npm run verify:ledger-progress",
    "workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs lint",
    "npm run verify:simulator-local"
  ]) {
    assert.ok(commands.has(command), `${file}: missing grader command ${command}`);
  }

  for (const grader of goal.deterministic_graders) {
    assert.equal(grader.cost, "zero_token", `${file}: ${grader.name} must be zero_token`);
    assert.ok(grader.proves, `${file}: ${grader.name} must state what it proves`);
  }

  assert.equal(
    goal.validation_inventory?.local_simulator?.command,
    "npm run verify:simulator-local",
    `${file}: local simulator validation inventory must reuse npm run verify:simulator-local`
  );
  assert.equal(
    goal.validation_inventory?.local_simulator?.script,
    "script/verify_simulator_local.sh",
    `${file}: local simulator validation inventory must point to the existing script`
  );
  assert.equal(
    goal.validation_inventory?.external_preflight?.command,
    "npm run verify:external-preflight",
    `${file}: external preflight inventory must reuse npm run verify:external-preflight`
  );
  assert.equal(
    goal.validation_inventory?.external_preflight?.evidence_file,
    "release/testflight-evidence.json",
    `${file}: external preflight inventory must point to the evidence file`
  );
  assert.equal(
    goal.validation_state?.local_simulator?.command,
    "npm run verify:simulator-local",
    `${file}: local simulator validation state must name the existing command`
  );
  assert.equal(
    goal.validation_state?.local_simulator?.do_not_repeat_unless_inventory_inputs_changed,
    true,
    `${file}: local simulator state must guard against repeat proof without input changes`
  );
  assert.equal(
    goal.validation_state?.external_preflight?.command,
    "npm run verify:external-preflight",
    `${file}: external preflight validation state must name the existing command`
  );
  assert.ok(
    goal.agent_guardrails?.some((guardrail) => guardrail.includes("Reuse validation_inventory scripts")),
    `${file}: agent guardrails must require reusing validation inventory scripts`
  );
  assert.ok(
    goal.agent_guardrails?.some((guardrail) => guardrail.includes("verify:ledger-progress")),
    `${file}: agent guardrails must require ledger ↔ PROGRESS ownership via verify:ledger-progress`
  );
  assert.ok(
    goal.done_criteria?.some((criterion) => criterion.includes("verify:ledger-progress")),
    `${file}: done criteria must require npm run verify:ledger-progress`
  );

  assert.equal(goal.simulator_validation?.preferred_agent?.name, "validation-release", `${file}: simulator preferred agent must be validation-release`);
  assert.equal(goal.simulator_validation?.preferred_agent?.model, "gpt-5.4-mini", `${file}: validation-release must be pinned to gpt-5.4-mini`);
  assert.equal(goal.simulator_validation?.preferred_agent?.effort, "medium", `${file}: validation-release effort must be medium`);

  const validationAgent = goal.subagents?.allowed?.find((agent) => agent.name === "validation-release");
  assert.ok(validationAgent, `${file}: validation-release subagent policy is required`);
  assert.equal(validationAgent.model, "gpt-5.4-mini", `${file}: validation-release model must be gpt-5.4-mini`);
  assert.equal(validationAgent.effort, "medium", `${file}: validation-release effort must be medium`);
  assert.ok(validationAgent.cannot_do.some((item) => item.includes("weaken assertions")), `${file}: validation-release must be forbidden from weakening assertions`);

  const totalWeight = goal.rubric.criteria.reduce((sum, criterion) => sum + criterion.weight, 0);
  assert.ok(Math.abs(totalWeight - 1) < 0.0001, `${file}: rubric weights must sum to 1`);
  assert.ok(goal.rubric.min_score >= 0.7, `${file}: rubric minimum score must be at least 0.7`);
  assert.equal(goal.completion_commit?.required, true, `${file}: completion_commit.required must be true`);
  assert.ok(goal.completion_commit?.must_include?.includes("goal.json"), `${file}: completion commit must include goal.json`);
  assert.ok(
    goal.completion_commit?.when?.includes("before marking the session goal complete"),
    `${file}: completion commit timing must be before marking the goal complete`
  );
  assert.ok(
    goal.done_criteria.some((criterion) => criterion.includes("committed") && criterion.includes("goal.json") && criterion.includes("completed")),
    `${file}: done criteria must require committing completed goal.json`
  );
  assert.ok(
    goal.release_gate?.external_preflight?.includes("npm run verify:external-preflight"),
    `${file}: release gate must keep external preflight verification outside active done criteria`
  );
  assert.ok(
    !goal.done_criteria.some((criterion) => criterion.includes("npm run verify:external-preflight")),
    `${file}: done criteria must not require external preflight verification`
  );
  assert.ok(goal.max_iterations > 0, `${file}: max_iterations must be positive`);
}

const template = readJson("goal.template.json");
const current = readJson("goal.json");

assertGoalShape("goal.template.json", template);
assertGoalShape("goal.json", current);

assert.deepEqual(
  [...commandSet(current)].sort(),
  [...commandSet(template)].sort(),
  "goal.json and goal.template.json must list the same deterministic grader commands"
);

console.log("Goal contract verified");
