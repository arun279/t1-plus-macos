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
helper_executable="$app_path/Contents/MacOS/T1PlusHelper"
agent_plist="$app_path/Contents/Library/LaunchAgents/io.github.arun279.t1plus.helper.plist"
app_executable="$app_path/Contents/MacOS/T1 Plus Touchpad Support for macOS"
icon_assets=App/T1PlusApp/Assets.xcassets/AppIcon.appiconset

[[ $(plutil -extract CFBundleIdentifier raw "$info_plist") == io.github.arun279.t1plus ]]
[[ $(plutil -extract CFBundleShortVersionString raw "$info_plist") == "$(< VERSION)" ]]
[[ $(plutil -extract CFBundleIconName raw "$info_plist") == AppIcon ]]
[[ $(plutil -extract NSInputMonitoringUsageDescription raw "$info_plist") == 'Reads touch reports from a connected T1 Plus to provide touchpad input.' ]]
[[ -x $app_executable ]]
[[ -f $app_path/Contents/Resources/Assets.car ]]
[[ -f $app_path/Contents/Resources/AppIcon.icns ]]
[[ -x $helper_executable ]]
[[ -f $agent_plist ]]
[[ ! -e $app_path/Contents/Library/LoginItems ]]
[[ $(plutil -extract Label raw "$agent_plist") == io.github.arun279.t1plus.helper ]]
[[ $(plutil -extract BundleProgram raw "$agent_plist") == Contents/MacOS/T1PlusHelper ]]
[[ $(plutil -extract KeepAlive.SuccessfulExit raw "$agent_plist") == false ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :MachServices:io.github.arun279.t1plus.helper.status' "$agent_plist") == true ]]
[[ $(plutil -extract RunAtLoad raw "$agent_plist") == true ]]

[[ $(find "$icon_assets" -type f -name '*.png' | wc -l | tr -d ' ') == 10 ]]
icon_names=(
  icon_16x16.png
  icon_16x16@2x.png
  icon_32x32.png
  icon_32x32@2x.png
  icon_128x128.png
  icon_128x128@2x.png
  icon_256x256.png
  icon_256x256@2x.png
  icon_512x512.png
  icon_512x512@2x.png
)
icon_sizes=(16 32 32 64 128 256 256 512 512 1024)
for icon_index in "${!icon_names[@]}"; do
  icon_name=${icon_names[$icon_index]}
  icon="$icon_assets/$icon_name"
  expected_size=${icon_sizes[$icon_index]}
  grep -Fq "\"filename\": \"$icon_name\"" "$icon_assets/Contents.json"
  if [[ $(sips -g pixelWidth "$icon" | awk '/pixelWidth/ { print $2 }') != "$expected_size" ]] ||
    [[ $(sips -g pixelHeight "$icon" | awk '/pixelHeight/ { print $2 }') != "$expected_size" ]] ||
    ! sips -g hasAlpha "$icon" | grep -q 'hasAlpha: no'; then
    printf 'error: app icon rendition has invalid dimensions or opacity: %s\n' "$icon" >&2
    exit 1
  fi
done

while IFS= read -r usage_key; do
  if [[ $usage_key != NSInputMonitoringUsageDescription ]]; then
    printf 'error: app bundle declares permission outside its budget: %s\n' "$usage_key" >&2
    exit 1
  fi
done < <(
  plutil -convert xml1 -o - "$info_plist" |
    sed -n 's:.*<key>\(NS[^<]*UsageDescription\)</key>.*:\1:p'
)

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
  "OBJC_CLASS_\$_NSXPCConnection" \
  "OBJC_CLASS_\$_SMAppService"; do
  if [[ $app_symbols != *$required_symbol* ]]; then
    printf 'error: app does not link required lifecycle API: %s\n' "$required_symbol" >&2
    exit 1
  fi
done

if [[ $undefined_symbols != *"OBJC_CLASS_\$_NSXPCListener"* ]]; then
  printf 'error: helper does not link the required health service API\n' >&2
  exit 1
fi

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
