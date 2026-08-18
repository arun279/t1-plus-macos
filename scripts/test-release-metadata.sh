#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$script_dir/.." && pwd)
cd "$root"

fixture=$(mktemp -d "${TMPDIR:-/tmp}/t1-plus-release-metadata.XXXXXX")
cleanup() {
  rm -rf "$fixture"
}
trap cleanup EXIT

mkdir -p "$fixture/bin" "$fixture/scripts" "$fixture/T1Plus.xcodeproj"
cp \
  scripts/archive-release.sh \
  scripts/delete-release-candidate.sh \
  scripts/release-notes.sh \
  scripts/verify-release-dmg.sh \
  scripts/verify-release-history.sh \
  scripts/verify-release-metadata.sh \
  "$fixture/scripts/"
printf '1.2.3\n' > "$fixture/VERSION"
sed 's/MARKETING_VERSION = [^;]*/MARKETING_VERSION = 1.2.3/' \
  T1Plus.xcodeproj/project.pbxproj > "$fixture/T1Plus.xcodeproj/project.pbxproj"
cat > "$fixture/CHANGELOG.md" << 'EOF'
# Changelog

## [Unreleased]

## [1.2.3] - 2026-08-16
- First release note.
- Second release note.

## [1.2.2] - 2026-08-15
- Previous release.
EOF
cat > "$fixture/bin/gh" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "${FAKE_RELEASE_TAGS:-}"
EOF
chmod +x "$fixture/bin/gh"
cat > "$fixture/bin/codesign" << 'EOF'
#!/usr/bin/env bash
if [[ $* == *'--entitlements'* ]]; then
  exit 0
fi
if [[ $* != *'--display'* ]]; then
  exit 0
fi
path=${!#}
case $path in
  *.dmg) identifier=io.github.arun279.t1plus.disk-image ;;
  *T1PlusHelper.app) identifier=io.github.arun279.t1plus.helper ;;
  *) identifier=io.github.arun279.t1plus ;;
esac
cat << EOF_SIGNATURE
Identifier=$identifier
CodeDirectory v=20500 size=100 flags=0x10000(${FAKE_RUNTIME_FLAG:-runtime}) hashes=1+7 location=embedded
Authority=Developer ID Application: Test (ABCDEFGHIJ)
Timestamp=Aug 17, 2026 at 8:00:00 PM
TeamIdentifier=ABCDEFGHIJ
EOF_SIGNATURE
EOF
cat > "$fixture/bin/hdiutil" << 'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == attach ]]; then
  while (($#)); do
    if [[ $1 == -mountpoint ]]; then
      mkdir -p "$2/T1 Plus Touchpad Support for macOS.app/Contents/Library/LoginItems/T1PlusHelper.app"
      break
    fi
    shift
  done
fi
EOF
for command in rmdir spctl xcrun; do
  cat > "$fixture/bin/$command" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
done
cat > "$fixture/scripts/test-dmg-package.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fixture/bin/codesign" "$fixture/bin/hdiutil" "$fixture/bin/rmdir" \
  "$fixture/bin/spctl" "$fixture/bin/xcrun" "$fixture/scripts/test-dmg-package.sh"

expect_failure() {
  if "$@" > /dev/null 2>&1; then
    printf 'error: command unexpectedly succeeded: %s\n' "$*" >&2
    exit 1
  fi
}

expect_failure env \
  APPLE_TEAM_ID=invalid \
  CODESIGN_IDENTITY='Developer ID Application: Test' \
  "$fixture/scripts/archive-release.sh" "$fixture/archive" "$fixture/export"
expect_failure env \
  APPLE_TEAM_ID=ABCDEFGHIJ \
  CODESIGN_IDENTITY='Apple Development: Test' \
  "$fixture/scripts/archive-release.sh" "$fixture/archive" "$fixture/export"

[[ $("$fixture/scripts/verify-release-metadata.sh" 1.2.3) == 1.2.3 ]]
expect_failure "$fixture/scripts/verify-release-metadata.sh" 1.2.4
[[ $("$fixture/scripts/release-notes.sh" 1.2.3) == $'- First release note.\n- Second release note.' ]]

cp "$fixture/CHANGELOG.md" "$fixture/CHANGELOG.valid.md"
sed 's/## \[1\.2\.3\] - 2026-08-16/## [1.2.3] - Unreleased/' \
  "$fixture/CHANGELOG.valid.md" > "$fixture/CHANGELOG.md"
expect_failure "$fixture/scripts/verify-release-metadata.sh" 1.2.3
cp "$fixture/CHANGELOG.valid.md" "$fixture/CHANGELOG.md"

release_environment=(
  "PATH=$fixture/bin:$PATH"
  GH_TOKEN=test-token
  GITHUB_REPOSITORY=example/t1-plus-macos
)
env "${release_environment[@]}" FAKE_RELEASE_TAGS=$'v1.2.2\nv0.9.0' \
  "$fixture/scripts/verify-release-history.sh" 1.2.3
expect_failure env "${release_environment[@]}" FAKE_RELEASE_TAGS=v1.2.3 \
  "$fixture/scripts/verify-release-history.sh" 1.2.3
expect_failure env "${release_environment[@]}" FAKE_RELEASE_TAGS=v2.0.0 \
  "$fixture/scripts/verify-release-history.sh" 1.2.3
expect_failure env "${release_environment[@]}" FAKE_RELEASE_TAGS=v1.2.2 \
  "$fixture/scripts/verify-release-history.sh" 01.2.3

touch "$fixture/candidate.dmg"
env PATH="$fixture/bin:$PATH" \
  "$fixture/scripts/verify-release-dmg.sh" "$fixture/candidate.dmg"
expect_failure env PATH="$fixture/bin:$PATH" FAKE_RUNTIME_FLAG=none \
  "$fixture/scripts/verify-release-dmg.sh" "$fixture/candidate.dmg"

cat > "$fixture/bin/gh" << 'EOF'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  'release delete')
    rm -f "$FAKE_RELEASE_STATE/release"
    ;;
  'release view')
    [[ -e $FAKE_RELEASE_STATE/release ]]
    ;;
  'api --method')
    rm -f "$FAKE_RELEASE_STATE/tag"
    ;;
  *)
    exit 64
    ;;
