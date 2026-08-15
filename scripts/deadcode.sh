#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

mkdir -p .build
set -o pipefail
xcodebuild \
  -project T1Plus.xcodeproj \
  -scheme T1PlusApp \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath .build/DeadCodeDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  clean build 2>&1 | tee .build/xcodebuild.log

swiftlint analyze \
  --strict \
  --config .swiftlint.yml \
  --compiler-log-path .build/xcodebuild.log
