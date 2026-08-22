#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
  printf 'usage: %s RELEASE_TAG VERSION\n' "$0" >&2
  exit 64
fi
: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

release_tag=$1
version=$2
if [[ ! $version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  printf 'error: version is not a release Semantic Version: %s\n' "$version" >&2
  exit 1
fi
if [[ $release_tag != "v$version" ]]; then
  printf 'error: release tag %s does not match version %s\n' "$release_tag" "$version" >&2
  exit 1
fi

expected_assets=$(
  printf '%s\n' \
    "T1-Plus-Touchpad-Support-for-macOS-$version.dmg" \
    "T1-Plus-Touchpad-Support-for-macOS-$version.dmg.sha256" \
    appcast.xml |
    sort
)
actual_assets=$(
  gh release view "$release_tag" \
    --repo "$GITHUB_REPOSITORY" \
    --json assets \
    --jq '.assets[].name' |
    sort
)
if [[ $actual_assets != "$expected_assets" ]]; then
  printf 'error: release %s has an unexpected asset set\n' "$release_tag" >&2
  diff -u \
    <(printf '%s\n' "$expected_assets") \
    <(printf '%s\n' "$actual_assets") >&2 || true
  exit 1
fi
