#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
  printf 'usage: %s BASE_COMMIT HEAD_COMMIT\n' "$0" >&2
  exit 64
fi

base=$1
head=$2
dependabot_author='dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>'
dependabot_signoff='Signed-off-by: dependabot[bot] <support@github.com>'
count=0
failed=false
while IFS= read -r commit; do
  ((count += 1))
  author=$(git show -s --format='%an <%ae>' "$commit")
  message=$(git show -s --format=%B "$commit")
  if printf '%s\n' "$message" | grep -Fqx "Signed-off-by: $author"; then
    continue
  fi
  if [[ $author == "$dependabot_author" ]] &&
    printf '%s\n' "$message" | grep -Fqx "$dependabot_signoff"; then
    continue
  fi
  printf 'error: commit %s lacks the author DCO sign-off: %s\n' "$commit" "$author" >&2
  failed=true
done < <(git rev-list --reverse --no-merges "$base..$head")

if ((count == 0)); then
  printf 'error: no non-merge commits found in %s..%s\n' "$base" "$head" >&2
  exit 1
fi
[[ $failed == false ]]
