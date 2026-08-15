# Security policy

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Use GitHub's private vulnerability
reporting for this repository. Include affected versions, impact, reproduction steps, and any known
mitigations.

## Supported versions

No public binary has been released. Security fixes currently target `main`. A supported-version
table will be published with the first release.

## Security boundary

The baseline product uses a per-user helper, shared `IOHIDManager` access, and supported macOS event
APIs. It must not require root, patch system processes, disable platform security, or write device
firmware. See [docs/SECURITY.md](docs/SECURITY.md) for the threat model.
