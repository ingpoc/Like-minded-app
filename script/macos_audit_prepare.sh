#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8787}"
SCREEN="${1:-meetOverview}"
WINDOW_STATE="${2:-default}"

case "$WINDOW_STATE" in
  small)
    export LIKEMINDED_MAC_WINDOW_WIDTH="${LIKEMINDED_MAC_WINDOW_WIDTH:-1120}"
    export LIKEMINDED_MAC_WINDOW_HEIGHT="${LIKEMINDED_MAC_WINDOW_HEIGHT:-752}"
    ;;
  large)
    export LIKEMINDED_MAC_WINDOW_WIDTH="${LIKEMINDED_MAC_WINDOW_WIDTH:-1440}"
    export LIKEMINDED_MAC_WINDOW_HEIGHT="${LIKEMINDED_MAC_WINDOW_HEIGHT:-900}"
    ;;
  default)
    export LIKEMINDED_MAC_WINDOW_WIDTH="${LIKEMINDED_MAC_WINDOW_WIDTH:-1200}"
    export LIKEMINDED_MAC_WINDOW_HEIGHT="${LIKEMINDED_MAC_WINDOW_HEIGHT:-760}"
    ;;
  *)
    echo "Usage: $0 [mac-screen] [default|small|large]" >&2
    exit 2
    ;;
esac

cd "$ROOT_DIR"

if ! curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
  echo "Validation API is not running on http://127.0.0.1:$PORT" >&2
  echo "Start it in a separate terminal first: npm run dev:api:validation" >&2
  exit 1
fi

curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null
./script/run_macos_manual_validation.sh "$SCREEN"

node - "$SCREEN" <<'NODE'
const fs = require("fs");
const path = require("path");

const screen = process.argv[2];
const dir = path.join(process.cwd(), "validation", "macos");
const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((name) => name.endsWith(".json")) : [];
const ledger = files
  .map((name) => {
    const file = path.join(dir, name);
    return { file, data: JSON.parse(fs.readFileSync(file, "utf8")) };
  })
  .find(({ data }) => (data.source_files || []).some((source) => source.includes(`(${screen})`)));

console.log(`screen: ${screen}`);
if (ledger) {
  console.log(`ledger: ${path.relative(process.cwd(), ledger.file)}`);
  console.log(`mockup: ${ledger.data.mockup_ref || "missing"}`);
  console.log(`controls: ${(ledger.data.controls || []).length}`);
} else {
  console.log("ledger: not found");
  console.log("mockup: unknown");
}
console.log("manual_next: use Computer Use to inspect and operate this screen before moving on");
NODE
