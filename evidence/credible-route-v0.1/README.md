# Credible-route portable verification

The bounded log excerpt is from an actual isolated Foundation-only check run
using Swift 6.2.1 on x86_64 Linux. It contains 38 focused XCTest cases: 27
qualification/file-I/O/safety/attempt cases and 11 physical-task/sensor cases.
The watchdog missing-heartbeat smoke check also created a sticky stop file and
returned exit 1. `scripts/validate-credible-route-portable.sh` reproduces that
verification scope from repository source.

This is not a complete repository build, native sensor/physics execution,
Apple MLX execution, hardware stop enforcement or a task-improvement result.
The local source snapshot contained the authored Foundation modules and selected
tests; other Core/Metal/MLX files were only syntax-parsed. Thirty-two local Swift
files passed syntax parsing; this is not Apple-target type checking.

The full local log is supplied with the development handoff. No source hash
manifest or fabricated native run is attached to these portable results.
