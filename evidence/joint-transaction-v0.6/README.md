# Accepted fast-prefix joint transaction v0.6 evidence

This directory records exact-source build and correctness qualification for
physical-time Metal tissue conduction and accepted substep scheduler/regional
prefixes at source revision `a324c632e1f5c70540a82f6ccff3eee6ed179047`.

## Apple M4 Pro qualification

The full SwiftPM suite passed on an Apple M4 Pro Mac mini:

- macOS 26.6, build 25G72;
- Apple Swift 6.3.3;
- 74 tests, zero failures;
- 27 Metal 4 tests;
- corrected 750-microsecond candidates matching the physical-time CPU relay
  oracle, including deterministic interpolation and exact rejected retry;
- private UInt64 timestamp/value ownership committing and aborting together;
- fail-closed rejection before a bounded relay overwrite loses required
  physical-time coverage;
- an accepted loss-of-support event reaching the fast scheduler and regional
  shadow before root finish;
- a rejected pain event launching no fast prefix and leaving the accepted
  shadow exact;
- final joint commit matching the fast scheduler/regional state inspected
  before finish;
- interactive and batched committed parity across tissue, scheduler, regional
  diagnostics, recurrent tokens, delayed route history, and routing state.

The checkout was clean and its `HEAD` was verified against the source revision
before the test command. The Mac mini's unrelated 2,048-environment crow learner
had exited before this qualification began.

## Boundary

This is deterministic source/test evidence, not a throughput measurement or a
live NumanX coupling result. The interactive reference synchronizes the host
after each Metal candidate. An accepted interrupt updates a transaction-owned
regional shadow after physical acceptance, so it can affect the next candidate
but cannot alter the already accepted physical step. Protective motor output,
live cross-runtime command coordination, and atomic physical/brain pointer
publication are not implemented. The bounded v0.6 path recomputes each accepted
regional prefix from the untouched committed generation; it is correctness
behavior, not an incremental-prefix performance qualification.
