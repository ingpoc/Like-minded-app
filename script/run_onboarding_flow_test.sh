#!/usr/bin/env bash
# Full macOS onboarding → tabs → settings → delete (delegates to optimized harness).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FLOW_TOKEN="${FLOW_TOKEN:-flow-onboard-$(date +%s)}"
export OUT="${OUT:-$ROOT/output/onboarding-flow-test}"
export CUA_CAPTURE="${CUA_CAPTURE:-failures}"
exec bash "$ROOT/script/macos_cua_manual_test.sh"
