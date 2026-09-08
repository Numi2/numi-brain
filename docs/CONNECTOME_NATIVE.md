# Male-CNS controller in NumiBrain

The native controller is integrated with the ordinary NumiBrain factory,
synchronous and asynchronous decision paths, protected actuator decoding,
joint publication, complete committed checkpoints and prepared recovery.
It is an opt-in **research controller**, not a qualified replacement for a
trained robot policy. Importing an anatomical graph does not supply learned
robot skills or a measured model of the living animal.

## Real release data

The audited male-CNS v1.0 graph contains **166,700 classified neuronal entries**,
**25,582,938 directed weighted neuron-pair connections**, and **217 retained
isolated neurons**. These counts describe this compilation, not the number of
individual synaptic contacts reported in the publication. We retain every
nonzero pair in the released minconf-0.5 table whose endpoints pass the stated
classification rule; the synapse-count threshold is one.

The source annotation table contains 211,577 records. Its 44,877 unclassified
or non-neuronal records are excluded, not silently treated as neurons. The
pack manifest also counts excluded connectivity rows. This is the graph among
explicitly classified neuronal entries, not every segment or every connection
in the full electron-microscopy volume.

Unsigned pack identity:

```text
NUMICNS1 fingerprint  5e1e89f366e0157a
SHA-256              58314f44a02afe0726e5ba699a533d203b85b2fd6125bc0542b5db72cf993a1c
```

The compiler and release are reproducible from pinned source bytes:

```sh
python3 -m venv .venv-connectome
.venv-connectome/bin/python -m pip install numpy pyarrow
.venv-connectome/bin/python tools/numi_connectome.py bootstrap \
  --source-dir .numi/data/male-cns-v1.0 \
  --output .numi/data/male-cns-v1.0-neuron-unsigned.numicns \
  --resolution neuron --minimum-synapses 1 --sign-mode unsigned
```

All three official source files have hard-coded SHA-256 pins. Downloads use
bounded streaming, temporary files and atomic publication. Reuse validates
both source bytes and the source manifest. A changed versioned URL does not
silently become the same dataset. A future source revision requires a reviewed
pin update. Large data stay outside the Git source tree.

`--sign-mode unsigned` does not infer neurotransmitter signs. `--sign-mode
heuristic` is a separately identified model using consensus transmitter labels,
including histamine; it is not a claim that transmitter identity determines
every receptor's effect. Both modes normalize log1p synapse counts by incoming
absolute mass. Counts, normalization, signs and rate parameters remain distinct
from measured electrophysiology. The explicit modeled dynamics are bounded
signed rate updates with physical-time-adjusted alpha, not spiking neurons.

Source and attribution: HHMI Janelia / Google Research / collaborating authors,
Male CNS v1.0, CC BY 4.0. Preserve the supplied attribution and source manifest.
https://male-cns.janelia.org/download/
https://research.google/blog/a-connectomics-milestone-mapping-the-complete-male-fruit-fly-brain/

## One graph, different bodies

A `ConnectomeControllerSpec` contains exact graph, species and sensory-profile
fingerprints; named sensory/ascending neuron IDs and receptor features; named
descending/motor IDs; explicit integration times; and an actuator-major decoder
matrix. `ConnectomeControllerProgram` validates and compiles it against the
actual `CompiledSpeciesTemplate` and parameter publication. Distinct bodies
need distinct reviewed mappings and decoders; matching array shapes is not
permission to substitute a body. The old NumiLab `.numibody` TaskProgram
mapping is **not** a NumiBrain receptor mapping.

```sh
swift run -c release numi-brain-connectome inspect GRAPH.numicns
swift run -c release numi-brain-connectome catalog GRAPH.numicns neurons.jsonl
swift run -c release numi-brain-connectome validate-controller \
  GRAPH.numicns controller.json compiled-body.json PARAMETER_FINGERPRINT_HEX
```

