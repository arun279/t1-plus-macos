# Security model

## Assets

- user input confidentiality and integrity
- the user's macOS session and accessibility permissions
- application signing and update integrity
- factory device firmware and Windows compatibility

## Trust boundaries

The physical device supplies untrusted fixed-size reports. The decoder rejects wrong report IDs and
lengths before reading fields. Gesture logic receives normalized values and cannot access HID or
event-posting APIs. Only the signed helper can read the configured device and post translated events.

Configuration and diagnostics are local. A future updater must use signed, notarized, immutable
release artifacts. No telemetry or network service is part of the baseline design.

## Prohibited production behavior

- root daemons or setuid helpers
- private APIs, system-process injection, or weakened platform security
- firmware flashing or persistent device writes
- broad HID capture without exact device matching
- logging raw user input by default
- accepting unauthenticated IPC commands from other users or processes

Diagnostic capture must be explicit, visibly active, bounded, locally stored, and sanitized before
sharing.
