#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

fixture=$(mktemp -d "${TMPDIR:-/tmp}/t1-plus-appcast-test.XXXXXX")
cleanup() {
  rm -rf "$fixture"
}
trap cleanup EXIT

cat > "$fixture/generate_appcast" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

read -r private_key
[[ -n $private_key ]]

while (($#)); do
  case $1 in
    --ed-key-file)
      [[ $2 == - ]]
      shift 2
      ;;
    --download-url-prefix)
      download_prefix=$2
      shift 2
      ;;
    --embed-release-notes)
      shift
      ;;
    --maximum-deltas)
      [[ $2 == 0 ]]
      shift 2
      ;;
    -o)
      output_path=$2
      shift 2
      ;;
    *)
      archives_directory=$1
      shift
      ;;
  esac
done

dmg_path=$(find "$archives_directory" -type f -name '*.dmg' -print -quit)
[[ -f $dmg_path ]]
[[ -f ${dmg_path%.dmg}.md ]]
signature=$(dd if=/dev/zero bs=64 count=1 2> /dev/null | base64 | tr -d '\n')
cat > "$output_path" << EOF_APPCAST
<?xml version="1.0" encoding="utf-8"?>
<!-- sparkle-sign-warning: signed -->
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <item>
      <sparkle:version>1</sparkle:version>
      <sparkle:shortVersionString>0.1.0</sparkle:shortVersionString>
      <enclosure url="${download_prefix}$(basename "$dmg_path")" sparkle:edSignature="$signature" />
    </item>
  </channel>
</rss>
<!-- sparkle-signatures:
edSignature: $signature
length: 1
-->
EOF_APPCAST
EOF
chmod +x "$fixture/generate_appcast"

dmg_path="$fixture/T1-Plus-Touchpad-Support-for-macOS-0.1.0.dmg"
appcast_path="$fixture/appcast.xml"
touch "$dmg_path"
printf 'private-key\n' |
  env \
    SPARKLE_DOWNLOAD_URL_PREFIX=https://github.com/arun279/t1-plus-macos/releases/download/v0.1.0 \
    SPARKLE_GENERATE_APPCAST="$fixture/generate_appcast" \
    scripts/generate-appcast.sh 0.1.0 "$dmg_path" "$appcast_path"
scripts/verify-appcast.sh 0.1.0 "$dmg_path" "$appcast_path"

sed 's:/releases/download/v0\.1\.0/:/releases/download/v9.9.9/:' \
  "$appcast_path" > "$fixture/invalid-appcast.xml"
if scripts/verify-appcast.sh \
  0.1.0 \
  "$dmg_path" \
  "$fixture/invalid-appcast.xml" > /dev/null 2>&1; then
  printf 'error: invalid appcast unexpectedly passed verification\n' >&2
  exit 1
fi

printf 'Appcast tests passed.\n'
