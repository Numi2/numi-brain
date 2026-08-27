# NumanX joint transaction contract v0.9

This document defines the first compiled NumiBrain–NumanX handoff boundary.
NumanX retains authoritative physical state; NumiBrain and orchestration retain
only content-addressed tokens that identify the common root, physical
candidates, accepted physical shadows, and final commit.

## Stable ABI

The C++ ABI owns four standard-layout transaction records plus one output
record, all with field-wise fingerprints:

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
- `NBProtectiveCommand` (64 bytes) binds one accepted brain generation and
  timestamp to its interrupt mask, bounded withdrawal, bracing,
  motor-inhibition, and autonomic-arousal drives, environment, and flags.

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
so bounded v0.9 execution recomputes a canonical prefix rather than mutating
the committed generation incrementally. After the final accepted physical
token reaches the target, `finishInteractiveJointControl` binds that fast
shadow and the accepted tissue shadow to the joint-only commit guard. A final
prefix is recomputed only when the caller supplies additional host-only events
at finish. The resulting commit receipt remains the only publication point.
Interactive abort, including abort with an active GPU candidate, publishes no
tissue, scheduler, token, delayed-route, routing, protective-command, time, or
random-counter history.

After every accepted scheduler/regional prefix, `derive_protective_command`
unions the accepted interrupt invocations and reads emergency/spinal diagnostic
salience. It writes a fingerprinted command into the private generation paired
with that prefix. The next `advanceFastSystems` result exposes the command as a
GPU buffer address, byte count, physical timestamp, and brain generation. The
first candidate receives the committed idle command. Rejected events launch no
derivation and cannot alter the latest accepted command. Commit publishes the
paired command generation; abort restores the prior committed generation.

The command is deliberately species neutral. A body adapter must translate its
drives into muscle excitation, autonomic input, or a robot actuator contract.
The command does not write NumanX state directly.

The first compiled adapter now maps that command through an immutable ordered
muscle profile. Each 32-byte channel supplies a stable muscle identifier,
resting excitation, withdrawal and brace gains, and a maximum. Metal writes a
fingerprinted 64-byte header plus a private FP32 protective-excitation array
paired with the command generation. The following candidate receives GPU
addresses and identity metadata for both buffers. Rejection, abort, and commit
apply to command and excitation generations together.

The standalone interop executable binds one ordered output channel to every
source muscle loaded from the NumanX `.nhmyo` asset. The first six retain the
foundation fixture gains; all later channels are explicit valid zero-rest,
zero-gain entries. The full 416-record identity and output fingerprint match
the physical consumer. A separate immutable catalog binds each source tendon
to its ordered first and terminal route-site body identifiers and local
coordinates without claiming anatomical proximal/distal or body-side meaning.

For each candidate, `NBNumanXMotorCandidate` binds the root and substep
fingerprints to the accepted brain time/generation and the private motor-header
and excitation GPU addresses. The compiled validator checks environment,
random-counter generation, expected base-versus-shadow generation, alignment,
byte counts, muscle count, and the complete transaction-local fingerprint. GPU
addresses are ephemeral and never become checkpoint or replay identity.

The reference implementation deliberately synchronizes the host after each
candidate Metal submission so an external physical solver can return its
acceptance token. This proves state ownership and retry semantics; it is not a
no-readback cross-runtime command timeline.

The runtime lends the exact resident header and excitation `MTLBuffer` objects
for the still-live physical candidate. The lease retains their object lifetime
and exposes opaque process-local handles without reading their contents. The
bounded NumanX bridge imports the excitation allocation into its own MyoSim
command buffer and returns the candidate physical fingerprint and generation
used to construct the accepted-physics token before the brain can advance or
recycle the generation.

## Current boundary

The compiled ABI, validation, fingerprints, Swift value wrappers, transaction
state machine, exact attempt/event ledger, accepted-event filtering, bounded
ledger encoder, and interactive Metal candidate lifecycle are implemented and
covered by deterministic CPU and Metal tests. The interactive and batched
paths produce exact matching committed tissue, scheduler, recurrent-token,
delayed-route, and routing-state fingerprints.

The temporal-body-field joint-root executable at NumiBrain `4f8c220` and
isolated NumanX `5cdee51` passes the actual ordered 416-channel private excitation
allocation to MyoSim, advances an
articulated Core candidate, transduces the accepted peak actuator force with
its source-tendon and endpoint-body identity, binds that observation to the
accepted-physics and attachment-catalog fingerprints, publishes it only after
root commit, derives a commit-bound sparse body-load frame and 37-channel
endpoint-sharing neighborhood, materializes the same peak endpoint loads into
a private Metal body field, retains and linearly decays them across committed
roots, inhibits the overloaded source channel until its field cell expires,
grows commanded activation from a
zero-activation start, changes the next neural output, rejects and exactly
replays one physical candidate, and publishes both roots. Accepted receptor
events reach the fast scheduler/regional shadow only after physical acceptance
and before the next candidate; they cannot alter the candidate already
accepted. The timestamped Metal history is bounded to 32 accepted samples; a
corrected-duration candidate fails before dispatch if accepting it would erase
the only bracket required by the maximum configured delay.

This remains a reference bridge rather than Phase 1 completion. NumiBrain and
NumanX synchronize separate Metal queues, the MyoSim result is staged for
diagnostics, Core articulated integration is CPU-side, and root publication is
sequential rather than one atomic GPU pointer swap. Anatomical/body-side
semantics, intermediate route-body export, a body-schema receptor field,
NumanX-generated adaptive substep rejection, shared GPU timeline, calibrated
vulnerability, damage, recovery and uncertainty dynamics, anatomical neighbor-
directed protection, and composition with voluntary control remain required.
