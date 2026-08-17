# Changelog

This project follows Semantic Versioning. This file is the source for public release notes.

## Unreleased

### Added

- Native SwiftUI settings app and bundled per-user `SMAppService` helper.
- Exact, shared, read-only T1 Plus HID matching and event-driven reconnect behavior.
- Swift report decoder and allocation-free gesture state machine with deterministic tests.
- CoreGraphics pointer, click, drag, continuous scroll, momentum, zoom-shortcut, and
  three/four-finger output.
- Native permission onboarding, device/helper status, and support enable/disable controls.
- Versioned, bounded pointer, tap, scroll, and gesture settings with live helper reload.
- Bounded local diagnostics export, settings reset, and support removal.
- Protected pull-request checks for formatting, linting, dead code, tests, universal builds,
  package structure, secrets, and workflow security.
- Native XCUITest coverage for essential controls, support-removal disclosure, and final-window
  process termination.

### Security

- Restrict input to the exact device identity and reject known device-write APIs from the package.
- Release held output state on disconnect, stop, sleep, inactive session, and termination.
- Preserve the all-fingers-lift gate across repeated suspension and settings-reload events.
- Keep overlapping sleep and inactive-session suspension independent so system wake cannot resume
  input before the user session becomes active.
- Start suspended when the helper launches into an already inactive user session.
- Enforce an allowlist containing only the required Input Monitoring privacy description.
