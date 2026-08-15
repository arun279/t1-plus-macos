# Repository instructions

## Scope

This repository contains the production macOS application. Experimental captures, downloaded
vendor material, credentials, signing assets, and machine-specific logs do not belong here.

## Required commands

- Format: `scripts/format.sh`
- Lint: `scripts/lint.sh`
- Build: `scripts/build.sh`
- Test: `scripts/test.sh`
- Full gate: `scripts/check.sh`

Run the full gate before pushing. Do not bypass hooks or required GitHub checks.

## Engineering rules

- Keep the physical-device path read-only and shared unless a reviewed protocol requirement proves
  a volatile write is both necessary and safe.
- Do not add root daemons, private APIs, firmware writes, or persistent device changes.
- Keep UI/lifecycle code separate from the decoder and gesture state machine.
- Do not allocate, log, or perform blocking work per input frame.
- Add deterministic tests for every protocol or gesture defect.
- Add dependencies only with a documented security, maintenance, size, and runtime justification.
- Keep documentation standalone. Do not refer to private workspaces or conversation history.
