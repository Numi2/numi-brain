# Physical-outcome learning for the connectome decoder

This is a research-only learning path for the actual actuator-major matrix in
`ConnectomeControllerSpec`, not the unrelated shared `.motor` gains. The
released graph, neuron properties, sensory projections and descending-neuron
selection remain frozen. MLX computes bounded decoder probes and updates
outside a rollout; the existing Metal/NumanX owner still performs all sensing,
neural evolution, motor conversion, safety handling and physical stepping.

## One complete experiment step

Start with a retained `capture-connectome` run made by this source revision.
It must have accepted every root and contain format-3 controller provenance.
Old captures that merely left a decoder file in the artifact directory cannot
be relabeled as verified decoder-learning evidence.

1. Freeze `ConnectomeDecoderStudySettings` with `freeze-connectome-settings`.
   Set `calibrationSettingsSHA256` in the physical protocol to the returned
   settings artifact hash, then retain the protocol with `freeze-protocol`.
2. Run `study-connectome` using that protocol, the parent capture hash and two
   complete native capture configurations with distinct run identifiers.
   Their `connectomeSpecificationPath` values must be null: the frozen probe
   plan supplies the two specifications. Graph paths must name the same graph.
3. Read the retained proposal. `candidateSpecificationSHA256` names a directly
   loadable controller JSON artifact. Evaluate it in a fresh `capture-connectome`
   run and with `evaluate-connectome`, then compare with an independently run
   parent and held-out conditions. A finite-difference proposal is not evidence
   of improvement and does not replace an admitted production policy.

The explicit entrypoint is:

```sh
swift run -c release numi-brain-experiment study-connectome --config study.json
```

`study.json` has the following fields; hashes and native paths come from the
existing capture and frozen protocol, not from arbitrary example identifiers:

```text
artifactDirectory
parentRunSHA256
protocolSHA256
settings
negativeCapture
positiveCapture
```

Each nested capture uses the existing `CaptureInput` fields: artifactDirectory,
protocolSHA256, publicationSHA256, runIdentifier, nativePaths,
connectomeGraphPath, connectomeSpecificationPath, watchdog and watchdogLifecycle.
Both captures use the same artifact directory, protocol and shared publication.
The `nativePaths` keys are library, rigid, muscle, contacts, visualPack,
visionProfile, metalRoboMetallib, matterMetallib and material. A configured
watchdog requires its own valid owner/lifecycle configuration for each run;
the study never disables it or fabricates an arming record.

The settings fields are coordinates, directionSeed, probeRadius, learningRate,
gradientLimit, trustRadius, magnitudeLimit and minimumResolvableLossDifference.
Coordinates must be sorted, unique and in range. Weight coordinate for actuator
`a` and descending channel `c` is `a * channelCount + c`; the bias coordinate is
`decoderWeights.count + a`. At most 65,536 coordinates are perturbed per study.
The seed determines repeatable signs independently of every mind's RNG.

The same workflow is available as separate commands for external orchestration:

```sh
numi-brain-experiment probe-connectome --config probes.json
numi-brain-experiment capture-connectome --config negative.json
numi-brain-experiment capture-connectome --config positive.json
numi-brain-experiment evaluate-connectome --config negative-evaluation.json
numi-brain-experiment evaluate-connectome --config positive-evaluation.json
numi-brain-experiment calibrate-connectome --config update.json
```

`probes.json` contains artifactDirectory, parentRunSHA256, protocolSHA256 and
settings. `update.json` contains artifactDirectory, probePlanSHA256,
negativeEvaluationSHA256 and positiveEvaluationSHA256. Probe plan fields
negativeSpecificationSHA256 and positiveSpecificationSHA256 resolve to
`<artifactDirectory>/<hash>.artifact`; those files are controller specifications.
The evaluation CLI retains its report and returns exit code 1 when the task
criterion is not met. The combined study can still use a valid, fully accepted
but unsuccessful task trajectory to compute a research proposal.

## Exact evidence and admission boundaries

The native owner now records graph bytes, canonical decoder JSON and the exact
compiled body as transitive artifacts of the run. The capture identity also
includes the topology, binding, decoder program, whole-brain program and shared
parameter publication. Each terminal execution transcript names the actual
connectome and brain programs used by its owning runtime. The verifier
recompiles retained graph/spec/body data and checks those identifiers against
every root. Missing files, changed bytes, a different body, substituted decoder,
or relabeling a connectome execution as a legacy run are errors.

Legacy v2 capture bytes and legacy execution bytes remain readable. Research
v3 records cannot lose their controller record and remain valid. The default
capture verifier rejects research-controller runs; `evaluate-connectome` opts
into the research scope. The legacy physical gain calibrator rejects these
receipts even when a caller explicitly obtained one. Hashes provide integrity
and provenance relations, not a signature or attestation of an external host.

An update rereads both evaluation artifacts, recomputes their physical metrics
from the retained native run evidence, and verifies the exact probe plan. Both
runs must use the same frozen protocol, parameter publication, physical model,
proof program and device. They must have no rejected roots, equal initial
observed relative head height, and a resolvable finite loss difference. This is
a strict matched-initialization experiment, not proof of identical complete
initial physical checkpoints. In particular, the observed-height check may
reject a pair whose earliest measured states already differ; do not bypass it
by editing retained measurements.

## Numerical contract

For selected coordinate `j`, a deterministic sign `d[j]` is -1 or +1:

```text
negative[j] = parent[j] - probeRadius * d[j]
positive[j] = parent[j] + probeRadius * d[j]
g[j] = (positiveLoss - negativeLoss) / (positive[j] - negative[j])
step[j] = clip(learningRate * clip(g[j], -gradientLimit, gradientLimit),
               -trustRadius, trustRadius)
candidate[j] = clip(parent[j] - step[j], -magnitudeLimit, magnitudeLimit)
```

The denominator uses the actual representable probe values. This is a noisy
paired-direction estimate, not the exact gradient of all coordinates from two
runs. No convergence, optimality, sample-efficiency or statistical-significance
claim is inferred from a single pair. Probes requiring asymmetric clipping,
nonfinite differences and unresolvable changes are rejected. The trust radius
bounds each parameter change, not robot motion or objective change. Unselected
coordinates remain bit-identical. Recompilation must confirm unchanged neural
topology and a changed decoder identity before a proposal is retained.

The candidate JSON is a new immutable rollout configuration. It does not alter
an active cohort, silently migrate a checkpoint to another decoder, or acquire
production qualification. Every proposal is explicitly `promotable: false`.

## Actual scope

The generic controller can bind different compiled actuator bodies. The current
physical experiment runner remains the existing 416-muscle native full-body
model, and its existing reach/hold objective measures relative head height.
This increment does not claim that a wheeled robot, quadruped or humanoid has
learned locomotion, that the imported fly is biologically reproduced, or that
the body-specific sensor/readout assignments have been behaviorally validated.
It provides the executable outcome-based decoder-learning path and its evidence
checks, not a trained checkpoint or a measured task result.

For checks of the actual source, sparse shader and learner arithmetic:

```sh
NUMIBRAIN_CONNECTOME_GRAPH=/absolute/path/to/male-cns-v1.0-neuron-unsigned.numicns \
  python3 tools/run_connectome_apple_tests.py --with-learning
```

For the strict full normal-root scope, additionally pass `--require-metal4` on
a Metal 4-capable Apple machine. A legacy test encoder can test the sparse
shader but cannot qualify the production Metal 4 owner. CI retains those claims
separately rather than turning unavailable hardware into a passing root result.
