#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 ]]; then
  printf 'usage: %s <expected-appcast> <served-url>\n' "$0" >&2
  exit 64
fi

expected_appcast=$1
served_url=$2
attempts=${UPDATE_FEED_VERIFY_ATTEMPTS:-12}
delay=${UPDATE_FEED_VERIFY_DELAY_SECONDS:-5}
download=$(mktemp "${TMPDIR:-/tmp}/t1-plus-served-appcast.XXXXXX")
trap 'rm -f "$download"' EXIT

for ((attempt = 1; attempt <= attempts; attempt++)); do
  if curl \
    --fail \
    --location \
    --silent \
    --show-error \
    --output "$download" \
    "$served_url" && cmp -s "$expected_appcast" "$download"; then
    exit 0
  fi
  if ((attempt < attempts)); then
    sleep "$delay"
  fi
done

printf 'error: served update feed did not match after %d attempts: %s\n' \
  "$attempts" \
  "$served_url" >&2
exit 1
