# Gate C causal-learning development — 2026-09-04

Status: implementation changes awaiting Apple validation; Gate C remains open.
Base revision: `59892e55eca06dc00d3fb80f0979afd9ef419e26`.
Development branch: `codex/gate-c-causal-learning`.

This change set repairs learning and evaluation defects. It does not establish
physical task success, create a qualified `.nbpolicy`, or authorize promotion.
The acceptance requirements in `NUMANX_GATE_C_REQUIREMENTS.md` are unchanged.

## Changes

### Causal policy-head parity

`MLXEmbodiedPolicyHead` is now the shared implementation used by the learner
and offline intervention evaluator. It reproduces the deployed sixteen-synergy
head relation: pre-transition recurrent state, a validity-gated 24-component
observation sketch folded into sixteen synergies, the belief transform, and the
policy transform. The final eight observation coordinates retain their 0.25
contribution to the first eight synergies.

The ordinary learner previously conditioned this policy loss on the accepted
posterior. It now uses causal prior/observation inputs. Teacher state and
accepted outcomes remain supervision rather than policy inputs. Missing
observations are selected out before arithmetic; availability itself does not
become an additive motor feature. Other slow losses are retained; this is not
a claim that all twenty objectives are now full-fidelity policy optimization.

### Linear-memory temporal learning

`BrainCommittedSequenceIndex` constructs expected-O(N), linear-storage links
using exact UInt64 generations, timestamps, and parameter identity. It rejects
duplicate identifiers/generations, invalid metadata, and overflow. It neither
uses physical ring order nor joins timestamp gaps.

`MLXCommittedSequenceBatch` converts these links to device gathers. Both edges
of a two-step sequence must satisfy the complete validity mask, including the
intermediate record. Missing links select zero rather than multiplying a
potential NaN by zero. The normal learning path no longer materializes N-by-N
adjacency or squares a dense adjacency matrix.

The deprecated adjacency accessors remain explicit diagnostic-only allocations
for source compatibility. Calling one still costs O(N^2) memory. The initializer
now throws; external callers must add `try`. All repository call sites used by
this change are updated.

Metadata decoding occurs only at the existing immutable, shared-storage learner
boundary. There is no added host readback in production stepping. FP32 learning
arithmetic and the existing Metal/MLX ownership split are unchanged.

### Immutable calibration and learner admission

Parameter projection preserves frozen coordinates from the parent after
clipping. A head-posture calibration is therefore restricted to its declared
motor coordinates 3 and 4, rather than allowing magnitude projection to alter
unrelated coordinates. Non-motor parent payload reuse is retained.

Every update requires positive committed generation and at least one fully
valid accepted transition per mind. Empty minds cannot emit sparsity-only
successors or dilute equal-per-mind reductions. The common update boundary also
requires every configured physical objective to have its corresponding
artifact, including cohort calls that previously omitted those artifacts.

### Held-out intervention integrity

`BrainObservationInterventionIndex` supplies deterministic held-out-only donor
indices. Value shuffling is performed within identical three-component
availability signatures. A singleton signature remains unchanged; it must not
be interpreted as evidence of a successful shuffle. Timestamp shifts use only
exact contiguous predecessors that also belong to the selected held-out set.

Both values and validity are shifted. A row with no eligible predecessor is
represented as unavailable evidence, not a valid zero-valued sensor, and no
training-prefix donor is borrowed. All four variants retain the same selected
scoring rows. This boundary behavior is part of the diagnostic protocol, not
a claim that every selected row has an observed delayed measurement.

Reported counts and donors use the full finite/format/version validity mask.
Masked loss evaluation excludes non-finite values in unselected rows but still
rejects a non-finite selected result through the existing report constructor.
Public report formats and the packed enabled-modality ordering are unchanged.

## Verification performed

Environment: Swift 6.2.1, `x86_64-unknown-linux-gnu`.

The two new pure-Core source files and their unchanged repository test files
were compiled in an isolated Swift package: **16 XCTest cases passed, zero
failures** (9 sequence-index cases and 7 observation-intervention cases).
This is not a build or test run of the complete repository.

Coverage includes ring wrap, missing generations, exact timestamps beyond
Float precision, UInt64 overflow, duplicate identities, invalid metadata,
a 100,000-record index, validity-preserving shuffles, deterministic donor
selection, train/held-out isolation, and timestamp discontinuities. The
100,000-record case retains 800,000 bytes across its two Core Int32 arrays;
that figure does not include metadata, dictionaries, tensors, or other batch
storage and is not a total-process memory benchmark.

Swift frontend parsing also passed for the changed/new Swift source and test
files. Parsing is not target-platform type checking.

**12 Apple-side MLX regression tests are authored but not executed here.** They
cover scalar head-reference agreement, all observation coordinates, missing
sensor semantics, causal gradients, frozen-coordinate bit patterns, ordinary
projection, temporal gathers, invalid intermediate rows, masked NaNs,
linear tensor shapes, shifted validity, and masked evaluation.

No macOS build, MLX execution, Metal execution, native bridge run, inference
latency measurement, or new physical rollout was performed in this environment.

## Apple validation and qualification sequence

On the supported Apple host, using the repository's pinned dependencies:

```sh
swift test --filter BrainCommittedSequenceIndexTests
swift test --filter BrainObservationInterventionIndexTests
swift test --filter MLXCausalLearningTests
swift test
```

Then rerun the existing native Gate A/B bridge checks with the required local
NumanX libraries/assets configured. Inspect skipped tests as well as failures;
missing native assets are not a qualification pass.

Capture fresh parent/candidate runs using the documented Gate C commands and
an exact source revision containing these changes. Preserve immutable
parent/learner/artifact identities, the qualified 100-microsecond cadence,
predeclared thresholds, held-out partitions, and rejected-attempt artifacts.
Historical candidate scores must not be relabeled as results of this revision.

Complete the independently sourced training/data requirements and the existing
physical, cross-embodiment, long-horizon, few-shot, OOD, safety, replay, and
latency qualifications. Promote only through the existing verified receipt
path when all required evidence actually passes. These code repairs alone do
not satisfy that path and do not remove remaining physical-policy development.
