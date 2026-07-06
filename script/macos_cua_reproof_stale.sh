#!/usr/bin/env bash
# CUA reproof for macOS stale-pass ledger controls after source changes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/script/macos_validation_batch.sh" --stale-only --cua-only "$@"
