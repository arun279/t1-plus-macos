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
helper_executable="$helper_path/Contents/MacOS/T1PlusHelper"

[[ $(plutil -extract CFBundleIdentifier raw "$info_plist") == io.github.arun279.t1plus ]]
[[ $(plutil -extract CFBundleShortVersionString raw "$info_plist") == "$(< VERSION)" ]]
[[ -x "$app_path/Contents/MacOS/T1 Plus Touchpad Support for macOS" ]]
[[ -d $helper_path ]]
[[ $(plutil -extract CFBundleIdentifier raw "$helper_path/Contents/Info.plist") == io.github.arun279.t1plus.helper ]]
[[ $(plutil -extract LSBackgroundOnly raw "$helper_path/Contents/Info.plist") == true ]]
[[ -x $helper_executable ]]

app_architectures=$(lipo -archs "$app_path/Contents/MacOS/T1 Plus Touchpad Support for macOS")
helper_architectures=$(lipo -archs "$helper_executable")
for architectures in "$app_architectures" "$helper_architectures"; do
  [[ " $architectures " == *" arm64 "* ]]
  [[ " $architectures " == *" x86_64 "* ]]
done

undefined_symbols=$(nm -u "$helper_executable")
if [[ $undefined_symbols == *IOHIDDeviceSetReport* ||
  $undefined_symbols == *IOHIDDeviceSetValue* ||
  $undefined_symbols == *IOHIDTransactionCommit* ]]; then
  printf 'error: embedded helper links a forbidden HID write API\n' >&2
  exit 1
fi

printf 'Verified app identity and embedded helper: %s\n' "$app_path"
