#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)) || [[ ! $1 =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  printf 'usage: %s vMAJOR.MINOR.PATCH\n' "${0##*/}" >&2
  exit 64
fi

release_tag=$1

tag_exists() {
  local status=0

  git ls-remote --exit-code --tags origin "refs/tags/$release_tag" > /dev/null 2>&1 || status=$?
  case $status in
    0) return 0 ;;
    2) return 1 ;;
    *)
      printf 'error: could not inspect candidate tag: %s\n' "$release_tag" >&2
      exit "$status"
      ;;
  esac
}

candidate_tag_exists=false
if tag_exists; then
  candidate_tag_exists=true
fi

gh release delete "$release_tag" --yes

if [[ $candidate_tag_exists == true ]]; then
  gh api --method DELETE "repos/$GITHUB_REPOSITORY/git/refs/tags/$release_tag"
fi

if gh release view "$release_tag" > /dev/null 2>&1; then
  printf 'error: rejected draft still exists: %s\n' "$release_tag" >&2
  exit 1
fi

if tag_exists; then
  printf 'error: rejected candidate tag still exists: %s\n' "$release_tag" >&2
  exit 1
fi
