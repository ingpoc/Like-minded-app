#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"
FRAMEWORK_DIR="${TESTING_FRAMEWORK_DIR:-$HOME/.agents/skills/testing-framework}"

resolve_node() {
  if [ -n "${NODE_BIN:-}" ] && [ -x "$NODE_BIN" ]; then
    printf '%s\n' "$NODE_BIN"
    return 0
  fi
  candidate="$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
  if [ -x "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    command -v node
    return 0
  fi
  for candidate in "$HOME"/.nvm/versions/node/*/bin/node; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

NODE_EXECUTABLE="$(resolve_node)" || {
  echo "testing-ledger validate: Node.js >=20 is required; set NODE_BIN" >&2
  exit 1
}

required=(
  "SKILL.md"
  "references/quality-gates.md"
  "references/agent-coordination.md"
  "references/context-budget.md"
  "references/fix-retest-loop.md"
  "references/hardened-workflow.md"
  "references/novice-discover.md"
)

for rel in "${required[@]}"; do
  test -f "$SKILL_DIR/$rel" || { echo "testing-ledger validate: missing $rel" >&2; exit 1; }
done

for binding in \
  "Requirements owner" \
  "Design owner" \
  "Journey inventory" \
  "State coverage" \
  "Coverage history" \
  "Verification gate" \
  "Orchestrator receipt" \
  "Quality dimensions" \
  "Evidence routes" \
  "Runtime identity"; do
  grep -Fq "| $binding |" "$SKILL_DIR/SKILL.md" || {
    echo "testing-ledger validate: missing framework binding: $binding" >&2
    exit 1
  }
done

stale_surfaces=(
  "$SKILL_DIR/SKILL.md"
  "$SKILL_DIR/references"
  "$REPO_ROOT/AGENTS.md"
  "$REPO_ROOT/PROGRESS.md"
  "$REPO_ROOT/README.md"
  "$REPO_ROOT/goal.json"
  "$REPO_ROOT/goal.template.json"
  "$REPO_ROOT/docs/workflows/setup.md"
  "$REPO_ROOT/docs/workflows/validation.md"
  "$REPO_ROOT/docs/references/project-context.md"
  "$REPO_ROOT/docs/references/convergence-field-pattern.md"
  "$REPO_ROOT/validation/screens/_template.flow.json"
  "$REPO_ROOT/validation/screens"
  "$REPO_ROOT/validation/testing-issue-queue.json"
  "$REPO_ROOT/package.json"
  "$REPO_ROOT/script/testing_ledger_run.js"
  "$REPO_ROOT/script/testing_ledger_next_flow.js"
  "$REPO_ROOT/script/ledger_session_brief.js"
  "$REPO_ROOT/script/ledger_stale_screens.js"
  "$REPO_ROOT/script"
)
if rg -n -i 'macos[-_ ]cua|hermes[-_ ]chrome|testing_ledger_prove_flow|CUA-click|cua-click|macos:validation-batch|validation:wave2-reproof|audit:macos|verify:macos-screens|testing:ledger-prove([^[:alnum:]_-]|$)' "${stale_surfaces[@]}"; then
  echo "testing-ledger validate: stale native/browser routing prose found; use bundled @Computer or @Chrome" >&2
  exit 1
fi

for owner in \
  "$REPO_ROOT/DESIGN.md" \
  "$REPO_ROOT/GOAL.md" \
  "$REPO_ROOT/validation/production-contract.json" \
  "$REPO_ROOT/validation/testing-issue-queue.json"; do
  test -f "$owner" || { echo "testing-ledger validate: missing owner $owner" >&2; exit 1; }
done

test -f "$FRAMEWORK_DIR/SKILL.md" || {
  echo "testing-ledger validate: global testing-framework unavailable at $FRAMEWORK_DIR" >&2
  exit 1
}

"$FRAMEWORK_DIR/scripts/validate.sh" >/dev/null
(cd "$REPO_ROOT" && npm run test:testing-ledger)

QUICK="$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py"
if test -f "$QUICK"; then
  python3 "$QUICK" "$SKILL_DIR"
fi

AUDIT="$HOME/.agents/skills/create-skill/scripts/audit.py"
if test -f "$AUDIT"; then
  python3 "$AUDIT" "$SKILL_DIR"
fi

echo '{"ok":true,"skill":"testing-ledger","quality_contract":"current"}'
