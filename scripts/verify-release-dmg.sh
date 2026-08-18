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

require_signature_line() {
  local path=$1
  local requirement=$2
  local pattern=$3
  local signature=$4
  if ! grep -Eq "$pattern" <<< "$signature"; then
    printf 'error: %s signature is missing %s\n' "$path" "$requirement" >&2
    printf '%s\n' "$signature" >&2
    exit 1
  fi
}

require_signature_identifier() {
  local path=$1
  local identifier=$2
  local signature=$3
  if ! grep -Fqx "Identifier=$identifier" <<< "$signature"; then
    printf 'error: %s signature is missing the expected identifier\n' "$path" >&2
    printf '%s\n' "$signature" >&2
    exit 1
  fi
}

verify_code_signature_metadata() {
  local path=$1
  local identifier=$2
  local signature=$3
  require_signature_identifier "$path" "$identifier" "$signature"
  require_signature_line "$path" 'a Developer ID Application authority' '^Authority=Developer ID Application:' "$signature"
  require_signature_line "$path" 'a secure timestamp' '^Timestamp=' "$signature"
  require_signature_line "$path" 'the hardened runtime flag' '^CodeDirectory .* flags=.*\(runtime\)' "$signature"
  require_signature_line "$path" 'a valid team identifier' '^TeamIdentifier=[A-Z0-9]+$' "$signature"
}

xcrun stapler validate "$dmg_path"
codesign --verify --strict --verbose=2 "$dmg_path"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"
scripts/test-dmg-package.sh "$dmg_path"

dmg_signature=$(codesign --display --verbose=4 "$dmg_path" 2>&1)
require_signature_identifier "$dmg_path" io.github.arun279.t1plus.disk-image "$dmg_signature"
require_signature_line "$dmg_path" 'a Developer ID Application authority' '^Authority=Developer ID Application:' "$dmg_signature"
require_signature_line "$dmg_path" 'a secure timestamp' '^Timestamp=' "$dmg_signature"
require_signature_line "$dmg_path" 'a valid team identifier' '^TeamIdentifier=[A-Z0-9]+$' "$dmg_signature"

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
for signed_path in "$app_path" "$helper_path"; do
  if codesign --display --entitlements - "$signed_path" 2>&1 | grep -q '<key>'; then
    printf 'error: release code has an undeclared entitlement: %s\n' "$signed_path" >&2
    exit 1
  fi
done
verify_code_signature_metadata "$app_path" io.github.arun279.t1plus "$app_signature"
verify_code_signature_metadata "$helper_path" io.github.arun279.t1plus.helper "$helper_signature"
app_team=$(sed -n 's/^TeamIdentifier=//p' <<< "$app_signature")
helper_team=$(sed -n 's/^TeamIdentifier=//p' <<< "$helper_signature")
dmg_team=$(sed -n 's/^TeamIdentifier=//p' <<< "$dmg_signature")
[[ $app_team == "$helper_team" && $app_team == "$dmg_team" ]]

spctl --assess --type execute --verbose=2 "$app_path"
hdiutil detach -quiet "$mount_point"
attached=false
rmdir "$mount_point"
trap - EXIT
