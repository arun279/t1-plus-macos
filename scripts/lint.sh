#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

mode=${1:-all}
if [[ $mode != all && $mode != swift && $mode != portable ]]; then
  printf 'usage: %s [all|swift|portable]\n' "$0" >&2
  exit 64
fi

if [[ $mode == all || $mode == swift ]]; then
  swift format lint \
    --configuration .swift-format \
    --parallel \
    --recursive \
    --strict \
    App Helper Packages
  swiftlint lint --strict --config .swiftlint.yml
fi

if [[ $mode == all || $mode == portable ]]; then
  shellcheck scripts/*.sh .githooks/*
  shfmt -d -i 2 -ci -sr scripts .githooks
  actionlint
fi
