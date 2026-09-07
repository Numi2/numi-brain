# Native male-CNS connectome integration

Status: experimental source integration; not an Apple-qualified robot policy.
The implementation starts from NumiBrain `b3ff9883bd42d5274114598e49d01d7e0ae0c538`.
It imports the existing NumiLab `NUMICNS1` graph format instead of inventing
another dataset or placing the neuron graph on a synthetic cortical sheet.

## Owning components

`NumiBrainConnectomeABI` validates the binary graph and projection tables in
C++20. `NumiBrainCore.ConnectomeGraph` retains immutable validated bytes and
provides cold-path neuron-ID and annotation access. `ConnectomeBinding`
compiles receptor and descending-neuron projections against one exact
`CompiledSpeciesTemplate` and parameter publication.

`MetalConnectomeGraph` shares immutable graph data and two compiled pipelines.
Each `MetalConnectomeRuntime` owns three FP32 state buffers, output features,
projection tables and bounded dispatch uniforms. Separate robots may share the
graph allocation but never the recurrent state. All computation is encoded
into the caller's existing Metal 4 pass; there is no second queue, Python
stepping, per-environment host stepping or production neural-state readback.

`MetalJointAgentStateTransaction.encodeConnectome` attaches the optional
participant to the existing cognitive root. The default brain factory is NOT
changed to replace a trained policy with this model.

## Import and inspection

```sh
swift run numi-brain-connectome inspect /path/to/male-cns.numicns
python3 tools/test_connectome_native.py
```

The earlier NumiLab compiler supplies `.numicns` files. Its `.numibody` files
map TaskProgram observations, not NumiBrain receptor arrays. Do not silently
reuse those mappings. This repository does not yet bundle the release
acquisition/compiler path or the multi-gigabyte source data.

The native reader checks bounded ranges, canonical alignment and padding,
unique neuron IDs, finite bounded parameters, destination-major CSR offsets,
ordered unique sources, label encoding, JSON provenance and the interchange
fingerprint. Unknown versions, unsupported nonzero homeostatic parameters and
invalid graphs fail rather than being partially imported. File input is copied
into an owned snapshot so file mutation cannot change a validated graph.
FNV-1a is an integrity checksum, not a signature. Retain original-file and
compiled-pack SHA-256 digests with each experiment.

## Embodiment interface

Construct `ConnectomeReceptorProjection` entries using exact source neuron
IDs plus a modality, receptor index and feature index from the compiled body.
Construct `ConnectomeDescendingProjection` entries using exact annotated
motor/descending IDs and an output channel. Supply both to:

```swift
let binding = try ConnectomeBinding(
  graph: graph,
  template: compiledSpecies,
  parameterVersionFingerprint: publication.version.fingerprint,
  channelCount: channelCount,
  nominalStepMicroseconds: nominalStepMicroseconds,
  integrationStepMicroseconds: integrationStepMicroseconds,
  receptors: receptorProjections,
  descending: descendingProjections
)
```

The named values are application-owned inputs, not fabricated robot anatomy.
The native compiler resolves the same modality-major, receptor-major feature
layout as `MetalSensoryTransductionRuntime`. Each input must target an
annotated sensory or ascending node; each output selects a motor or descending
node. Every output channel must be covered. Missing IDs, roles or sensor
features are errors. Graph, species, sensory-profile and parameter-version
fingerprints are mandatory; matching tensor dimensions are not enough.

NumiBrain expands sensor validity per observation scalar. The connectome reads
`validity[projection.scalar]`, not the receptor's index. An invalid or nonfinite
measurement contributes zero, including its affine bias. This explicit
missing-input policy is not an inferred biological response.

After the owner has produced the root's accepted O(t) sensor frame, call:

```swift
let descending = try root.encodeConnectome(
  mind, encoder: ownerEncoder, sensory: acceptedSensoryFrame
)
```

The root verifies both sensor addresses against its own shadow arena and
requires the same Metal device as the neural buffers. `DescendingView` binds
the resulting channels to the root and exact projection fingerprint. These
are decoder features, NOT actuator commands or writable body state. A reviewed
robot-specific decoder still has to consume the features through the existing
motor/safety/physics path. No automatic humanoid, quadruped or drone skill
transfer is supplied by graph import.

