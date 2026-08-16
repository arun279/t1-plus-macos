#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

if (($# != 1)); then
  printf 'usage: %s DMG_PATH\n' "$0" >&2
  exit 64
fi

dmg_path=$1
if [[ ! -f $dmg_path || $dmg_path != *.dmg ]]; then
  printf 'error: disk image not found: %s\n' "$dmg_path" >&2
  exit 1
fi

mount_point=$(mktemp -d "${TMPDIR:-/tmp}/t1-plus-mount.XXXXXX")
attached=false
cleanup() {
  if [[ $attached == true ]]; then
    hdiutil detach -quiet "$mount_point"
  fi
  rmdir "$mount_point"
}
trap cleanup EXIT

hdiutil attach -quiet -readonly -nobrowse -mountpoint "$mount_point" "$dmg_path"
attached=true
app_path="$mount_point/T1 Plus Touchpad Support for macOS.app"
[[ -d $app_path ]]
[[ -L $mount_point/Applications ]]
[[ $(readlink "$mount_point/Applications") == /Applications ]]
cmp -s LICENSE "$mount_point/LICENSE.txt"
scripts/test-app-package.sh "$mount_point"
