#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

derived_data=$(mktemp -d "${TMPDIR:-/tmp}/t1-plus-ui-tests.XXXXXX")
results_dir="$root/.build/UITestResults"
result_bundle="$results_dir/Test-$(date -u +%Y%m%dT%H%M%SZ)-$$.xcresult"
trap 'rm -rf "$derived_data"' EXIT
mkdir -p "$results_dir"

xcodebuild \
  -quiet \
  -project T1Plus.xcodeproj \
  -scheme T1PlusApp \
  -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$derived_data" \
  -resultBundlePath "$result_bundle" \
  test
