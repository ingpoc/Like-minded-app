#!/usr/bin/env bash
# Unsigned native build check for iOS (simulator) and macOS.
# Resolves Swift packages once, checks project.yml and the Xcode project agree, then builds both schemes.
# Env: BCL_NATIVE_OUT (default /tmp/likeminded-native-build) holds DerivedData, SPM checkouts and logs.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${BCL_NATIVE_OUT:-/tmp/likeminded-native-build}"
PROJ="$ROOT_DIR/apps/ios-macos/Likeminded.xcodeproj"
mkdir -p "$OUT"
EVENTS="$ROOT_DIR/output/observability/native-build.jsonl"
mkdir -p "$(dirname "$EVENTS")"
emit() { printf '{"ts":"%s","service":"likeminded-native-build","event":"%s","step":"%s","status":"%s","duration_ms":%s}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$3" "$4" >> "$EVENTS"; }
run_step() {
  local step="$1"; shift
  local start=$(date +%s)
  if "$@" > "$OUT/$step.log" 2>&1; then
    emit build_step "$step" ok $(( ($(date +%s) - start) * 1000 ))
    echo "PASS $step ($(( $(date +%s) - start ))s)"
  else
    emit build_step "$step" failed $(( ($(date +%s) - start) * 1000 ))
    echo "FAIL $step; last lines of $OUT/$step.log:" >&2
    tail -30 "$OUT/$step.log" >&2
    exit 1
  fi
}

if command -v xcodegen >/dev/null; then
  (cd "$ROOT_DIR/apps/ios-macos" && xcodegen generate -q)
  if ! git -C "$ROOT_DIR" diff --quiet -- apps/ios-macos/Likeminded.xcodeproj; then
    echo "FAIL xcodegen: project.yml and Likeminded.xcodeproj disagree (run xcodegen generate and commit)" >&2
    exit 1
  fi
  echo "PASS xcodegen in sync"
fi

# BUILD-03: Xcode 27 ships the Metal compiler as a separate component; Sources/Shared has .metal shaders.
if ! xcrun metal --version >/dev/null 2>&1; then
  echo "FAIL metal toolchain missing (run: xcodebuild -downloadComponent MetalToolchain)" >&2
  exit 1
fi
echo "PASS metal toolchain present"

COMMON=(-project "$PROJ" -derivedDataPath "$OUT/dd" -clonedSourcePackagesDirPath "$OUT/spm" -packageCachePath "$OUT/spmcache" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)
# BUILD-02: on Xcode 27 SwiftPM's own download of the LiveKit binary xcframework zips hangs (0% CPU, no sockets)
# after the source checkouts finish. So the build uses a private package cache and seeds the binary artifacts into it
# with curl (checksum-checked) from the checked-out manifests; with the cache seeded, resolve takes seconds.
# Cold cache: resolve in the background until the checkouts land, stop it once it stalls, seed, then resolve again.
RESOLVED="$PROJ/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
RESOLVE=(xcodebuild -resolvePackageDependencies -project "$PROJ" -scheme Likeminded -clonedSourcePackagesDirPath "$OUT/spm" -packageCachePath "$OUT/spmcache" -onlyUsePackageVersionsFromResolvedFile)
seed_artifacts() {
  python3 - "$OUT/spm/checkouts" <<'PY' | while IFS=$'\t' read -r url sum; do
import pathlib, re, sys
seen = set()
for f in sorted(pathlib.Path(sys.argv[1]).glob("*/Package*.swift")):
    for url, sum_ in re.findall(r'\.binaryTarget\([^)]*?url:\s*"([^"]+)"\s*,\s*checksum:\s*"([0-9a-f]{64})"', f.read_text(errors="ignore"), re.S):
        if url not in seen:
            seen.add(url); print(f"{url}\t{sum_}")
PY
    name="$(printf '%s' "$url" | sed -E 's/[^A-Za-z0-9]/_/g')"
    dest="$OUT/spmcache/artifacts/$name"
    mkdir -p "$(dirname "$dest")"
    if [[ ! -s "$dest" ]] || [[ "$(shasum -a 256 "$dest" | cut -d' ' -f1)" != "$sum" ]]; then
      curl -sSfL --retry 2 -m 600 -o "$dest" "$url"
    fi
    [[ "$(shasum -a 256 "$dest" | cut -d' ' -f1)" == "$sum" ]] || { echo "FAIL checksum mismatch for $url" >&2; exit 1; }
    echo "PASS artifact cached: ${url##*/}"
  done
}
checkouts_match() {
  [[ -f "$OUT/spm/workspace-state.json" ]] && python3 - "$OUT/spm/workspace-state.json" "$RESOLVED" <<'PY'
import json, sys
state = json.load(open(sys.argv[1]))["object"]["dependencies"]
have = {d["packageRef"]["identity"]: (d["state"].get("checkoutState") or {}).get("revision") for d in state}
pins = {p["identity"]: p["state"].get("revision") for p in json.load(open(sys.argv[2]))["pins"]}
sys.exit(0 if have == pins else 1)
PY
}
fetch_checkouts() {
  local log="$OUT/spm-checkouts.log" pins last=-1 idle=0 waited=0 size have pid
  pins="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["pins"]))' "$RESOLVED")"
  "${RESOLVE[@]}" > "$log" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    sleep 5; waited=$((waited + 5))
    size="$(wc -c < "$log" | tr -d ' ')"
    if [[ "$size" == "$last" ]]; then idle=$((idle + 5)); else idle=0; last="$size"; fi
    have="$(find "$OUT/spm/checkouts" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    if { [[ "$have" -ge "$pins" ]] && [[ "$idle" -ge 20 ]]; } || [[ "$waited" -ge "${SPM_RESOLVE_TIMEOUT:-600}" ]]; then
      kill "$pid" 2>/dev/null || true; break
    fi
  done
  wait "$pid" 2>/dev/null || true
  echo "PASS spm checkouts fetched (${waited}s, $(find "$OUT/spm/checkouts" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') of $pins)"
}
if checkouts_match; then
  echo "PASS spm checkouts in $OUT/spm match Package.resolved (offline)"
  seed_artifacts
else
  fetch_checkouts
  seed_artifacts
  run_step spm-resolve perl -e 'alarm shift; exec @ARGV' "${SPM_RESOLVE_TIMEOUT:-600}" "${RESOLVE[@]}"
  checkouts_match || { echo "FAIL spm checkouts do not match Package.resolved after resolve" >&2; exit 1; }
fi
COMMON+=(-disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile)
run_step ios-build xcodebuild "${COMMON[@]}" -scheme Likeminded -destination "generic/platform=iOS Simulator" build
run_step macos-build xcodebuild "${COMMON[@]}" -scheme LikemindedMac -destination "platform=macOS" build
echo "PASS native builds (iOS simulator + macOS, unsigned)"
