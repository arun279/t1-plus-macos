#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
checker="$script_dir/check-workspace-health.sh"
minimum_free_kib=$((15 * 1024 * 1024))
maximum_temporary_build_kib=$((4 * 1024 * 1024))

output=$(
  T1PLUS_WORKSPACE_AVAILABLE_KIB=$minimum_free_kib \
    T1PLUS_WORKSPACE_WORKTREE_COUNT=3 \
    T1PLUS_WORKSPACE_TEMPORARY_BUILD_KIB=$maximum_temporary_build_kib \
    "$checker"
)
[[ $output == 'Workspace health passed:'* ]]

expect_failure() {
  local expected=$1
  shift
  local output

  if output=$("$@" 2>&1); then
    printf 'error: workspace health fixture unexpectedly passed\n' >&2
    exit 1
  fi

  if [[ $output != *"$expected"* ]]; then
    printf 'error: workspace health fixture did not report %q\n%s\n' "$expected" "$output" >&2
    exit 1
  fi
}

expect_failure 'requires at least 15 GiB free' \
  env \
  T1PLUS_WORKSPACE_AVAILABLE_KIB=$((minimum_free_kib - 1)) \
  T1PLUS_WORKSPACE_WORKTREE_COUNT=3 \
  T1PLUS_WORKSPACE_TEMPORARY_BUILD_KIB=$maximum_temporary_build_kib \
  "$checker"

expect_failure 'at most 3 registered worktrees' \
  env \
  T1PLUS_WORKSPACE_AVAILABLE_KIB=$minimum_free_kib \
  T1PLUS_WORKSPACE_WORKTREE_COUNT=4 \
  T1PLUS_WORKSPACE_TEMPORARY_BUILD_KIB=$maximum_temporary_build_kib \
  "$checker"

expect_failure 'must not exceed 4 GiB' \
  env \
  T1PLUS_WORKSPACE_AVAILABLE_KIB=$minimum_free_kib \
  T1PLUS_WORKSPACE_WORKTREE_COUNT=3 \
  T1PLUS_WORKSPACE_TEMPORARY_BUILD_KIB=$((maximum_temporary_build_kib + 1)) \
  "$checker"

printf 'Workspace health fixtures passed.\n'
