#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

if (($# != 1)); then
  printf 'usage: %s VERSION\n' "$0" >&2
  exit 64
fi

version=$1
awk -v prefix="## [$version] - " '
  index($0, prefix) == 1 { found = 1; next }
  found && /^## / { exit }
  found { print }
  END { if (!found) exit 1 }
' CHANGELOG.md
