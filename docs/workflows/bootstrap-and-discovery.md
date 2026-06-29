# Bootstrap And Discovery

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This workflow describes repo bootstrap checks only.

Workflow for adding or discovering the first real project structure.

## Entry

Use when the repo is empty, newly initialized, or missing clear app structure.

## Steps

1. Inventory files with `rg --files` or `find` when no files exist.
2. Check for manifests before choosing tools: `package.json`, `pnpm-lock.yaml`, `vite.config.*`, `next.config.*`, `pyproject.toml`, `Cargo.toml`, or similar.
3. If no manifest exists, ask whether the user wants a new app scaffold or provide a minimal implementation plan before adding dependencies.
4. Once a stack is chosen, add repo-specific validation commands to `docs/workflows/validation.md`.
5. If repeated workflows emerge, recommend project-local agents with scope, model/effort, permissions, spawn rules, and validation.

## Do Not

- Do not infer a framework from the repo name alone.
- Do not add generic project agents before concrete repeated workflows exist.
- Do not copy global orchestration or writing doctrine into local docs.

## Output Contract

Report:
- files or manifests found
- stack or bootstrap assumption used
- docs updated
- validation command added or reason none exists yet
