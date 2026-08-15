# Testing

## Local gates

| Command | Ownership |
| --- | --- |
| `scripts/format.sh` | Swift and shell formatting |
| `scripts/lint.sh` | Swift style, shell analysis, workflow syntax, and action hardening |
| `scripts/test.sh` | deterministic core unit and replay tests |
| `scripts/build.sh` | unsigned native app and embedded-helper build |
| `scripts/deadcode.sh` | type-aware SwiftLint analyzer rules after a clean Xcode build |
| `scripts/test-app-package.sh` | bundle identity and helper-embedding smoke test |
| `scripts/check.sh` | complete pre-push gate |

`scripts/bootstrap.sh` verifies tools and enables the tracked hooks. It never installs tools. The
optional `Brewfile` is an explicit convenience for developers who choose to modify their local
Homebrew environment.

## CI

Pull requests use stable checks for formatting/linting, release building, core tests, app-package
tests, and security/workflow analysis. GitHub-hosted macOS 26 runners supply stable Xcode 26.6 and
SwiftLint 0.65.0; workflows assert those versions before trusting results.

## Hardware boundary

Hosted CI cannot validate Bluetooth, TCC permissions, sleep/wake, latency, battery use, or real
gestures. Changes that affect the helper or gesture behavior require a physical T1 Plus acceptance
record before merge. Releases additionally require reconnect, soak, uninstall, rollback, and
Windows-preservation checks.

Automated replay proves deterministic behavior for captured input. It does not replace real-user
operation of the signed application on a non-headless Mac.
