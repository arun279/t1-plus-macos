#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

configuration=${1:-Debug}
if [[ $configuration != Debug && $configuration != Release ]]; then
  printf 'usage: %s [Debug|Release]\n' "$0" >&2
  exit 64
fi

xcodebuild \
  -project T1Plus.xcodeproj \
  -scheme T1PlusApp \
  -configuration "$configuration" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath .build/DerivedData \
  -quiet \
  CODE_SIGNING_ALLOWED=NO \
  build
