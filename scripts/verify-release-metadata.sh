#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

if (($# != 1)); then
  printf 'usage: %s VERSION\n' "$0" >&2
  exit 64
fi

requested_version=$1
version=$(< VERSION)
if [[ ! $version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  printf 'error: VERSION is not a release Semantic Version: %s\n' "$version" >&2
  exit 1
fi
if [[ $requested_version != "$version" ]]; then
  printf 'error: requested version %s does not match VERSION %s\n' \
    "$requested_version" "$version" >&2
  exit 1
fi

project_versions=$(
  sed -n 's/^[[:space:]]*MARKETING_VERSION = \([^;]*\);/\1/p' \
    T1Plus.xcodeproj/project.pbxproj | sort -u | paste -sd ' ' -
)
if [[ $project_versions != "$version" ]]; then
  printf 'error: Xcode MARKETING_VERSION does not match VERSION %s\n' "$version" >&2
  exit 1
fi

project_builds=$(
  sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION = \([^;]*\);/\1/p' \
    T1Plus.xcodeproj/project.pbxproj | sort -u | paste -sd ' ' -
)
if [[ ! $project_builds =~ ^[1-9][0-9]*$ ]]; then
  printf 'error: Xcode CURRENT_PROJECT_VERSION must be one shared positive integer\n' >&2
  exit 1
fi

escaped_version=${version//./\\.}
if ! grep -Eq "^## \\[$escaped_version\\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md; then
  printf 'error: CHANGELOG.md lacks a dated section for %s\n' "$version" >&2
  exit 1
fi

printf '%s\n' "$version"
