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
| `scripts/deadcode.sh` | Find unused Swift declarations and imports after a clean build |
| `scripts/build.sh` | Build the native app and embedded helper |
| `scripts/test-app-package.sh` | Verify bundle identity, architecture, permissions, lifecycle APIs, and the read-only HID boundary |
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

## Contribution terms

By contributing, you certify that you have the right to submit the work under Apache-2.0 and agree
to the [Developer Certificate of Origin 1.1](https://developercertificate.org/). Add a
`Signed-off-by` line to each commit with `git commit -s`. The tracked commit-message hook and
required pull-request security check enforce a sign-off matching the commit author.
