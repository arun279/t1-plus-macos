#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

# shellcheck source=Tools/versions.env
source Tools/versions.env

require_version() {
  local label=$1
  local expected=$2
  shift 2

  local output
  if ! output=$("$@" 2>&1); then
    printf 'error: %s is unavailable; no software was installed\n' "$label" >&2
    return 1
  fi
  if [[ $output != *"$expected"* ]]; then
    printf 'error: %s must contain version %s, got:\n%s\n' "$label" "$expected" "$output" >&2
    return 1
  fi
}

require_version "Xcode" "$XCODE_VERSION" xcodebuild -version
require_version "swift format" "$SWIFT_FORMAT_VERSION" swift format --version
require_version "SwiftLint" "$SWIFTLINT_VERSION" swiftlint version
require_version "ShellCheck" "$SHELLCHECK_VERSION" shellcheck --version
require_version "shfmt" "$SHFMT_VERSION" shfmt --version
require_version "actionlint" "$ACTIONLINT_VERSION" actionlint -version
require_version "Gitleaks" "$GITLEAKS_VERSION" gitleaks version
require_version "zizmor" "$ZIZMOR_VERSION" zizmor --version

git config core.hooksPath .githooks
printf 'Verified tools and configured core.hooksPath=.githooks for this clone.\n'
