# Interactive joint transaction v0.4 evidence

This directory records exact-source build and correctness qualification for the
interactive Metal candidate lifecycle and physical-time CPU relay oracle at
source revision `0664afa3f6ddf6bfefe5fc3fc39b13f8e1d588e4`.

## Apple M4 Pro qualification

The full SwiftPM suite passed on an Apple M4 Pro Mac mini:

- macOS 26.6, build 25G72;
- Apple Swift 6.3.3;
- 71 tests, zero failures;
- 24 Metal 4 tests, including interactive candidate reject, retry, accepted
  shadow, abort, joint commit, and exact batched-ledger parity;
- exact committed parity across tissue, scheduler result, regional state,
  recurrent tokens, delayed route history, and dynamic routing state;
- CPU physical-time relay tests covering exact samples, irregular-time linear
  interpolation, lost-coverage rejection, variable-duration retry, abort, and
  root chunking.

The checkout was clean and its `HEAD` was verified against the source revision
immediately before the test command. The Mac mini's unrelated crow-training
workload had exited before this qualification began.

## Boundary

This is deterministic source/test evidence, not a throughput measurement or a
live NumanX coupling result. The interactive reference synchronizes the host
after each Metal candidate. The GPU tissue path still uses fixed-step relay
history; corrected variable-duration relay sampling is currently executable
only in the CPU oracle. Accepted physical events reach scheduler/regional state
at root finalization rather than interrupting an in-flight physical substep.
