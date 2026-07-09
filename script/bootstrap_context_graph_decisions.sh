#!/usr/bin/env bash
# Replay committed decision seeds into .context-graph/graph.db (gitignored).
# Safe to re-run: record-decision supersedes same decision_key.
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEEDS="$REPO_ROOT/tools/project-context/decision-seeds"
if [[ ! -d "$SEEDS" ]]; then
  echo "No decision seeds at $SEEDS" >&2
  exit 1
fi
for f in "$SEEDS"/*.json; do
  [[ -f "$f" ]] || continue
  echo "record-decision $(basename "$f")"
  "$REPO_ROOT/script/project_context.sh" record-decision "$f"
done
"$REPO_ROOT/script/project_context.sh" doctor
