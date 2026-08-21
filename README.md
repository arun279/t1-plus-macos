# T1 Plus Touchpad Support for macOS

Unofficial macOS touchpad support for the ProtoArc T1 Plus.

This project is building a native macOS settings app and a small per-user helper that translate the
T1 Plus multitouch HID reports into supported macOS input events. The device remains unmodified and
continues to use its factory firmware on Windows.

## Install

T1 Plus Touchpad Support requires macOS 13 or later.

1. Download the disk image and matching `.sha256` file from the
   [latest GitHub release](https://github.com/arun279/t1-plus-macos/releases/latest).
2. Optionally verify the download from Terminal in the download directory:

   ```sh
   shasum -a 256 --check T1-Plus-Touchpad-Support-for-macOS-*.dmg.sha256
   ```

3. Open the disk image and drag **T1 Plus Touchpad Support for macOS** to Applications.
4. Open the app. Use its buttons to grant Input Monitoring and Accessibility. The app relaunches
   once after Accessibility approval so macOS reports the new permission, then turn on the touchpad.
5. Pair the T1 Plus in Bluetooth settings. Pairing before or after setup is supported.

Use **Check for Updates…** in the app menu or the Updates section to check manually. Automatic
checking and automatic download/install are separate opt-in settings in the app.

The helper runs only while the touchpad is turned on. The app may also appear under Login Items because
macOS manages the bundled helper as a background item. Touch input and diagnostics stay on the Mac;
the helper has no network access. The settings app contacts only the signed GitHub Releases update
feed while it is open and update checks are enabled or requested.

To uninstall, open the app and use **Prepare for Uninstall…** before moving the application to
Trash. That unregisters the helper and resets its settings without changing the touchpad, its
firmware, or its Bluetooth pairing. macOS privacy grants can be revoked separately in System
Settings.

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
- `docs`: standalone architecture, protocol, and engineering-decision documentation
- `scripts`: the canonical build, test, formatting, and analysis commands

## Development

The supported production toolchain is Xcode 26.6. The core package can also be developed with its
matching Swift command-line toolchain.

```sh
scripts/prepare-local-tools.sh # optional repo-local tools; no Homebrew or global install
scripts/bootstrap.sh
scripts/check.sh
```

`prepare-local-tools.sh` downloads checksum-pinned macOS binaries into ignored
`.build/local-tools`; omit it when the pinned tools are already on `PATH`. `bootstrap.sh` only verifies
tools and configures this clone's Git hooks. `check.sh` checks formatting, lints, tests, analyzes,
builds, validates the app bundle, and scans for secrets. See
[CONTRIBUTING.md](CONTRIBUTING.md) for individual commands, CI behavior, and the hardware test
boundary.

## Project status

The raw report decoder and semantic gesture engine are implemented in Swift and covered by
deterministic tests. The helper now connects through shared, read-only IOHID input and translates
semantic actions through CoreGraphics, with reconnect and output-state cleanup. The native app now
shows the two required macOS permissions and controls the bundled helper through `SMAppService`.
The T1 Plus can be paired before or after the touchpad is turned on; the helper waits for it and reconnects
automatically. The app also reports exact-device presence and configures pointer speed, tapping,
scrolling, and gestures through versioned, validated per-user settings. It can export a bounded,
local diagnostics report and remove the helper registration and settings without touching the
device. The language decision and release-build evidence are recorded in
[ADR 0001](docs/decisions/0001-use-swift-for-the-gesture-core.md). Each published release is
Developer ID-signed, notarized, stapled, and made from an accepted draft artifact without rebuilding
it. Each release also includes a signed Sparkle appcast so installed copies can update without a
manual reinstall. The release checklist includes fresh permission and service lifecycle testing, full hardware
behavior on macOS, and unchanged-device regression testing on Windows.

## Independence and trademarks

This is an independent, unofficial compatibility project. It is not affiliated with, sponsored by,
or endorsed by ProtoArc or Apple. ProtoArc, T1 Plus, Apple, and macOS are trademarks of their
respective owners and are used only to identify compatibility.

## License

Licensed under the [Apache License 2.0](LICENSE).
Third-party license notices are in [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).
