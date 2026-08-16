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
  scripts/release-notes.sh \
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

printf 'Release metadata tests passed.\n'
