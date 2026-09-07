# Native male-CNS connectome controller

This is an opt-in, connectome-grounded **rate-model controller**, not an
emulation of all measured fruit-fly physiology and not a pretrained robot skill.
The standard NumiBrain controller remains unchanged when no connectome is supplied.

## One runtime and one state owner

`NumiBrainConnectomeABI` validates `NUMICNS1` graph packs and decoder values in
C++20. `ConnectomeGraph` owns a validated byte snapshot. `ConnectomeBinding`
resolves annotated sensory/ascending neurons against an exact compiled robot's
receptor layout and selects annotated descending/motor readout neurons.
`ConnectomeMotorDecoder` maps those readouts to the robot's existing normalized
actuator-drive domain, with a bounded command-change rate.

`ConnectomeProgram` binds graph, projection, decoder, physical integration
intervals and dispatch capacity. Configure it through
`MetalNumiBrainConfiguration(connectomeProgram: program, ...)` using the normal
owning handle/factory. Both synchronous and asynchronous decision paths run it
after receptor transduction and before the existing motor-inhibition stage.
There is no separate physics loop or connectome command queue.

The optional `.connectomeState`, `.connectomeReadout` and `.connectomeControl`
sections live in the **existing complete hot-state arena**. They participate in
normal shadow copy, root commit/abort, committed checkpoint, and prepared GPU
recovery. Temporary integration buffers have no persistent authority. The old
manual `root.encodeConnectome` participant API has been removed.

The complete program fingerprint participates in the hot-layout fingerprint.
Consequently equally shaped graphs or different decoders cannot restore one
another's checkpoints or reuse a different NumanX program identity. Layouts
without a connectome retain their previous fingerprint and section list.
Independent minds have independent state; a weak device cache shares only
immutable graph buffers and pipelines. Cache hits compare complete graph bytes.

## Physical command path

The decoder replaces voluntary somatic drive only in connectome mode. Existing
hyperdirect stop, physiological and risk inhibition, developmental strength,
protective reflexes and physical actuator conversion remain active. Invalid
neural outputs select neutral drive rather than falling back to another policy.
Generic voluntary communication, locomotor CPG and cerebellar residual outputs
are not added as a competing policy. Vital autonomic oscillators remain active.
The existing root coordinator caches the decision across physical retries.
No direct writes to authoritative poses, velocities or contact forces are added.

Decoder logits use the native command normalization: `max(tanh(x),0)` for
muscle excitation; `0.5*(tanh(x)+1)` for other actuator kinds. Per-actuator neutral
and emergency values remain owned by `SpeciesTemplate` and the physical adapter.
The decoder's previous drive and validity are checkpointed, making slew limiting
repeatable after restart. Safety can override the voluntary slew limit.

## Exact body binding

Use `ConnectomeReceptorProjection` with a source neuron identifier, modality,
receptor index and feature index. Use `ConnectomeDescendingProjection` with a
source neuron identifier and readout channel. Bind them through:

```swift
let binding = try ConnectomeBinding(
  graph: graph, template: compiledSpecies,
  parameterVersionFingerprint: publication.version.fingerprint,
  channelCount: channelCount,
  nominalStepMicroseconds: nominalStepMicroseconds,
  integrationStepMicroseconds: integrationStepMicroseconds,
  receptors: receptorProjections, descending: descendingProjections)
let decoder = try ConnectomeMotorDecoder(
  binding: binding, template: compiledSpecies,
  weights: learnedWeights, bias: learnedBias,
  maximumDriveChangePerSecond: maximumDriveChangePerSecond)
let program = try ConnectomeProgram(graph: graph, binding: binding, decoder: decoder)
```

Names above are application-owned values, not fabricated neuron or robot
anatomy. `ConnectomeLaunch` serializes the semantic mappings, decoder and exact
identities; loading it recompiles and verifies them. Missing nodes, unannotated
ports, incorrect receptor-feature relations, unsupported dimensions, nonfinite
weights, uncovered readout channels or stale identities are rejected.

NumiBrain validity is **per observation scalar**, not per receptor. Invalid or
nonfinite sensory measurements contribute zero, including their affine bias.
The previous NumiLab `.numibody` files use a different TaskProgram observation
layout and cannot be silently substituted for these bindings.

## Dynamics and import

```sh
swift run numi-brain-connectome inspect /path/to/male-cns.numicns
python3 tools/test_connectome_native.py
```

The initial `NUMICNS1` interchange is retained. Neuron and reduced population
packs are distinguished. No tissue-grid adjacency is invented. The numerical
model is explicitly:

```
target_i = tanh(bias_i + recurrent_gain_i * sum_j(w_ij*h_j)
                       + sensory_gain_i * sensory_projection_i)
a_i(dt) = -expm1(log1p(-alpha_i) * dt/nominal_step)
h_i_next = clamp(h_i + a_i(dt)*(target_i-h_i), -1, 1)
```

`alpha=1` is handled separately. Updates read the previous integration state;
this is not measured axonal conduction delay. Root simulation time determines
substeps, including a final remainder, and accepted O(t) is held throughout the
candidate. Readouts are bounded weighted sums. Nonfinite recurrence or readout
is propagated to the decoder's invalid-state handling, not silently clamped
into a plausible observation. `legacy_clip` is not used; nonzero unsupported
homeostatic fields are rejected.

The source is HHMI Janelia / Google Male CNS:
https://male-cns.janelia.org/download/
https://research.google/blog/a-connectomics-milestone-mapping-the-complete-male-fruit-fly-brain/

Retain the release files' SHA-256 hashes, annotations, filtering and weight
transformation with each compiled pack. FNV-1a is only interchange integrity,
not authentication. Synapse counts and transmitter labels do not determine all
functional weights or receptor effects. Population reductions must not be
reported as complete individual-neuron graphs.

## Qualification boundary

A cortical policy-package receipt cannot authorize a new connectome program;
verified factory admission rejects that substitution. Changing the parent
parameter publication requires a newly compiled binding/program, not relabeling
old weights. Graph import and a decoder do not establish robot task success.

Portable native tests validate graph corruption handling and decoder contracts.
Apple tests include `ConnectomeGraphTests`, `MetalConnectomeKernelTests` and
`MetalConnectomeIntegrationTests`; the last exercises the actual GPU arena,
abort isolation, committed checkpoint/restore, decoder identity rejection and
continued root replay. Its physical tokens and receptor observations are
explicitly synthetic. A missing GPU is a failure of execution qualification,
not a successful skipped test. Refer to retained CI logs for executed results;
source presence alone is not a measured outcome.
