#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

scripts/test-workspace-health.sh
swift test --package-path Packages/T1Core --parallel
scripts/test-dco.sh
scripts/test-codeql-relevance.sh
scripts/test-release-metadata.sh
scripts/test-appcast.sh
