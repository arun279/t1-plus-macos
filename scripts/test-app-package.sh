#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

search_root=${1:-.build/DerivedData/Build/Products/Release}
app_path=$(find "$search_root" -type d -name 'T1 Plus Touchpad Support for macOS.app' -print -quit)
if [[ -z $app_path ]]; then
  printf 'error: app bundle not found under %s\n' "$search_root" >&2
  exit 1
fi

info_plist="$app_path/Contents/Info.plist"
helper_path="$app_path/Contents/Library/LoginItems/T1PlusHelper.app"

[[ $(plutil -extract CFBundleIdentifier raw "$info_plist") == io.github.arun279.t1plus ]]
[[ $(plutil -extract CFBundleShortVersionString raw "$info_plist") == "$(<VERSION)" ]]
[[ -x "$app_path/Contents/MacOS/T1 Plus Touchpad Support for macOS" ]]
[[ -d $helper_path ]]
[[ $(plutil -extract CFBundleIdentifier raw "$helper_path/Contents/Info.plist") == io.github.arun279.t1plus.helper ]]
[[ -x "$helper_path/Contents/MacOS/T1PlusHelper" ]]

printf 'Verified app identity and embedded helper: %s\n' "$app_path"
