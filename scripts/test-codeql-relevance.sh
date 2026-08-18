#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
checker="$script_dir/codeql-relevance.sh"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/t1-plus-codeql-relevance-tests.XXXXXX")
trap 'rm -rf "$fixture"' EXIT

while IFS= read -r variable; do
  unset "$variable"
done < <(git rev-parse --local-env-vars)

git -C "$fixture" init -q
git -C "$fixture" config user.name 'Test Contributor'
git -C "$fixture" config user.email 'contributor@example.com'
git -C "$fixture" config commit.gpgsign false
git -C "$fixture" config core.hooksPath /dev/null

commit_file() {
  local path=$1
  local content=$2
  mkdir -p "$fixture/$(dirname "$path")"
  printf '%s\n' "$content" > "$fixture/$path"
  git -C "$fixture" add -- "$path"
  git -C "$fixture" commit -q -m "Change $path"
}

assert_result() {
  local expected=$1
  local base=$2
  local head=$3
  local label=$4
  local actual
  actual=$(cd "$fixture" && "$checker" "$base" "$head")
  if [[ $actual != "$expected" ]]; then
    printf 'error: %s: expected %s, got %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

git -C "$fixture" commit -q --allow-empty -m 'Baseline'
baseline=$(git -C "$fixture" rev-parse HEAD)
assert_result false "$baseline" "$baseline" 'unchanged commit'

commit_file docs/guide.md 'documentation'
docs=$(git -C "$fixture" rev-parse HEAD)
assert_result false "$baseline" "$docs" 'documentation only'

commit_file App/T1PlusAppUITests/Flow.swift 'test code'
ui_test=$(git -C "$fixture" rev-parse HEAD)
assert_result false "$docs" "$ui_test" 'UI test only'

commit_file App/T1PlusApp/Runtime.swift 'production code'
source=$(git -C "$fixture" rev-parse HEAD)
assert_result true "$ui_test" "$source" 'production source'

commit_file Packages/T1Core/Package.swift 'package manifest'
manifest=$(git -C "$fixture" rev-parse HEAD)
assert_result true "$source" "$manifest" 'package manifest'

commit_file .github/workflows/codeql.yml 'analyzer workflow'
workflow=$(git -C "$fixture" rev-parse HEAD)
assert_result true "$manifest" "$workflow" 'CodeQL workflow'

commit_file scripts/codeql-relevance.sh 'scope classifier'
classifier=$(git -C "$fixture" rev-parse HEAD)
assert_result true "$workflow" "$classifier" 'CodeQL scope classifier'

git -C "$fixture" rm -q App/T1PlusApp/Runtime.swift
git -C "$fixture" commit -q -m 'Delete production source'
deleted=$(git -C "$fixture" rev-parse HEAD)
assert_result true "$classifier" "$deleted" 'deleted production source'

commit_file Helper/T1PlusHelper/Legacy.swift 'legacy source'
before_rename=$(git -C "$fixture" rev-parse HEAD)
mkdir -p "$fixture/docs"
git -C "$fixture" mv Helper/T1PlusHelper/Legacy.swift docs/legacy.md
git -C "$fixture" commit -q -m 'Move production source to documentation'
renamed=$(git -C "$fixture" rev-parse HEAD)
assert_result true "$before_rename" "$renamed" 'renamed production source'

assert_result true invalid "$renamed" 'invalid base commit'
printf 'CodeQL relevance fixtures passed.\n'
