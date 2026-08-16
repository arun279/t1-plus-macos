#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

if [[ $(uname -s) != Darwin ]]; then
  printf 'error: local tool preparation supports macOS only\n' >&2
  exit 1
fi

# shellcheck source=Tools/versions.env
source Tools/versions.env

case $(uname -m) in
  arm64)
    actionlint_arch=arm64
    actionlint_sha=aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f
    gitleaks_arch=arm64
    gitleaks_sha=b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5
    shellcheck_arch=aarch64
    shellcheck_sha=339b930feb1ea764467013cc1f72d09cd6b869ebf1013296ba9055ab2ffbd26f
    shfmt_arch=arm64
    shfmt_sha=9680526be4a66ea1ffe988ed08af58e1400fe1e4f4aef5bd88b20bb9b3da33f8
    ;;
  x86_64)
    actionlint_arch=amd64
    actionlint_sha=5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644
    gitleaks_arch=x64
    gitleaks_sha=dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709
    shellcheck_arch=x86_64
    shellcheck_sha=c2c15e08df0e8fbc374c335b230a7ee958c313fa5714817a59aa59f1aa594f51
    shfmt_arch=amd64
    shfmt_sha=6feedafc72915794163114f512348e2437d080d0047ef8b8fa2ec63b575f12af
    ;;
  *)
    printf 'error: unsupported macOS architecture: %s\n' "$(uname -m)" >&2
    exit 1
    ;;
esac

staging=$(mktemp -d "${TMPDIR:-/tmp}/t1-plus-local-tools.XXXXXX")
cleanup() {
  rm -rf "$staging"
}
trap cleanup EXIT
mkdir "$staging/bin"

download() {
  local url=$1
  local sha256=$2
  local destination=$3

  curl --fail --location --silent --show-error "$url" --output "$destination"
  printf '%s  %s\n' "$sha256" "$destination" | shasum -a 256 --check --status
}

actionlint_archive="$staging/actionlint.tar.gz"
download \
  "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_darwin_${actionlint_arch}.tar.gz" \
  "$actionlint_sha" \
  "$actionlint_archive"
tar -xzf "$actionlint_archive" -C "$staging/bin" actionlint

gitleaks_archive="$staging/gitleaks.tar.gz"
download \
  "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_darwin_${gitleaks_arch}.tar.gz" \
  "$gitleaks_sha" \
  "$gitleaks_archive"
tar -xzf "$gitleaks_archive" -C "$staging/bin" gitleaks

shellcheck_archive="$staging/shellcheck.tar.gz"
download \
  "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.darwin.${shellcheck_arch}.tar.gz" \
  "$shellcheck_sha" \
  "$shellcheck_archive"
tar -xzf "$shellcheck_archive" -C "$staging"
cp "$staging/shellcheck-v${SHELLCHECK_VERSION}/shellcheck" "$staging/bin/shellcheck"

download \
  "https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_darwin_${shfmt_arch}" \
  "$shfmt_sha" \
  "$staging/bin/shfmt"

swiftlint_archive="$staging/portable_swiftlint.zip"
download \
  "https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/portable_swiftlint.zip" \
  d6cb0aa7a2f5f1ef306fc9e37bcb54dc9a26facc8f7784ac0c3dd3eccf5c6ba6 \
  "$swiftlint_archive"
unzip -q "$swiftlint_archive" swiftlint -d "$staging/bin"
chmod +x "$staging/bin"/*

[[ $("$staging/bin/actionlint" -version) == *"$ACTIONLINT_VERSION"* ]]
[[ $("$staging/bin/gitleaks" version) == *"$GITLEAKS_VERSION"* ]]
[[ $("$staging/bin/shellcheck" --version) == *"version: $SHELLCHECK_VERSION"* ]]
[[ $("$staging/bin/shfmt" --version) == "v$SHFMT_VERSION" ]]
[[ $("$staging/bin/swiftlint" version) == "$SWIFTLINT_VERSION" ]]

tools_dir=$root/.build/local-tools
mkdir -p "$tools_dir"
cp "$staging/bin"/* "$tools_dir/"
printf 'Prepared checksum-verified tools in %s\n' "$tools_dir"
