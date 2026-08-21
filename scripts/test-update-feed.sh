#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

fixture=$(mktemp -d "${TMPDIR:-/tmp}/t1-plus-update-feed-test.XXXXXX")
trap 'rm -rf "$fixture"' EXIT

appcast_path="$fixture/appcast.xml"
printf '%s\n' '<rss version="2.0"></rss>' > "$appcast_path"
scripts/stage-update-feed.sh "$appcast_path" "$fixture/site"

cmp "$appcast_path" "$fixture/site/appcast.xml"
cmp updates/index.html "$fixture/site/index.html"
[[ $(find "$fixture/site" -type f | wc -l | tr -d ' ') == 2 ]]
grep -Fq 'https://arun279.github.io/t1-plus-macos/appcast.xml' App/T1PlusApp/Info.plist
grep -Fq 'needs.candidate.outputs.bootstrap_feed' .github/workflows/release-candidate.yml
grep -Fq 'needs: publish' .github/workflows/publish-release.yml
UPDATE_FEED_VERIFY_ATTEMPTS=1 \
  scripts/verify-served-update-feed.sh "$appcast_path" "file://$appcast_path"

printf '%s\n' '<rss version="2.0"><channel/></rss>' > "$fixture/other.xml"
if UPDATE_FEED_VERIFY_ATTEMPTS=1 \
  scripts/verify-served-update-feed.sh \
  "$fixture/other.xml" \
  "file://$appcast_path" > /dev/null 2>&1; then
  printf 'error: update-feed verification accepted different served bytes\n' >&2
  exit 1
fi

if scripts/stage-update-feed.sh "$appcast_path" "$fixture/site" > /dev/null 2>&1; then
  printf 'error: update-feed staging unexpectedly replaced an existing directory\n' >&2
  exit 1
fi
