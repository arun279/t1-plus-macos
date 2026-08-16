# T1 Plus Touchpad Support for macOS

Unofficial macOS touchpad support for the ProtoArc T1 Plus.

This project is building a native macOS settings app and a small per-user helper that translate the
T1 Plus multitouch HID reports into supported macOS input events. The device remains unmodified and
continues to use its factory firmware on Windows.

> [!IMPORTANT]
> This repository is under active development. It does not yet publish an installable release.

## Principles

- Use supported macOS APIs and a normal signed application bundle.
- Make the disabled state cost nothing: no resident helper and no background polling.
- Keep the event path allocation-free and event-driven.
- Never require root for the baseline input path.
- Never write firmware or persistent device state.
- Preserve normal Windows compatibility.

## Repository layout

- `App/T1PlusApp`: native SwiftUI/AppKit settings application
- `Helper/T1PlusHelper`: bundled per-user input helper
- `Packages/T1Core`: report decoding and gesture semantics with no UI dependency
- `docs`: standalone architecture, protocol, security, and testing documentation
- `scripts`: the canonical build, test, formatting, and analysis commands

## Development

The supported production toolchain is Xcode 26.6. The core package can also be developed with its
matching Swift command-line toolchain.

```sh
scripts/bootstrap.sh
scripts/check.sh
```

`bootstrap.sh` verifies required tools and configures this clone's Git hooks. It does not install
software. See [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/TESTING.md](docs/TESTING.md) for the exact
checks and the hardware test boundary.

## Project status

The raw report decoder and semantic gesture engine are implemented in Swift and covered by
deterministic tests. The helper now connects through shared, read-only IOHID input and translates
semantic actions through CoreGraphics, with reconnect and output-state cleanup. The native app now
shows the two required macOS permissions and controls the bundled helper through `SMAppService`.
The T1 Plus can be paired before or after support is enabled; the helper waits for it and reconnects
automatically. The language decision and release-build evidence are recorded in
[ADR 0001](docs/decisions/0001-use-swift-for-the-gesture-core.md). Signed-app permission and
service lifecycle acceptance, settings, diagnostics, and full hardware acceptance remain under
development. No public release is ready yet.

## Independence and trademarks

This is an independent, unofficial compatibility project. It is not affiliated with, sponsored by,
or endorsed by ProtoArc or Apple. ProtoArc, T1 Plus, Apple, and macOS are trademarks of their
respective owners and are used only to identify compatibility.

## License

Licensed under the [Apache License 2.0](LICENSE).
