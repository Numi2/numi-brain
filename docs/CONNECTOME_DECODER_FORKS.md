# Decoder-only experiment forks

Use a retained **complete** brain checkpoint and the matching physical-owner
checkpoint for paired decoder probes. Recreating a seed or matching one sensor
value does not reproduce recurrent state, memory, controller filters or solver
history.

`MetalConnectomeDecoderFork.prepare` is a cold, device-independent checkpoint
transformation. It recompiles both controller specifications, compares the
actual graph bytes and all frozen operator settings, and changes only the
connectome decoder's program identity and its containing checksums. It preserves
cognitive hot state, persistent memory, all fast-tissue buffers, neural activity,
physical-checkpoint identity, timestamps, generations and random context exactly.
It rejects changes to the graph, receptors, readouts, integration step, nominal
step, maximum logit, actuator shape or shared parameter publication.

The owning `MetalNumiBrainHandle.createConnectomeDecoderFork(from:...)` factory
additionally validates the entire runtime configuration and restores an isolated
child runtime before returning it. No existing parent handle is touched on
success or failure. The fork always starts from the supplied retained snapshot,
not from any later state of a running parent. Both probes must receive the same retained checkpoint bytes;
serialized key ordering is not used as a substitute for snapshot identity.

```swift
let source = try parent.saveCheckpoint(
  controlStepIdentifier: controlStep,
  physicalCheckpointFingerprint: physicalFingerprint
).encoded()
let negative = try MetalNumiBrainHandle.createConnectomeDecoderFork(
  from: source, configuration: parentConfiguration, publication: publication, identifier: "negative", specification: negativeSpec,
  physicalCheckpointFingerprint: physicalFingerprint,
  physicalData: physicalOwnerCheckpointBytes
)
let positive = try MetalNumiBrainHandle.createConnectomeDecoderFork(
  from: source, configuration: parentConfiguration, publication: publication, identifier: "positive", specification: positiveSpec,
  physicalCheckpointFingerprint: physicalFingerprint,
  physicalData: physicalOwnerCheckpointBytes
)
try negative.fork.identity.validatePairedInitialization(with: positive.fork.identity)
```

The named physical checkpoint bytes and fingerprint come from the application's
physical owner, not fabricated placeholders. Restore those bytes into **two
separate physical-world instances** through that owner's validated restore API
before advancing either child. NumiBrain neither interprets nor restores the
external physical bytes. A hash equality proves byte equality, not that a world
actually loaded them; retained physical execution captures must establish that.

Environment and episode identifiers are deliberately unchanged for paired
common-random-number experiments. Child GPU state and mutable memory are not
shared. Use different fork/run identifiers for artifact namespaces; never treat
these correlated probes as independent random-seed evaluations.

Retain the identity JSON, exact source and target brain bytes, physical bytes,
source/target controller specifications and graph with each study. The identity
binds every content SHA-256 and source generation. Its `promotable` field is
always false. `validatePairedInitialization` rejects different memory/physical
snapshots, publication/topology drift, duplicate run IDs and identical probes.
It is preflight, not a policy-admission or physical-execution receipt.

This explicit operation does not relax ordinary checkpoint loading or parameter
successor migration. Loading an old program's checkpoint into a changed decoder
still fails outside the fork path. Changing the body or learned neural operator
requires a different explicitly designed migration, not this decoder-only API.

Verification scope: `ConnectomeDecoderForkTests` exercises byte preservation,
paired identities, nonfinite/shape/operator rejection and import budgets without
allocating a Metal device. Full child runtime restoration/trajectory checks must
run on Metal 4 hardware with native physical-owner checkpoint restoration. The
existing specialized physical-capture CLI is not implicitly taught to restore
another world's checkpoint by this API.
