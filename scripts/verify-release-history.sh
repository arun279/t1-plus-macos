#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  printf 'usage: %s VERSION\n' "$0" >&2
  exit 64
fi
: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

version=$1
if [[ ! $version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  printf 'error: version is not a release Semantic Version: %s\n' "$version" >&2
  exit 1
fi
major=${BASH_REMATCH[1]}
minor=${BASH_REMATCH[2]}
patch=${BASH_REMATCH[3]}

is_newer_than() {
  local previous_major=$1
  local previous_minor=$2
  local previous_patch=$3

  ((major > previous_major)) && return 0
  ((major < previous_major)) && return 1
  ((minor > previous_minor)) && return 0
  ((minor < previous_minor)) && return 1
  ((patch > previous_patch))
}

while IFS= read -r tag; do
  if [[ ! $tag =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    continue
  fi
  prior_major=${BASH_REMATCH[1]}
  prior_minor=${BASH_REMATCH[2]}
  prior_patch=${BASH_REMATCH[3]}
  if ! is_newer_than "$prior_major" "$prior_minor" "$prior_patch"; then
    printf 'error: version %s is not newer than published release %s\n' "$version" "$tag" >&2
    exit 1
  fi
done < <(gh api --paginate "repos/$GITHUB_REPOSITORY/releases" --jq '.[].tag_name')
