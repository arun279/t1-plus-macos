#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

if (($# != 3)); then
  printf 'usage: %s VERSION DMG_PATH APPCAST_PATH\n' "$0" >&2
  exit 64
fi
: "${SPARKLE_DOWNLOAD_URL_PREFIX:?SPARKLE_DOWNLOAD_URL_PREFIX is required}"

version=$1
dmg_path=$2
appcast_path=$3
generate_appcast=${SPARKLE_GENERATE_APPCAST:-.build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast}

[[ $version == "$(< VERSION)" ]]
[[ -f $dmg_path && $dmg_path == *.dmg ]]
[[ ! -e $appcast_path ]]
[[ -x $generate_appcast ]]

staging_directory=$(mktemp -d "${TMPDIR:-/tmp}/t1-plus-appcast.XXXXXX")
cleanup() {
  rm -rf "$staging_directory"
}
trap cleanup EXIT

archive_name=$(basename "$dmg_path")
cp "$dmg_path" "$staging_directory/$archive_name"
scripts/release-notes.sh "$version" > "$staging_directory/${archive_name%.dmg}.md"

"$generate_appcast" \
  --ed-key-file - \
  --download-url-prefix "${SPARKLE_DOWNLOAD_URL_PREFIX%/}/" \
  --embed-release-notes \
  --maximum-deltas 0 \
  -o "$appcast_path" \
  "$staging_directory"

[[ -s $appcast_path ]]
