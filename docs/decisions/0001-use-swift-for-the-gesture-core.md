# ADR 0001: Use Swift for the gesture core

- Status: Accepted
- Date: 2026-08-15

## Context

The application and per-user helper require Apple's native macOS frameworks. The report decoder and
gesture state machine still need an independently justified implementation language. Prototype reuse
and rewrite cost are not selection criteria. The important criteria are semantic correctness,
latency, allocation behavior, runtime overhead, safety, packaging complexity, and maintainability.

The candidates considered were Swift, C, C++, Objective-C++, and Rust. Swift and C were implemented
far enough to compare because neither requires a garbage collector and both can express a compact,
event-driven state machine. No measured requirement justified introducing the additional C++ or Rust
toolchain and interoperability surface.

## Decision

Use pure Swift for `T1Protocol` and `T1Gestures`. Keep the core independent of Foundation, AppKit,
SwiftUI, IOKit, and CoreGraphics. Pass semantic actions through a generic sink so the production hot
path does not create a per-frame action collection or existential box.

The implementation uses fixed-capacity value storage for the four report contacts and eight possible
contact identifiers. It performs no logging, locking, blocking I/O, or intentionally per-frame heap
allocation. Explicit fields preserve the macOS 13 deployment target without depending on newer
fixed-array language/library availability. The app and helper are already Swift processes, so this
choice adds no second language runtime. The C prototype is not a shipped runtime component.

## Evidence

Both engines replayed the same decoded frames and produced canonical fingerprints covering action
order, pointer and scroll deltas, button side, button phase, click count, scroll phase, and shortcut
identity. All 15 valid hardware traces, totaling 14,729 frames, matched exactly.

The latency comparison used seven representative hardware traces. Input parsing was outside the
timed region. Each release-built engine replayed every trace 5,000 times per trial for five
alternating trials. The table reports the median trial on an Apple M5 Pro running macOS 26.6.1.
Swift used `swift build -c release`; C used Apple Clang 21 with `-O2 -DNDEBUG` and strict warnings.

| Scenario | Frames | C ns/frame | Swift ns/frame | Swift minus C |
| --- | ---: | ---: | ---: | ---: |
| One-finger pointer | 506 | 13.03 | 16.11 | 3.08 ns |
| Physical buttons | 361 | 6.13 | 10.72 | 4.59 ns |
| Two-finger scroll | 306 | 17.54 | 17.83 | 0.29 ns |
| Pinch | 1,024 | 16.70 | 16.32 | -0.38 ns |
| Three-finger gesture | 954 | 21.88 | 22.03 | 0.15 ns |
| Four-finger horizontal gesture | 1,362 | 23.12 | 26.16 | 3.04 ns |
| Four-finger vertical gesture | 1,208 | 21.50 | 24.25 | 2.75 ns |
| Frame-weighted aggregate | 5,721 | 19.16 | 21.00 | 1.84 ns |

The aggregate Swift result is 9.6 percent slower in this isolated microbenchmark, but the absolute
difference is 1.84 nanoseconds per report. That is about 0.23 microseconds of CPU time per second at
125 reports per second, or 1.84 microseconds per second even at 1,000 reports per second. This is not
a material CPU, latency, or battery difference for the product.

The microbenchmark proves only decoded-frame state-machine cost. Integrated helper measurements still
gate idle wakeups, p99 latency, allocations, resident memory, energy use, reconnect behavior, and
output-backend cost.

## Consequences

- Memory-safe value types and strict concurrency checking cover the highest-frequency product code.
- The app, helper, core, tests, signing, and release builds use one Apple-supported toolchain.
- There is no C ABI, ownership bridge, sanitizer matrix, or duplicated model representation to audit.
- Raw hardware captures remain outside the public repository until explicitly curated and sanitized.
  Public CI uses deterministic synthetic inputs; hardware replay remains a release acceptance gate.
- If integrated measurements fail a published budget, this decision must be revisited from new
  evidence. The semantic-action boundary still permits an isolated C, Rust, or native-HID backend.
