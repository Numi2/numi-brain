# NumanX joint transaction contract v0.4

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
- every bounded v0.2 attempt uses the fixed tissue integration timestep;
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
tissue generation and the inactive owner of its conduction-history slot.
Acceptance advances only the root-shadow state pointer, history-owner bit,
accepted time, and joint ledger. Rejection drops the candidate identity and
leaves those authoritative shadow values unchanged, so the retry recomputes
from the previous accepted state and overwrites scratch output. Neither path
publishes committed state.

After the final accepted physical token reaches the target,
`finishInteractiveJointControl` transduces only accepted receptor events and
executes the scheduler and regional-token pass. It binds those shadows and the
accepted tissue shadow to the existing joint-only commit guard. The resulting
commit receipt is therefore still the only publication point. Interactive
abort, including abort with an active GPU candidate, publishes no tissue,
scheduler, token, delayed-route, routing, time, or random-counter history.

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
publication yet. Fast receptor events are retained on accepted substep records
but reach the scheduler/regional path only during root finalization, not during
the candidate. Candidate duration must equal the compiled tissue timestep;
conduction history is still indexed by accepted steps, so accepting a corrected
variable duration would silently change delay semantics. Cross-runtime command
coordination, substep-time protective response, and physically timestamped
conduction history remain required before this boundary can claim working
NumanX coupling.
