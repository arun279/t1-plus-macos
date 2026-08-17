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

xcrun stapler validate "$dmg_path"
codesign --verify --strict --verbose=2 "$dmg_path"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"
scripts/test-dmg-package.sh "$dmg_path"

dmg_signature=$(codesign --display --verbose=4 "$dmg_path" 2>&1)
grep -q '^Identifier=io.github.arun279.t1plus.disk-image$' <<< "$dmg_signature"
grep -q '^Authority=Developer ID Application:' <<< "$dmg_signature"
grep -q '^Timestamp=' <<< "$dmg_signature"
grep -Eq '^TeamIdentifier=[A-Z0-9]+$' <<< "$dmg_signature"

mount_point=$(mktemp -d "${TMPDIR:-/tmp}/t1-plus-signed-mount.XXXXXX")
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
helper_path="$app_path/Contents/Library/LoginItems/T1PlusHelper.app"
codesign --verify --strict --verbose=2 "$helper_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

app_signature=$(codesign --display --verbose=4 "$app_path" 2>&1)
helper_signature=$(codesign --display --verbose=4 "$helper_path" 2>&1)
grep -q '^Identifier=io.github.arun279.t1plus$' <<< "$app_signature"
grep -q '^Identifier=io.github.arun279.t1plus.helper$' <<< "$helper_signature"
for signed_path in "$app_path" "$helper_path"; do
  if codesign --display --entitlements - "$signed_path" 2>&1 | grep -q '<key>'; then
    printf 'error: release code has an undeclared entitlement: %s\n' "$signed_path" >&2
    exit 1
  fi
done
for signature in "$app_signature" "$helper_signature"; do
  grep -q '^Authority=Developer ID Application:' <<< "$signature"
  grep -q '^Timestamp=' <<< "$signature"
  grep -q '^flags=.*runtime' <<< "$signature"
  grep -Eq '^TeamIdentifier=[A-Z0-9]+$' <<< "$signature"
done
app_team=$(sed -n 's/^TeamIdentifier=//p' <<< "$app_signature")
helper_team=$(sed -n 's/^TeamIdentifier=//p' <<< "$helper_signature")
dmg_team=$(sed -n 's/^TeamIdentifier=//p' <<< "$dmg_signature")
[[ $app_team == "$helper_team" && $app_team == "$dmg_team" ]]

spctl --assess --type execute --verbose=2 "$app_path"
hdiutil detach -quiet "$mount_point"
attached=false
rmdir "$mount_point"
trap - EXIT
