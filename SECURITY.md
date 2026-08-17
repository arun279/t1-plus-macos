# Security policy

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Use GitHub's private vulnerability
reporting for this repository. Include affected versions, impact, reproduction steps, and any known
mitigations.

## Supported versions

No public binary has been released. Security fixes currently target `main`. A supported-version
table will be published with the first release.

## Security boundary

The security-sensitive assets are user input, the macOS session and its Accessibility permission,
release integrity, factory device firmware, and Windows compatibility. Device reports are untrusted:
the decoder validates report ID and length before reading fields, and gesture code has no access to
HID or event-posting APIs.

The signed per-user helper opens only vendor/product `04e8:7021` with primary usage Digitizers /
Touch Pad, in shared mode. The product must not require root, patch system processes, weaken platform
security, use private APIs, flash firmware, persist device writes, capture broad HID input, or accept
unauthenticated commands from other users or processes.

Configuration and diagnostics remain local. The on-demand diagnostics report has a fixed field
allowlist and excludes touch data, logs, user identity, paths, and serial numbers. There is no
telemetry or network service in the baseline product.

## Permissions

| Consent | Purpose |
| --- | --- |
| Input Monitoring | Read reports from the exact T1 Plus HID service |
| Accessibility event posting | Emit pointer, balanced button, scrolling, and configured gesture events |
| Background Item approval | Run the bundled helper while support is enabled and the settings app is closed |

The product does not request Automation, Screen Recording, Full Disk Access, Bluetooth privacy,
administrator access, or root authorization. The package gate rejects every privacy usage-description
key outside the one Input Monitoring declaration.

An external preference change cannot invoke a helper command. The helper accepts only a complete,
versioned, bounded settings value and ignores changes that do not alter effective configuration.
