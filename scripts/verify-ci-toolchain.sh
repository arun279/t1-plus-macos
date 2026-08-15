#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

# shellcheck source=Tools/versions.env
source Tools/versions.env

xcode_output=$(xcodebuild -version)
xcode_version=${xcode_output%%$'\n'*}
if [[ $xcode_version != "Xcode $XCODE_VERSION" ]]; then
  printf 'error: expected Xcode %s, got %s\n' "$XCODE_VERSION" "$xcode_version" >&2
  exit 1
fi

swift_format_version=$(swift format --version)
if [[ $swift_format_version != "$SWIFT_FORMAT_VERSION" ]]; then
  printf 'error: expected swift format %s, got %s\n' \
    "$SWIFT_FORMAT_VERSION" "$swift_format_version" >&2
  exit 1
fi

printf 'Verified Xcode %s and swift format %s.\n' \
  "$XCODE_VERSION" "$SWIFT_FORMAT_VERSION"
