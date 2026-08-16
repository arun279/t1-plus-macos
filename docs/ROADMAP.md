# Roadmap

## Repository baseline

- native app and bundled-helper targets
- allocation-free Swift report decoder
- deterministic tests, hooks, CI, and security policy

## Core bake-off

- complete: implement the pure Swift semantic gesture engine
- complete: verify exact output-sequence parity on the valid private hardware corpus
- complete: benchmark Swift and optimized C with identical release inputs
- complete: select Swift for the production core in
  [ADR 0001](decisions/0001-use-swift-for-the-gesture-core.md)
- pending: curate sanitized public NDJSON fixtures before publishing raw trace data

## Functional application

- complete: exact HID device matching and shared input
- complete: baseline CoreGraphics pointer, button, scroll, momentum, and shortcut output
- complete: disconnect, stop, sleep, session, and signal cleanup in the helper
- in progress: permission onboarding and `SMAppService` lifecycle
- physical-hardware acceptance for pointer, click, drag, scroll, zoom, and three/four-finger actions
- wake/reconnect/held-state soak and performance acceptance
- complete: native exact-device status and versioned, bounded settings with live helper reload
- bounded diagnostics, reset, and uninstall

## Distribution

- Developer ID signing, hardened runtime, notarization, and DMG
- immutable GitHub releases from reviewed version pull requests
- Homebrew Cask after stable releases
- optional native virtual-HID backend only after entitlement and behavior validation

Bluetooth label correction remains an isolated research track. It must not introduce unsupported
host patches or device risk into the production application.
