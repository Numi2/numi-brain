# NumanX protective motor handoff v0.2 evidence

This directory records exact-source build and correctness qualification for the
transaction-bound NumanX motor-candidate packet at source revision
`2d41c7fd289deb0ef752008f0fbd89dfb6d1c623`.

## Apple M4 Pro qualification

The full SwiftPM suite passed on an Apple M4 Pro Mac mini:

- macOS 26.6, build 25G72;
- Apple Swift 6.3.3;
- 78 tests, zero failures;
- 27 Metal 4 tests;
- compiled 96-byte `NBNumanXMotorCandidate` size identity;
- exact root and candidate-substep binding;
- accepted brain timestamp and base-versus-shadow generation validation;
- unchanged random-counter generation and environment validation;
- nonzero, aligned private motor-header and muscle-excitation GPU addresses;
- exact header/excitation byte counts, muscle count, and profile identity;
- rejection of an address-tampered packet even after its fingerprint was
  recomputed;
- existing command, muscle-output, rejection, abort, and commit checks retained.

The checkout was clean and `HEAD` was verified against the source revision.

## Boundary

This validates a transaction-local handoff record on the owning Metal runtime.
GPU addresses are ephemeral and are not checkpoint or replay identity. No live
NumanX solver consumed the packet, no cross-runtime command buffer was submitted,
and no muscle, actuator, body, or autonomic physics changed. This is not
throughput, profiler, counter, physical-outcome, or biological evidence.