esac
EOF
cat > "$fixture/bin/git" << 'EOF'
#!/usr/bin/env bash
[[ ${1:-} == ls-remote ]] || exit 64
[[ ${FAKE_TAG_LOOKUP_ERROR:-} != true ]] || exit 128
[[ -e $FAKE_RELEASE_STATE/tag ]] || exit 2
EOF
chmod +x "$fixture/bin/gh" "$fixture/bin/git"

cleanup_state="$fixture/release-cleanup"
mkdir -p "$cleanup_state"
touch "$cleanup_state/release"
env \
  PATH="$fixture/bin:$PATH" \
  FAKE_RELEASE_STATE="$cleanup_state" \
  GITHUB_REPOSITORY=example/t1-plus-macos \
  "$fixture/scripts/delete-release-candidate.sh" v1.2.3
[[ ! -e $cleanup_state/release ]]

touch "$cleanup_state/release" "$cleanup_state/tag"
env \
  PATH="$fixture/bin:$PATH" \
  FAKE_RELEASE_STATE="$cleanup_state" \
  GITHUB_REPOSITORY=example/t1-plus-macos \
  "$fixture/scripts/delete-release-candidate.sh" v1.2.3
[[ ! -e $cleanup_state/release ]]
[[ ! -e $cleanup_state/tag ]]

touch "$cleanup_state/release"
expect_failure env \
  PATH="$fixture/bin:$PATH" \
  FAKE_RELEASE_STATE="$cleanup_state" \
  FAKE_TAG_LOOKUP_ERROR=true \
  GITHUB_REPOSITORY=example/t1-plus-macos \
  "$fixture/scripts/delete-release-candidate.sh" v1.2.3
[[ -e $cleanup_state/release ]]

expect_failure env \
  PATH="$fixture/bin:$PATH" \
  FAKE_RELEASE_STATE="$cleanup_state" \
  GITHUB_REPOSITORY=example/t1-plus-macos \
  "$fixture/scripts/delete-release-candidate.sh" invalid

printf 'Release metadata tests passed.\n'
