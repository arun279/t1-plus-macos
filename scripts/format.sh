#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

swift format format \
  --configuration .swift-format \
  --in-place \
  --parallel \
  --recursive \
  App Helper Packages

shfmt -w -i 2 -ci -sr scripts .githooks
