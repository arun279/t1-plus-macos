#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

scripts/check-workspace-health.sh
scripts/lint.sh
scripts/test.sh
scripts/deadcode.sh
scripts/build.sh Release
scripts/test-app-package.sh
gitleaks git --redact --no-banner .
