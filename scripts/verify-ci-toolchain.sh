#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

# shellcheck source=../Tools/versions.env
source Tools/versions.env

[[ $(xcodebuild -version | head -n 1) == "Xcode $XCODE_VERSION" ]]
[[ $(swift format --version) == "$SWIFT_FORMAT_VERSION" ]]
[[ $(swiftlint version) == "$SWIFTLINT_VERSION" ]]

printf 'Verified Xcode %s, swift format %s, and SwiftLint %s.\n' \
  "$XCODE_VERSION" "$SWIFT_FORMAT_VERSION" "$SWIFTLINT_VERSION"
