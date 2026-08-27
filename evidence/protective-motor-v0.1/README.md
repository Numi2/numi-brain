# Protective motor output v0.1 evidence

This directory records exact-source build and correctness qualification for the
transactional protective-command and per-muscle output path at source revision
`2f8238bcb03338684e916291361d30d5f9f1a31b`.

## Apple M4 Pro qualification

The full SwiftPM suite passed on an Apple M4 Pro Mac mini:

- macOS 26.6, build 25G72;
- Apple Swift 6.3.3;
- 78 tests, zero failures;
- 27 Metal 4 tests;
- compiled 64-byte protective command, 32-byte muscle channel, and 64-byte
  motor-output header identities;
- exact CPU/Metal fused-operation parity for the six-channel synthetic muscle
  profile and its complete excitation fingerprint;
- accepted loss-of-support producing bracing, inhibition, arousal, and muscle
  output before the following physical candidate;
- rejected pain producing no scheduler, regional, command, or excitation
  history;
- root abort restoring committed command, output header, and excitation state;
- joint commit publishing the same protective output inspected before finish;
- nonzero private GPU header and excitation addresses exposed with exact
  timestamp, brain generation, profile identity, byte counts, and muscle count.

The checkout was clean and `HEAD` was verified against the source revision. The
Mac mini's unrelated 2,048-environment crow learner had exited before this run.

## Boundary

This is deterministic source/test evidence, not throughput, profiler, counter,
biological, or live-body evidence. The six muscle channels are synthetic
fixtures. No live NumanX solver consumed the GPU addresses; no authoritative
muscle activation, actuator motion, localized withdrawal, species calibration,
voluntary control, autonomic physiology, or physical outcome was demonstrated.