## Time, state and publication

For node i, the implemented signed activity surrogate is:

```
target[i] = tanh(bias[i] + recurrent_gain[i] * sum_j(weight[i,j] * h[j])
                       + sensory_gain[i] * receptor_projection[i])
a[i,dt] = 1 - (1 - alpha[i]) ** (dt / nominal_step)
h_next[i] = clamp(h[i] + a[i,dt] * (target[i] - h[i]), -1, 1)
```

The interval comes from root target time minus committed simulation time, not
wall-clock time. Integration uses the configured bounded substeps and a final
remainder, with accepted O(t) input held throughout the candidate. Communication
reads the previous integration step; this is not a measured axonal delay.
Readout is a weighted sum of selected activities and node output gains,
clamped to [-1, 1]. `legacy_clip` remains in the interchange record but is not
used by this bounded surrogate. The model is not claimed numerically equivalent
to the earlier NumiLab controller or to electrophysiology.

A retry within the same root returns the cached descending view; it does not
reencode or resample the neural decision. Only root publication advances the
neural generation, timestamp and committed state index. Root abort discards the
candidate. Fallible identity checks happen before the existing prepared commit
is published. The original recovery/qualification code is otherwise preserved.

The caller must add `mind.residencyAllocations` to the owner residency set before
submission, retain the mind and sensor arena until GPU completion, and settle
that work before root commit/abort or resource reuse. Encode sensing, neural
execution and dependent decoding on the existing ordered owner timeline. These
APIs do not issue an independent GPU-completion witness.

Fresh zero-state initialization is explicit. Constructing a new mind with a
nonzero generation/time is NOT checkpoint restoration. A connectome participant
is not yet included in cognitive prepared-recovery images: capture rejects an
attached participant rather than silently dropping its state. Existing
cognitive-only committed checkpoints likewise must not be represented as a
complete connectome-agent checkpoint. Full participant checkpoint/recovery and
verified policy-package admission remain integration work before promotion.

## Scientific interpretation and source

The source is the HHMI Janelia / Google male Drosophila CNS dataset:

- https://male-cns.janelia.org/download/
- https://research.google/blog/a-connectomics-milestone-mapping-the-complete-male-fruit-fly-brain/

A population/type graph is a reduction, not the complete neuron graph. Neither
representation supplies missing electrophysiology, neural activity or learned
memories. Synapse counts are not measured functional weights; neurotransmitter
labels alone do not determine all receptor effects. The earlier compiler's
signed, log-normalized weights are a declared surrogate, not measured signs
and strengths for all connections.

## Verification and remaining execution work

The portable suite passes 18 native tests covering binary corruption, every
byte truncation, duplicate IDs, CSR/label ranges, missing identities, dimensions,
projection bounds, channel coverage, nonfinite inputs and time fingerprints.
The actual standalone graph/binding Swift source was compiled, linked to the
C++ library and executed with Swift 6.2.1 on Linux. The earlier NumiLab synthetic
pack retains graph fingerprint `54963d204b21c364` through this reader.

The new Metal-facing Swift source and test files were syntax-parsed, not
Apple-SDK type-checked. `ConnectomeGraphTests` contains package-level core
checks; `MetalConnectomeKernelTests` compares recurrence and readout with a
small mathematical reference, checks fractional timesteps and tests two
features of one receptor with different validity masks. The legacy Metal
encoder in this shader test is test-only; it is not a runtime fallback.

On the Apple target, build the package and run:

```sh
swift test --filter ConnectomeGraphTests
swift test --filter MetalConnectomeKernelTests
```

Those package/Metal tests were NOT executed in the Linux workspace. Root-level
GPU replay, device fault handling, recovery, complete-release execution,
latency/memory profiling and physical robot outcomes are not established by
these portable checks. Robot decoder integration and training have not been
performed. This remains an opt-in experimental module, not a production
replacement for the existing brain policy.
