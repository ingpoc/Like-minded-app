#!/usr/bin/env bash
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/tools/project-context"

if command -v uv >/dev/null 2>&1; then
  exec uv run --project "$PROJECT_DIR" project-context --root "$REPO_ROOT" "$@"
fi

run_compatible_python() {
  candidate="$1"
  shift
  if command -v "$candidate" >/dev/null 2>&1; then
    resolved="$(command -v "$candidate")"
  elif [ -x "$candidate" ]; then
    resolved="$candidate"
  else
    return 1
  fi

  if ! "$resolved" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 12) else 1)' >/dev/null 2>&1; then
    return 1
  fi

  export PYTHONPATH="$PROJECT_DIR/src${PYTHONPATH:+:$PYTHONPATH}"
  exec "$resolved" -m project_context.cli --root "$REPO_ROOT" "$@"
}

if [ -n "${PROJECT_CONTEXT_PYTHON:-}" ]; then
  run_compatible_python "$PROJECT_CONTEXT_PYTHON" "$@" || true
fi

run_compatible_python python3.13 "$@" || true
run_compatible_python python3.12 "$@" || true
run_compatible_python "$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3" "$@" || true
run_compatible_python python3 "$@" || true

echo "project_context.sh: Python >=3.12 is required; install uv or set PROJECT_CONTEXT_PYTHON" >&2
exit 2
