#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
minimum_free_kib=$((15 * 1024 * 1024))
maximum_worktrees=3
maximum_temporary_build_kib=$((4 * 1024 * 1024))

available_kib=${T1PLUS_WORKSPACE_AVAILABLE_KIB:-}
if [[ -z $available_kib ]]; then
  available_kib=$(df -Pk "$root" | awk 'NR == 2 { print $4 }')
fi

worktree_count=${T1PLUS_WORKSPACE_WORKTREE_COUNT:-}
if [[ -z $worktree_count ]]; then
  worktree_count=$(git worktree list --porcelain | awk '$1 == "worktree" { count++ } END { print count + 0 }')
fi

temporary_build_kib=${T1PLUS_WORKSPACE_TEMPORARY_BUILD_KIB:-}
if [[ -z $temporary_build_kib ]]; then
  temporary_build_kib=0
  shopt -s nullglob
  for build_directory in /private/tmp/t1-plus-*/.build; do
    build_kib=$(du -sk "$build_directory" | awk '{ print $1 }')
    temporary_build_kib=$((temporary_build_kib + build_kib))
  done
  shopt -u nullglob
fi

failed=false
if ((available_kib < minimum_free_kib)); then
  printf 'error: workspace requires at least 15 GiB free before the full gate; found %.1f GiB\n' \
    "$(awk -v kib="$available_kib" 'BEGIN { print kib / 1024 / 1024 }')" >&2
  failed=true
fi

if ((worktree_count > maximum_worktrees)); then
  printf 'error: workspace permits at most %d registered worktrees; found %d\n' \
    "$maximum_worktrees" "$worktree_count" >&2
  failed=true
fi

if ((temporary_build_kib > maximum_temporary_build_kib)); then
  printf 'error: temporary project build output must not exceed 4 GiB; found %.1f GiB\n' \
    "$(awk -v kib="$temporary_build_kib" 'BEGIN { print kib / 1024 / 1024 }')" >&2
  failed=true
fi

if [[ $failed == true ]]; then
  exit 1
fi

printf 'Workspace health passed: %.1f GiB free, %d worktrees, %.1f GiB temporary build output.\n' \
  "$(awk -v kib="$available_kib" 'BEGIN { print kib / 1024 / 1024 }')" \
  "$worktree_count" \
  "$(awk -v kib="$temporary_build_kib" 'BEGIN { print kib / 1024 / 1024 }')"
