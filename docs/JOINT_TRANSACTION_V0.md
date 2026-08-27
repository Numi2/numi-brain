# NumanX joint transaction contract v0.1

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

## Current boundary

The compiled ABI, validation, fingerprints, Swift value wrappers, and
transaction state machine are implemented and covered by deterministic tests.
The current Metal tissue API is not yet bound to these tokens, and there is no
live NumanX adapter or demonstrated atomic physical/brain pointer publication.
Those are the next interop steps; this contract alone is not a claim of working
NumanX coupling.
