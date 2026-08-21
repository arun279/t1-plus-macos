#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

if (($# != 2)); then
  printf 'usage: %s ARCHIVE_PATH EXPORT_PATH\n' "$0" >&2
  exit 64
fi
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
: "${CODESIGN_IDENTITY:?CODESIGN_IDENTITY is required}"
if [[ ! $APPLE_TEAM_ID =~ ^[A-Z0-9]{10}$ ]]; then
  printf 'error: APPLE_TEAM_ID must be a 10-character Apple team identifier\n' >&2
  exit 1
fi
if [[ $CODESIGN_IDENTITY != 'Developer ID Application: '* ]]; then
  printf 'error: CODESIGN_IDENTITY is not a Developer ID Application identity\n' >&2
  exit 1
fi

archive_path=$1
export_path=$2
if [[ -e $archive_path || -e $export_path ]]; then
  printf 'error: archive and export destinations must not already exist\n' >&2
  exit 1
fi
mkdir -p "$(dirname "$archive_path")" "$(dirname "$export_path")"

xcodebuild \
  -project T1Plus.xcodeproj \
  -scheme T1PlusApp \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" \
  -clonedSourcePackagesDirPath .build/SourcePackages \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$CODESIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$export_path" \
  -exportOptionsPlist Config/ExportOptions.plist
