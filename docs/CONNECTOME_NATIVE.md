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

## Pinned full-neuron acquisition

The importer now resides in this repository. It is offline preparation, not a
Python runtime. Dependencies and all three official input sizes/SHA-256 digests
are pinned in `tools/connectome-requirements.txt` and
`Contracts/MaleCNS_v1.sources.json`.

```sh
python3 -m pip install -r tools/connectome-requirements.txt
python3 tools/import_male_cns.py fetch --cache /absolute/path/male-cns-cache
python3 tools/import_male_cns.py compile --cache /absolute/path/male-cns-cache --output /absolute/path/male-cns-v1.numicns
```

Compilation preserves isolated catalog neurons and every retained neuron-pair
edge at the default threshold of one anatomical synapse. The report separates
anatomical counts from assumed signed weights. Uncertain/modulatory transmitter
classes have zero default functional weight, but their structural edges remain
present. This is an explicit incomplete physiology model, not an assertion that
these neurons have no function. The companion `.ports.csv` exposes real neuron
IDs, annotations, side and interface-role flags for reviewed sensor/readout maps.

The retained full-data run selected **167,216 neurons**, **25,587,572 directed
neuron-pair edges**, and **124,193,283 anatomical synapse counts**. These are
counts under the importer's recorded annotation selection, not a replacement
for the publication's independently defined proofreading counts. The pack is
216,220,498 bytes with SHA-256
`db2a30c4d4989ff036733d72764b06c08988cd97016774e68d91421b6bf6a647`.
See `evidence/connectome-full-v1/` for the exact report and executed import logs.

## Normal launch, teacher capture and decoder learning

Launch version **2** adds explicit `actuate` and `observeTeacher` execution
modes. Regenerate earlier version-1 launches; old layouts are not silently
reinterpreted. In observation mode the ordinary somatic controller remains
active while the connectome advances in the same transactional arena. The
connectome receives receptor data only, never teacher actions as sensory input.
The two modes have different program/checkpoint identities.

Build the actual frontends and the pinned MLX runtime resource:

```sh
swift build -c release --product numi-brain-experiment
swift build -c release --product numi-brain-connectome
sh tools/build_swiftpm_mlx_metallib.sh release
```

`numi-brain-experiment describe-native --config FILE` opens the configured native
NumanX bridge, compiles the actual anatomy without stepping physics, and retains
the compiled species template plus a developmental-seed parameter publication.
The result gives `artifactSHA256` (template), `publicationSHA256`, and
`nativeModelSourceFingerprint`. Its configuration contains `artifactDirectory`,
`timestepMicroseconds`, and the existing `nativePaths` object. That object names
absolute paths for `library`, `rigid`, `muscle`, `contacts`, `visualPack`,
`visionProfile`, `metalRoboMetallib`, `matterMetallib`, and `material`; an optional top-level
`authoredMatterWorld` object (`packagePath`, `humanSourceFingerprint`, and
`worldFingerprint`) uses the main branch's exact authored-Matter loader. The native
bridge currently supplies its full-body transport anatomy. Other robot owners
supply their own exact `CompiledSpeciesTemplate` to the same generic brain
factory; this command does not invent or convert their mechanics.

`numi-brain-connectome prepare --config FILE` creates a zero-decoder
**teacher-observation** launch, not a working untrained robot policy. Its JSON
configuration has this schema (replace the explicitly named inputs with the
actual paths/hashes and reviewed neuron bindings):

```json
{
  "context": {
    "artifactDirectory": "/absolute/path/artifacts",
    "graphPath": "/absolute/path/male-cns-v1.numicns",
    "graphSHA256": "db2a30c4d4989ff036733d72764b06c08988cd97016774e68d91421b6bf6a647",
    "compiledSpeciesSHA256": "SHA256_FROM_DESCRIBE_NATIVE",
    "publicationSHA256": "SHA256_OF_THE_TEACHER_PUBLICATION"
  },
  "channelCount": 1,
  "nominalStepMicroseconds": 20000,
  "integrationStepMicroseconds": 1000,
  "maximumSubsteps": 256,
  "maximumDriveChangePerSecond": 2,
  "receptors": [],
  "descending": []
}
```

The empty arrays intentionally fail validation until real port mappings are
provided. Each receptor entry has `neuronIdentifier`, numeric `modality`,
`receptorIndex`, `featureIndex`, `weight`, `scale`, `bias`, and `clip`. Each
readout entry has `neuronIdentifier`, `channel`, and `weight`. There is no
scientifically defensible universal fly-neuron-to-arbitrary-robot mapping, so
no random selection is mislabeled as measured anatomy.

Use the returned launch SHA in the ordinary experiment `capture` configuration:

```json
"connectome": {
  "graphPath": "/absolute/path/male-cns-v1.numicns",
  "graphSHA256": "db2a30c4d4989ff036733d72764b06c08988cd97016774e68d91421b6bf6a647",
  "launchSHA256": "SHA256_FROM_PREPARE"
}
```

Everything else follows the existing `freeze-protocol` / `capture` / `evaluate`
workflow. The runner validates the launch against the anatomy it actually loaded.
In teacher mode, only successfully published roots are paired with committed
connectome readouts. The exact existing semantic descending-action artifact is
the target. These small offline readouts use the existing state owner's range
copy and completion machinery, not a new stepping queue. Rejected roots remain
in the native transcript and never enter teacher rows. A completed capture
returns `connectomeTrainingSHA256` as well as its native run SHA.

Collect distinct training and held-out **episodes**, then run
`numi-brain-connectome train --config FILE`. Its configuration contains `context`
as above, `teacherLaunchSHA256`, arrays `trainingRunSHA256` and
`heldOutRunSHA256`, and `settings`:

```json
"settings": {
  "iterations": 200,
  "learningRate": 0.02,
  "l2": 0.0001,
  "gradientLimit": 1,
  "parameterLimit": 16
}
```

The loader reuses the transitive native capture verifier and checks accepted
outcomes, exact action bytes, episode, timestamp and committed generation for
every row. It rejects repeated roots and any episode appearing in both splits.
Distinct episode IDs alone do not establish distinct scenes/seeds; configure
those independently when testing transfer. This data validation does not issue
a policy-admission receipt.

MLX performs bounded, deterministic full-batch regression in the decoder's
inverse-activation domain. Graph and receptor mappings do not change. Per-row
weight mass stays below the C++ decoder limit; no held-out values affect update
steps or stopping. Before/after action MSE for both splits is retained. These
are unslewed decoder-fit metrics, not closed-loop task success or guarantees
about protected physical commands. A neutral/no-improvement dataset does not
publish a purported learned candidate.

Training returns a content-addressed result and an **actuation-mode candidate
launch**. Both remain unqualified research artifacts. Launch the candidate in a
fresh episode through the same `capture` configuration and evaluate physical
outcomes with the existing experiment evaluator. The teacher checkpoint is not
silently restored into a different decoder or execution mode. Full checkpoint
resume within the exact same graph/body/decoder/mode remains supported.

`numi-brain-connectome validate-launch --config FILE`, using `context` and
`launchSHA256`, checks the full binding without advancing any body or neural
state. It does not claim the controller is trained, biologically accurate or
safe for real hardware.
