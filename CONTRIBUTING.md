# Contributing

Contributions are welcome through pull requests.

## Development flow

1. Create a short-lived branch from `main`.
2. Run `scripts/bootstrap.sh` once for the clone. It verifies tools and enables the tracked hooks.
3. Make a focused change with matching tests and documentation.
4. Run `scripts/check.sh`.
5. Open a pull request and complete the applicable hardware-test section.

`main` is protected. Pull requests must be current with `main`, all required checks must pass, and
conversations must be resolved. The repository uses squash merges.

## Tooling

The production toolchain is pinned in `.xcode-version`; auxiliary versions are in
`Tools/versions.env`. On macOS, `scripts/prepare-local-tools.sh` downloads the official artifacts at
their recorded SHA-256 digests into ignored `.build/local-tools`. Review and invoke it explicitly;
`scripts/bootstrap.sh` never downloads or installs tools.

## Verification

| Command | Purpose |
| --- | --- |
| `scripts/format.sh` | Format Swift and shell sources |
| `scripts/lint.sh` | Check Swift, shell, and workflow sources |
| `scripts/test.sh` | Run deterministic core tests |
| `scripts/test-ui.sh` | Operate the native app with XCUITest without requesting permissions or registering the helper |
| `scripts/check-workspace-health.sh` | Fail before expensive local builds when disk, worktree, or temporary-output limits are exceeded |
| `scripts/deadcode.sh` | Find unused Swift declarations and imports after a clean build |
| `scripts/build.sh` | Build the native app and embedded helper |
| `scripts/test-app-package.sh` | Verify bundle identity, architecture, permissions, lifecycle APIs, and the read-only HID boundary |
| `scripts/verify-appcast.sh` | Verify the signed update feed, release version, and exact release URL |
| `scripts/check.sh` | Run the complete pre-push gate |

The settings tests own schema rejection, bounds, gesture mapping, preference round-trip, observer
lifetime, and reset behavior. The app-package gate owns bundle structure, required permission APIs,
the privacy-description allowlist, universal architecture, and rejection of known HID-write APIs.
Pull-request CI repeats these checks with the pinned stable Xcode and auxiliary tool versions.
The UI suite runs as a distinct required CI job because it needs an active graphical macOS session;
it does not belong in the noninteractive pre-push hook.

Hosted CI cannot validate Bluetooth, macOS privacy prompts, sleep/wake, input latency, energy use,
or real gestures. Changes to the helper or gesture behavior therefore require applicable physical
T1 Plus acceptance. A release also requires reconnect, soak, removal, rollback, and Windows
preservation checks. Automated replay does not replace operating the signed application normally on
a non-headless Mac.

## Releases

Releases are built from protected `main` by GitHub Actions. Do not build or publish a release from a
developer workstation.

1. Merge a version-preparation pull request that updates `VERSION`, every Xcode marketing version,
   the shared positive build number, and a dated `CHANGELOG.md` section.
2. Run **Release candidate** with that exact version. The protected `release-signing` environment
   builds the universal app, signs it with Developer ID, creates and signs the disk image, submits it
   for notarization, staples it, verifies Gatekeeper acceptance, signs the archive and update feed
   with Sparkle Ed25519, records provenance, and creates a draft GitHub release.
3. Test the exact draft disk image on a clean supported Mac with a physical T1 Plus. Cover fresh
   permissions, pairing before and after installation, enable and disable, gestures, reconnect,
   sleep and wake, removal, rollback, and the unchanged device on Windows.
4. If acceptance fails, run **Discard release candidate** before preparing a corrected candidate.
   If it passes, run **Publish release** and attest both macOS and Windows acceptance. The protected
   `release-publish` environment publishes the already accepted bytes without rebuilding them.

`release-signing` requires these environment secrets:

- `APPLE_DEVELOPER_ID_P12_BASE64`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`
- `APPLE_TEAM_ID`
- `APPLE_NOTARY_ISSUER_ID`
- `APPLE_NOTARY_KEY_ID`
- `APPLE_NOTARY_KEY_P8_BASE64`
- `SPARKLE_ED25519_PRIVATE_KEY`

Signing certificates, notarization keys, and the Sparkle private key must remain in GitHub
environment secrets. They must not
be committed, uploaded as ordinary artifacts, or copied into a release.

## Contribution terms

By contributing, you certify that you have the right to submit the work under Apache-2.0 and agree
to the [Developer Certificate of Origin 1.1](https://developercertificate.org/). Add a
`Signed-off-by` line to each commit with `git commit -s`. The tracked commit-message hook and
required pull-request security check enforce a sign-off matching the commit author.
