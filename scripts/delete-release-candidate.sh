#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)) || [[ ! $1 =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  printf 'usage: %s vMAJOR.MINOR.PATCH\n' "${0##*/}" >&2
  exit 64
fi

release_tag=$1

gh release delete "$release_tag" --yes

if git ls-remote --exit-code --tags origin "refs/tags/$release_tag" > /dev/null 2>&1; then
  gh api --method DELETE "repos/$GITHUB_REPOSITORY/git/refs/tags/$release_tag"
fi

if gh release view "$release_tag" > /dev/null 2>&1; then
  printf 'error: rejected draft still exists: %s\n' "$release_tag" >&2
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$release_tag" > /dev/null 2>&1; then
  printf 'error: rejected candidate tag still exists: %s\n' "$release_tag" >&2
  exit 1
fi
