#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

if (($# != 3)); then
  printf 'usage: %s VERSION DMG_PATH APPCAST_PATH\n' "$0" >&2
  exit 64
fi

version=$1
dmg_path=$2
appcast_path=$3
[[ $version == "$(< VERSION)" ]]
[[ -f $dmg_path && -s $appcast_path ]]

build_version=$(
  sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION = \([^;]*\);/\1/p' \
    T1Plus.xcodeproj/project.pbxproj | sort -u
)
archive_name=$(basename "$dmg_path")
download_url="https://github.com/arun279/t1-plus-macos/releases/download/v$version/$archive_name"

python3 -c \
  'import sys, xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' \
  "$appcast_path"
grep -Fq "<sparkle:version>$build_version</sparkle:version>" "$appcast_path"
grep -Fq "<sparkle:shortVersionString>$version</sparkle:shortVersionString>" "$appcast_path"
grep -Fq "url=\"$download_url\"" "$appcast_path"
grep -Eq 'sparkle:edSignature="[A-Za-z0-9+/]{86}=="' "$appcast_path"
grep -Fq '<!-- sparkle-signatures:' "$appcast_path"
grep -Eq '^edSignature: [A-Za-z0-9+/]{86}==$' "$appcast_path"
grep -Eq '^length: [1-9][0-9]*$' "$appcast_path"
