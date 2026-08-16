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
app_executable="$app_path/Contents/MacOS/T1 Plus Touchpad Support for macOS"

[[ $(plutil -extract CFBundleIdentifier raw "$info_plist") == io.github.arun279.t1plus ]]
[[ $(plutil -extract CFBundleShortVersionString raw "$info_plist") == "$(< VERSION)" ]]
[[ $(plutil -extract NSInputMonitoringUsageDescription raw "$info_plist") == 'Reads touch reports from a connected T1 Plus to provide touchpad input.' ]]
[[ -x $app_executable ]]
[[ -d $helper_path ]]
[[ $(plutil -extract CFBundleIdentifier raw "$helper_path/Contents/Info.plist") == io.github.arun279.t1plus.helper ]]
[[ $(plutil -extract LSBackgroundOnly raw "$helper_path/Contents/Info.plist") == true ]]
[[ $(plutil -extract LSApplicationCategoryType raw "$helper_path/Contents/Info.plist") == public.app-category.utilities ]]
[[ $(plutil -extract NSInputMonitoringUsageDescription raw "$helper_path/Contents/Info.plist") == 'Reads touch reports from a connected T1 Plus to provide touchpad input.' ]]
[[ -x $helper_executable ]]

for plist in "$info_plist" "$helper_path/Contents/Info.plist"; do
  for forbidden_key in \
    NSAppleEventsUsageDescription \
    NSBluetoothAlwaysUsageDescription \
    NSBluetoothPeripheralUsageDescription \
    NSScreenCaptureUsageDescription \
    NSSystemAdministrationUsageDescription; do
    if plutil -extract "$forbidden_key" raw "$plist" > /dev/null 2>&1; then
      printf 'error: app bundle declares forbidden permission key: %s\n' "$forbidden_key" >&2
      exit 1
    fi
  done
done

app_architectures=$(lipo -archs "$app_executable")
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

app_symbols=$(nm -u "$app_executable")
for required_symbol in \
  _CGPreflightPostEventAccess \
  _CGRequestPostEventAccess \
  _IOHIDCheckAccess \
  _IOHIDRequestAccess \
  "OBJC_CLASS_\$_SMAppService"; do
  if [[ $app_symbols != *$required_symbol* ]]; then
    printf 'error: app does not link required lifecycle API: %s\n' "$required_symbol" >&2
    exit 1
  fi
done

combined_symbols="$app_symbols
$undefined_symbols"
for forbidden_symbol in \
  _AEDeterminePermissionToAutomateTarget \
  _CGPreflightScreenCaptureAccess \
  _CGRequestScreenCaptureAccess; do
  if [[ $combined_symbols == *$forbidden_symbol* ]]; then
    printf 'error: app bundle links forbidden permission API: %s\n' "$forbidden_symbol" >&2
    exit 1
  fi
done

printf 'Verified app identity and embedded helper: %s\n' "$app_path"
