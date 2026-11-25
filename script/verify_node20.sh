#!/usr/bin/env bash
# Runs the API checks on the Node major pinned in .nvmrc (Render NODE_VERSION) via nvm.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then echo "FAIL nvm not found at $NVM_DIR" >&2; exit 1; fi
set +u; . "$NVM_DIR/nvm.sh"; set -u
WANT="$(tr -d '[:space:]' < .nvmrc)"
nvm use --silent "$WANT" >/dev/null || { echo "FAIL Node $WANT is not installed (nvm install $WANT)" >&2; exit 1; }
GOT="$(node -v)"
[[ "$GOT" == v"$WANT".* ]] || { echo "FAIL expected Node $WANT, got $GOT" >&2; exit 1; }
echo "node $GOT (npm $(npm -v))"
for step in check test:auth test:api smoke:mvp; do
  start=$(date +%s)
  if npm run -s "$step" > "/tmp/likeminded-node$WANT-$step.log" 2>&1; then
    echo "PASS $step on $GOT ($(( $(date +%s) - start ))s)"
  else
    echo "FAIL $step on $GOT; tail of /tmp/likeminded-node$WANT-$step.log:" >&2
    tail -20 "/tmp/likeminded-node$WANT-$step.log" >&2
    exit 1
  fi
done
