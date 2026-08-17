#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
checker="$script_dir/check-dco.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/t1-plus-dco-tests.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

while IFS= read -r variable; do
  unset "$variable"
done < <(git rev-parse --local-env-vars)

make_repository() {
  local name=$1
  local repository="$fixture_root/$name"
  mkdir "$repository"
  git -C "$repository" init -q
  git -C "$repository" config user.name 'Test Contributor'
  git -C "$repository" config user.email 'contributor@example.com'
  git -C "$repository" config commit.gpgsign false
  git -C "$repository" config core.hooksPath /dev/null
  git -C "$repository" commit -q --allow-empty -m 'Baseline'
  printf '%s\n' "$repository"
}

repository=$(make_repository author-signoff)
base=$(git -C "$repository" rev-parse HEAD)
git -C "$repository" commit -q --allow-empty \
  -m 'Signed contribution' \
  -m 'Signed-off-by: Test Contributor <contributor@example.com>'
(cd "$repository" && "$checker" "$base" HEAD)

git -C "$repository" commit -q --allow-empty -m 'Unsigned contribution'
if (cd "$repository" && "$checker" "$base" HEAD) > /dev/null 2>&1; then
  printf 'error: DCO check accepted an unsigned commit\n' >&2
  exit 1
fi

repository=$(make_repository dependabot-signoff)
base=$(git -C "$repository" rev-parse HEAD)
git -C "$repository" commit -q --allow-empty \
  --author='dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>' \
  -m 'Update dependency' \
  -m 'Signed-off-by: dependabot[bot] <support@github.com>'
(cd "$repository" && "$checker" "$base" HEAD)

repository=$(make_repository arbitrary-bot)
base=$(git -C "$repository" rev-parse HEAD)
git -C "$repository" commit -q --allow-empty \
  --author='other[bot] <other@example.com>' \
  -m 'Bot contribution' \
  -m 'Signed-off-by: dependabot[bot] <support@github.com>'
if (cd "$repository" && "$checker" "$base" HEAD) > /dev/null 2>&1; then
  printf 'error: DCO check accepted a different bot identity\n' >&2
  exit 1
fi

if [[ ${T1_DCO_ISOLATION_PROBE:-} != 1 ]]; then
  parent="$fixture_root/hook-parent"
  mkdir "$parent"
  git -C "$parent" init -q
  git -C "$parent" config user.name 'Parent Contributor'
  git -C "$parent" config user.email 'parent@example.com'
  git -C "$parent" config commit.gpgsign false
  git -C "$parent" commit -q --allow-empty -m 'Parent baseline'
  parent_head=$(git --git-dir="$parent/.git" rev-parse HEAD)
  parent_config=$(git --git-dir="$parent/.git" config --local --null --list | shasum -a 256)

  GIT_DIR="$parent/.git" \
    GIT_WORK_TREE="$parent" \
    T1_DCO_ISOLATION_PROBE=1 \
    "$script_dir/test-dco.sh" > /dev/null

  [[ $(git --git-dir="$parent/.git" rev-parse HEAD) == "$parent_head" ]]
  [[ $(git --git-dir="$parent/.git" config --local --null --list | shasum -a 256) == "$parent_config" ]]
fi

printf 'DCO fixtures passed.\n'
