#!/usr/bin/env bash
set -euo pipefail

if [[ ${CI:-} != true || ${RUNNER_OS:-} != macOS ]]; then
  printf 'error: this script is restricted to an ephemeral macOS CI runner\n' >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

# shellcheck source=Tools/versions.env
source Tools/versions.env

tools_dir=$root/.build/ci-tools
archive=$tools_dir/portable_swiftlint.zip
mkdir -p "$tools_dir"

curl --fail --location --silent --show-error \
  "https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/portable_swiftlint.zip" \
  --output "$archive"
printf '%s  %s\n' \
  d6cb0aa7a2f5f1ef306fc9e37bcb54dc9a26facc8f7784ac0c3dd3eccf5c6ba6 \
  "$archive" | shasum -a 256 --check --status
unzip -oq "$archive" swiftlint -d "$tools_dir"
chmod +x "$tools_dir/swiftlint"

actual_version=$("$tools_dir/swiftlint" version)
if [[ $actual_version != "$SWIFTLINT_VERSION" ]]; then
  printf 'error: expected SwiftLint %s, got %s\n' \
    "$SWIFTLINT_VERSION" "$actual_version" >&2
  exit 1
fi

printf '%s\n' "$tools_dir"
