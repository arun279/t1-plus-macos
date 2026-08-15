# Roadmap

## Repository baseline

- native app and bundled-helper targets
- allocation-free Swift report decoder
- deterministic tests, hooks, CI, and security policy

## Core bake-off

- curate sanitized NDJSON fixtures
- implement gesture recognition against the language-neutral fixtures
- benchmark Swift and the C reference with identical release inputs
- select the production core by latency, allocation, memory, safety, and maintainability evidence

## Functional application

- exact HID device matching and shared input
- permission onboarding and `SMAppService` lifecycle
- pointer, click, drag, scroll, zoom, and three/four-finger actions
- disconnect, reconnect, sleep/wake, cancellation, and stuck-state recovery
- native settings and bounded diagnostics

## Distribution

- Developer ID signing, hardened runtime, notarization, and DMG
- immutable GitHub releases from reviewed version pull requests
- Homebrew Cask after stable releases
- optional native virtual-HID backend only after entitlement and behavior validation

Bluetooth label correction remains an isolated research track. It must not introduce unsupported
host patches or device risk into the production application.
