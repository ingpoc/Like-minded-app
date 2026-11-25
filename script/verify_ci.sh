#!/usr/bin/env bash
# CI-01 acceptance: the API tests pass locally and the GitHub Actions CI run for the pushed HEAD succeeded.
# Waits up to CI_WAIT_SECONDS (default 900) for the run to finish. Read-only against GitHub.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
REPO="${CI_REPO:-ingpoc/Like-minded-app}"
[[ -f .github/workflows/ci.yml ]] || { echo "FAIL .github/workflows/ci.yml is missing" >&2; exit 1; }
npm run -s test:api > /tmp/likeminded-ci-verify-test-api.log 2>&1 || { echo "FAIL local test:api" >&2; tail -20 /tmp/likeminded-ci-verify-test-api.log >&2; exit 1; }
echo "PASS local test:api"
SHA="$(git rev-parse HEAD)"
git fetch -q origin
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
REMOTE_SHA="$(git rev-parse --verify -q "origin/$BRANCH" || true)"
[[ "$REMOTE_SHA" == "$SHA" ]] || { echo "FAIL HEAD $SHA is not pushed (origin/$BRANCH is ${REMOTE_SHA:-missing})" >&2; exit 1; }
deadline=$(( $(date +%s) + ${CI_WAIT_SECONDS:-900} ))
while :; do
  line="$(gh run list -R "$REPO" --workflow CI --commit "$SHA" --event pull_request --json databaseId,status,conclusion,url -q '.[0] | [.databaseId, .status, .conclusion, .url] | @tsv' 2>/dev/null || true)"
  if [[ -n "$line" ]]; then
    IFS=$'\t' read -r run_id status conclusion url <<<"$line"
    if [[ "$status" == "completed" ]]; then
      if [[ "$conclusion" == "success" ]]; then echo "PASS CI run $run_id on $SHA: $url"; exit 0; fi
      echo "FAIL CI run $run_id on $SHA concluded $conclusion: $url" >&2; exit 1
    fi
  fi
  (( $(date +%s) < deadline )) || { echo "FAIL no completed CI run for $SHA within ${CI_WAIT_SECONDS:-900}s (last: ${line:-none})" >&2; exit 1; }
  sleep 15
done
