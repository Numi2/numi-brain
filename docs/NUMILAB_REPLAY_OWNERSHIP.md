# NumiLab compatibility execution and replay ownership

The borrowed native bridge is an experimental **host-action compatibility**
path. It is not the production zero-copy joint Brain/body protocol. A passing
loader, shader, mock-owner test or package build does not establish that protocol.

## Admission and failure handling

One `NumiLabBorrowedTaskRollout` must exclusively own access to its borrowed
native handle. The embedding application still owns the handle's lifetime and
must prohibit other wrappers or direct native operations while borrowed. Swift
serializes complete operations, including nested snapshots and every step of a
restore. This lock is not GPU synchronization.

The C bridge retains the actual compiled action table, immutable layout and last
accepted counters. Out-of-band changes, failed native execution, inconsistent
acceptance or unavailable accepted-state digest quarantine the bridge. A failed
output is cleared. Invalid input and counter exhaustion are rejected before
physics; they do not by themselves change physical state.

Do not retry a quarantined world. Dispose it and restore into a fresh world from
retained, matching native construction inputs. Neither quarantine nor aborting
Brain reverses a native step that has already executed.

## Completed motor ownership

`NumiLabPositionPhysicalExecutor.execute` and
`NumiLabPositionHostActionAdapter.makeFrame` now require `ticket:`, the actual
`MetalTissueRuntime.NumanXMotorSubmissionTicket`, rather than a bare `lease:`.
This is an intentional tightening of the experimental API. The adapter checks
terminal producer feedback, successful motor-ready evaluation, candidate identity
and exact physical substep before reading command memory. An unfinished or failed
ticket does not advance physics. No new command queue or hidden staging readback
is created. The normal owner must still settle/reap its asynchronous submission.

Only shared command storage is accepted. Managed storage requires an explicit
GPU-to-CPU resource synchronization which this API does not provide; private and
memoryless storage are also rejected. Buffer arithmetic is overflow-checked.
Apple's resource contract is documented at:
https://developer.apple.com/documentation/metal/synchronizing-a-managed-resource-in-macos

For this single-environment path, native completed-environment-step count is the
physical generation, starting at zero in the fresh world. The root's base physics
generation must match it exactly. Reusing an old root or inventing a generation
offset fails before native execution. Multi-substep root composition needs its
own physical-owner integration and is not supplied by this one-step adapter.

## Exact replay records

`NumiLabRolloutAdvanceReceipt.policyRevision` retains the actual value passed to
native execution. `journal.appending(executed)` records it automatically. The
optional `policyRevision:` argument is only an assertion; a mismatch is rejected.
Receipt validation rejects counter overflow, identity drift, resets, GPU status
errors, nonfinite timing and noncontiguous accepted counts.

Restore holds exclusive access to its entire fresh target. Every accepted step
must reproduce counters and the native logical-byte resident-state digest. A
failed restore quarantines the partially advanced target instead of making it
available for publication. This is replay from retained construction inputs, not
an O(1) binary resident snapshot, transactional rollback or a durable serialized
paired Brain/physics checkpoint. Its cost grows with recorded steps.

A physical replay record is not evidence that the Brain root committed. Only
jointly committed transitions may enter training and lived memory. The journal
must not bypass that existing ownership rule.

## Verification scopes

`test_connectome_numilab_bridge.py` injects faults through a synthetic C owner.
It verifies bridge failure handling, not physics. The Apple job also builds that
fixture against the real pinned native header. Gate and receipt tests establish
bounded synchronization/arithmetic behavior.

`numilab-owner-replay.yml` separately builds the actual pinned NumiLab dylib and
shaders and runs native Franka/G1/X500 worlds through the bridge. It requires
per-step digest equality and final-q byte equality across four-step replay plus
changed-command divergence. Its success must be observed, not inferred from the
presence of the test. It contains no neural controller or Brain joint publication
and does not qualify standing, reaching, flight, learning or hardware safety.

Remaining product work includes the actual connectome-to-mounted-sensors closed
loop, full joint physical rollback/publication, paired durable persistence,
body-specific learning and held-out robot outcomes. Keep these distinct from
successful source and compatibility-interface checks.

## Reference Apple qualification

Run `tools/qualify_numilab_reference.py --native-owner /path/to/numi-lab
--numilab-sha <exact-sha> --output /new/external/receipt-directory` on a physical
Apple Silicon host. It requires API-confirmed Metal 4 and an Apple GPU family,
rejects Paravirtual devices, checks the exact checked-in 109-kernel inventory,
and runs the unchanged bridge replay plus native-owner regressions. Both source
checkouts must be clean. All commands, exits, capabilities and hashes are kept.

The workflow now targets a self-hosted `numilab-metal4` ARM64 Mac via explicit
workflow dispatch. No reference runner was registered when this change was
made; current qualification is executed directly over SSH on the M4 Pro Mac
mini using the same command. The workflow is not evidence of an installed or
running GitHub runner. Hosted `macos-latest` is no longer a qualification path.
