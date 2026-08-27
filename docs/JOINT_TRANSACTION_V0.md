# NumanX joint transaction contract v0.6

This document defines the first compiled NumiBrain–NumanX handoff boundary.
NumanX retains authoritative physical state; NumiBrain and orchestration retain
only content-addressed tokens that identify the common root, physical
candidates, accepted physical shadows, and final commit.

## Stable ABI

The C++ ABI owns four standard-layout records and field-wise fingerprints:

- `NBJointTransactionToken` (96 bytes) binds environment, episode, control
  step, immutable parameter version, base brain and physics generations,
  committed and target physical timestamps, one brain shadow generation, and
  the root random-counter generation.
- `NBJointSubstepToken` (72 bytes) binds the root fingerprint, accepted-substep
  index, retry-attempt index, start, duration, candidate timestamp, brain shadow
  generation, and unchanged random-counter generation.
- `NBAcceptedPhysicsStateToken` (64 bytes) is NumanX's acceptance proof. It binds
  the root and substep fingerprints to one opaque physical-state fingerprint,
  accepted timestamp, physical generation, and environment.
- `NBJointCommitToken` (64 bytes) binds the accepted physical proof to the new
  brain and physics generations, committed timestamp, parameter version, and
  environment.

Fingerprints mix fields explicitly in little-endian order and never hash struct
padding. Validation rejects version, identity, time, generation, flag,
fingerprint, and cross-record relation drift.

## Coordinator state machine

`BrainJointTransaction` starts from one immutable root token and implements:

```text
open root
  -> begin candidate
  -> reject -> same accepted time, substep index, shadow, and random generation
  -> retry
  -> accept NumanX token -> advance accepted time and physical generation
  -> repeat until target time
  -> validate final NumanX token
  -> issue joint commit receipt
```

Only an accepted physical token advances the root shadow. A rejection changes
only the diagnostic attempt counters. Commit requires no active candidate, at
least one accepted physical state, and exact arrival at the root target.
Abort clears candidate and accepted shadow metadata and restores base time and
physical generation in the coordinator value.

## Deterministic retry

The retry-attempt index is diagnostic and may change. The root transaction,
accepted-substep index, brain shadow generation, and random-counter generation
remain unchanged. Random sampling must therefore key from the root identity,
accepted-substep index, module, and sample index rather than the attempt index
or substep fingerprint.

## Metal root binding

`MetalTissueRuntime.beginJointControl` creates a root token directly from the
runtime's committed scheduler generation, committed tissue step, immutable
parameter version, environment, and counter-random episode. The coordinator
retains an ordered resolution ledger containing every rejected and accepted
candidate.

`runJointRootTransaction` validates that:

- the root still matches the Metal environment, parameter version, committed
  brain generation, physical time, and random generation;
- the ledger counters exactly match its accepted and rejected records;
- only accepted records advance the target time;
- every candidate duration is positive and no larger than the nominal tissue integration timestep;
- the final accepted NumanX token reaches the root target.

The Metal root then encodes the exact ledger. An ordinary brain-only commit is
disabled while that root is pending. `commitJointRootTransaction` validates the
final physical token, publishes the tissue, scheduler, token, route-history,
and routing-state generations, and returns the compiled joint receipt. Root
abort publishes none of those neural generations and clears the pending joint
binding.

Each resolution can also carry canonical receptor-derived interrupt events
whose timestamps lie strictly after candidate start and no later than candidate
end. Untransduced or out-of-window events are rejected by the coordinator.
Metal merges events only from accepted resolutions into the private root event
path; events attached to rejected physical candidates remain transaction-local
diagnostics and never reach scheduling or committed neural history.

## Interactive Metal candidates

`MetalTissueRuntime` also exposes an interactive reference path:

```text
beginInteractiveJointControl
  -> advanceFastSystems
  -> NumanX candidate step
  -> acceptPhysicsSubstep | rejectPhysicsSubstep
  -> repeat until the root target
  -> finishInteractiveJointControl
  -> commitJointRootTransaction | abortRootTransaction
```

`advanceFastSystems` executes event compaction and one tissue candidate on
Metal before physical acceptance is known. The candidate writes a private
tissue generation and the inactive owner of its conduction-history value and
timestamp slot. Corrected durations may shrink from the nominal timestep; the
shader resolves configured delay classes against physical microseconds and
interpolates accepted timestamp brackets.
Acceptance advances the root-shadow state pointer, history-owner bit, accepted
time, and joint ledger, then dispatches one canonical scheduler/regional prefix
from the untouched committed generation through the accepted timestamp. This
makes accepted receptor interrupts available before the next candidate while
preserving a bit-exact abort source. Rejection drops the candidate identity and
dispatches no scheduler/regional prefix, so the latest accepted fast shadow is
unchanged and the retry recomputes tissue from the previous accepted state.
Neither path publishes committed state.

Each accepted prefix includes all accepted substep events from the root start,
so bounded v0.6 execution recomputes a canonical prefix rather than mutating
the committed generation incrementally. After the final accepted physical
token reaches the target, `finishInteractiveJointControl` binds that fast
shadow and the accepted tissue shadow to the joint-only commit guard. A final
prefix is recomputed only when the caller supplies additional host-only events
at finish. The resulting commit receipt remains the only publication point.
Interactive abort, including abort with an active GPU candidate, publishes no
tissue, scheduler, token, delayed-route, routing, time, or random-counter
history.

The reference implementation deliberately synchronizes the host after each
candidate Metal submission so an external physical solver can return its
acceptance token. This proves state ownership and retry semantics; it is not a
no-readback cross-runtime command timeline.

## Current boundary

The compiled ABI, validation, fingerprints, Swift value wrappers, transaction
state machine, exact attempt/event ledger, accepted-event filtering, bounded
ledger encoder, and interactive Metal candidate lifecycle are implemented and
covered by deterministic CPU and Metal tests. The interactive and batched
paths produce exact matching committed tissue, scheduler, recurrent-token,
delayed-route, and routing-state fingerprints.

There is no live NumanX adapter or demonstrated atomic physical/brain pointer
publication yet. Accepted receptor events reach a fast scheduler/regional
shadow after physical acceptance and before the next candidate; they cannot
alter the physical candidate that has already been accepted, and no protective
motor-output adapter exists yet. The timestamped Metal history is bounded to 32
accepted samples; a corrected-duration candidate fails before dispatch if
accepting it would erase the only bracket required by the maximum configured
delay. Cross-runtime command coordination and protective output remain required
before this boundary can claim working NumanX coupling.