In the normal Swift application, supply
`connectome: MetalConnectomeConfiguration(graph: graph, specification: spec)` to
`MetalNumiBrainConfiguration`. The existing handle owns the resulting complete
runtime. An optional `MetalConnectomeGraph` shares only immutable graph storage
and pipelines across agents; each agent owns independent neural state.

The native capture runner supports `capture-connectome`. Start with the same
valid native-world capture configuration used by `capture`, adding the exact
`connectomeGraphPath` and `connectomeSpecificationPath` fields:

```sh
swift run -c release numi-brain-experiment capture-connectome \
  --config capture-connectome.json
```

The native world library, cooked body/world files, compiled species template,
sensor assets, artifactDirectory and retained protocol/publication hashes remain required inputs. This command does not
invent a body or silently fall back to a fixture. Its research classification
is explicit; legacy qualified policy receipts cannot admit a different
connectome controller. The runner binds graph, controller and compiled-body source bytes into the capture manifest and checks exact decoder/whole-brain identities in each root execution.

## Control and persistence

Accepted O(t) receptor measurements feed the connectome on the existing Metal 4
encoder. Invalid features contribute zero, including their affine biases.
Bounded neural substeps generate descending features; the decoder supplies
logits to the **normal** motor stage before rest, fatigue, inhibition, risk,
reflex, CPG and physical actuator conversion. It does not write body poses,
velocities or contact forces. It creates no second GPU queue, Python stepping
loop or hot-path neural readback.

Physical retries reuse the cached neural candidate and decoder result. Only
joint root publication advances neural state and generation. Abort discards
the candidate. Queue ownership, completion and resource-lifetime obligations
are unchanged from the existing transactional runtime.

Complete committed checkpoints include SHA-256-bound neural activity, exact
operator/graph/body/publication identities, environment, episode, generation
and simulation time. High-level restoration constructs an isolated candidate
runtime and publishes it only after all components restore. Existing legitimate
direct parameter successors can preserve the same neural state with an explicit
publication rebind; changing the graph, body mapping or decoder is not implicit
checkpoint compatibility.

Prepared-recovery images include **both** base and candidate neural states plus
the exact cached descending output. The low-level prepared restore requires
the matching neural participant whenever one is present. It never reconstructs
a candidate from the base alone or labels omitted neural state as complete.
Fresh initialization cannot impersonate a nonzero-generation checkpoint.

## Verification and limits

The integration passed Apple release builds on macOS 26.6.2 / Xcode 26.6 /
Swift 6.3.3, seven connectome tests including actual Metal kernel execution,
14 prepared-recovery regressions and three qualification-boundary regressions.
The native compiler/validator passed 22 strict C++ tests; Arrow source-table
tests run with PyArrow in CI. Exact records are in
`evidence/connectome-native-v1/README.md`.

`python3 tools/run_connectome_apple_tests.py` creates a test-only SwiftPM harness
from exact copies of the owning repository modules. Its default scope is source
and sparse-kernel conformance, not production root qualification. Add
`--with-learning` to build and exercise the actual decoder learner and complete
experiment CLI with the pinned MLX dependency. The full released graph can be
checked through the sparse shader using `NUMIBRAIN_CONNECTOME_GRAPH`.

The separate `--require-metal4` scope requires the full pack and exercises normal
factory/root, abort, independent-mind, different-actuator-body and complete
checkpoint tests. These fixtures use explicitly synthetic physical acceptance
receipts, so even a passing root suite does not prove a robot task outcome.
The hosted Apple runner tested on September 7 failed the Metal 4 factory checks;
that result is retained rather than counted as successful root execution.

The new `study-connectome` / `calibrate-connectome` path learns this decoder
matrix from verified physical outcome artifacts. The generic `calibrate` command
still trains legacy motor gains and rejects connectome receipts. See
[decoder learning](CONNECTOME_DECODER_LEARNING.md) for exact configuration,
provenance and numerical contracts. Learned embodiment, biological validation
and sustained throughput remain experiments, not consequences of source builds.
