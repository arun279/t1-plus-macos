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
`Tools/versions.env`. `Brewfile` is an explicit local-install convenience, not a runtime dependency
or a CI source of truth. Do not run it on a machine whose package state you do not intend to change.

## Contribution terms

By contributing, you certify that you have the right to submit the work under Apache-2.0 and agree
to the [Developer Certificate of Origin 1.1](https://developercertificate.org/). Add a
`Signed-off-by` line to each commit with `git commit -s`.
