#!/usr/bin/env bash
set -euo pipefail

if [[ ${CI:-} != true || ${RUNNER_OS:-} != Linux ]]; then
  printf 'error: this script is restricted to an ephemeral Linux CI runner\n' >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

# shellcheck source=../Tools/versions.env
source Tools/versions.env

tools_dir=$root/.build/ci-tools
mkdir -p "$tools_dir"

download() {
  local url=$1
  local sha256=$2
  local destination=$3

  curl --fail --location --silent --show-error "$url" --output "$destination"
  printf '%s  %s\n' "$sha256" "$destination" | sha256sum --check --status
}

download \
  "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz" \
  8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8 \
  "$tools_dir/actionlint.tar.gz"
tar -xzf "$tools_dir/actionlint.tar.gz" -C "$tools_dir" actionlint

download \
  "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb \
  "$tools_dir/gitleaks.tar.gz"
tar -xzf "$tools_dir/gitleaks.tar.gz" -C "$tools_dir" gitleaks

download \
  "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.gz" \
  b7af85e41cc99489dcc21d66c6d5f3685138f06d34651e6d34b42ec6d54fe6f6 \
  "$tools_dir/shellcheck.tar.gz"
tar -xzf "$tools_dir/shellcheck.tar.gz" \
  -C "$tools_dir" \
  --strip-components=1 \
  "shellcheck-v${SHELLCHECK_VERSION}/shellcheck"

download \
  "https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64" \
  fb096c5d1ac6beabbdbaa2874d025badb03ee07929f0c9ff67563ce8c75398b1 \
  "$tools_dir/shfmt"

chmod +x "$tools_dir/actionlint" "$tools_dir/gitleaks" "$tools_dir/shellcheck" "$tools_dir/shfmt"
printf '%s\n' "$tools_dir"
