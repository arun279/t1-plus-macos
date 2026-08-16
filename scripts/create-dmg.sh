#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

if (($# != 3)); then
  printf 'usage: %s APP_PATH VERSION OUTPUT_DMG\n' "$0" >&2
  exit 64
fi

app_path=$1
version=$2
output_path=$3
if [[ ! -d $app_path || $app_path != *.app ]]; then
  printf 'error: app bundle not found: %s\n' "$app_path" >&2
  exit 1
fi
if [[ $output_path != *.dmg || -e $output_path ]]; then
  printf 'error: output must be a new .dmg path: %s\n' "$output_path" >&2
  exit 1
fi

staging=$(mktemp -d "${TMPDIR:-/tmp}/t1-plus-dmg.XXXXXX")
cleanup() {
  rm -rf "$staging"
}
trap cleanup EXIT

ditto "$app_path" "$staging/$(basename "$app_path")"
ln -s /Applications "$staging/Applications"
cp LICENSE "$staging/LICENSE.txt"
mkdir -p "$(dirname "$output_path")"
hdiutil create \
  -quiet \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -volname "T1 Plus Touchpad $version" \
  -srcfolder "$staging" \
  "$output_path"
