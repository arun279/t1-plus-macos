#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
  printf 'usage: %s BASE_COMMIT HEAD_COMMIT\n' "$0" >&2
  exit 64
fi

base=$1
head=$2

if [[ ! $base =~ ^[0-9a-f]{40}$ ]] ||
  [[ ! $head =~ ^[0-9a-f]{40}$ ]] ||
  ! git cat-file -e "$base^{commit}" 2> /dev/null ||
  ! git cat-file -e "$head^{commit}" 2> /dev/null; then
  printf 'true\n'
  exit
fi

changes=$(mktemp "${TMPDIR:-/tmp}/t1-plus-codeql-relevance.XXXXXX")
trap 'rm -f "$changes"' EXIT
if ! git diff --name-status -z --find-renames "$base...$head" > "$changes"; then
  printf 'true\n'
  exit
fi

is_relevant() {
  case $1 in
    App/T1PlusAppUITests/* | Packages/T1Core/Tests/*)
      return 1
      ;;
    .github/workflows/codeql.yml | \
      .github/codeql/* | \
      .github/codeql.yml | \
      .github/codeql.yaml | \
      .xcode-version | \
      App/T1PlusApp/* | \
      Helper/T1PlusHelper/* | \
      Packages/T1Core/Sources/* | \
      T1Plus.xcodeproj/* | \
      T1Plus.xcworkspace/* | \
      Package.swift | \
      Package.resolved | \
      scripts/codeql-relevance.sh | \
      */Package.swift | \
      */Package.resolved | \
      *.c | *.cc | *.cpp | *.cxx | \
      *.entitlements | *.h | *.hpp | \
      *.m | *.mm | *.modulemap | *.swift | *.xcconfig)
      return 0
      ;;
  esac
  return 1
}

while IFS= read -r -d '' status; do
  case $status in
    R* | C*)
      IFS= read -r -d '' old_path
      IFS= read -r -d '' new_path
      if is_relevant "$old_path" || is_relevant "$new_path"; then
        printf 'true\n'
        exit
      fi
      ;;
    *)
      IFS= read -r -d '' path
      if is_relevant "$path"; then
        printf 'true\n'
        exit
      fi
      ;;
  esac
done < "$changes"

printf 'false\n'
