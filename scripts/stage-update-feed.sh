#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

if [[ $# != 2 ]]; then
  printf 'usage: %s <appcast> <output-directory>\n' "$0" >&2
  exit 64
fi

appcast_path=$1
output_directory=$2

if [[ ! -s $appcast_path ]]; then
  printf 'error: appcast is missing or empty: %s\n' "$appcast_path" >&2
  exit 1
fi
if [[ -e $output_directory ]]; then
  printf 'error: output directory already exists: %s\n' "$output_directory" >&2
  exit 1
fi

mkdir -p "$output_directory"
install -m 0644 updates/index.html "$output_directory/index.html"
install -m 0644 "$appcast_path" "$output_directory/appcast.xml"
