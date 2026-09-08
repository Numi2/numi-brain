# Connectome continuation: verified source, shader and learner

## Repository state

Direct source changes through `3b829b2752677b5ebeab49dd277bb0ef8925ce92`:

- `6e0e0300e62458ab02730b7c47fd7e89337f8de0`: cancellation-safe FP32 physical-time integration, small-step shader regressions and full-data sparse-operator conformance.
- `3a079bbe204b991576305f74108ad4b7717d39cf`: exact source materialization, bounded decoder-publication correction and release-build testability.
- `0a37ef29aaa426034509094e3b9f090ea13efffc`: fix the recovered capture fixture's collision with XCTestCase.run; protect patch output paths.
- `3b829b2752677b5ebeab49dd277bb0ef8925ce92`: numerical operator revision 2 in binding identity, with an independently reconstructed hash regression.

The 22-file decoder/import/capture increment is retained under `.numi` and
`.numi/connectome-decoder/materialized-source.json`. It is NOT yet expanded
into the ordinary source files on `main`. The passing CI checkout materialized
those files before compiling them. This distinction matters: a bare SwiftPM
build of `main` does not acquire the staged decoder-learning implementation.

In a clean clone containing these commits, explicitly expand the verified
increment with:

```sh
python3 tools/materialize_connectome_source.py --apply
```

The default invocation without `--apply` is a dry run. The tool verifies the
staged bytes and every final source SHA-256, refuses affected user edits, checks
all changes before applying them, and does not commit, push or modify a live
controller. Repeated application is a no-op when the exact files are present.
The expanded source is an implementation candidate, not policy admission.

## Passing Apple execution

Run: https://github.com/Numi2/numi-brain/actions/runs/34180210243

Job: `101917603846`, conclusion `success`.
Checkout: `0a37ef29aaa426034509094e3b9f090ea13efffc`, plus the exact verified
materialized increment.

Host: macOS 26.6.2, Xcode 26.6, Apple Swift 6.3.3, arm64.
GPU reported by the shader test: `Apple Paravirtual device`.

Executed successfully:

- 22 native C++ pack/binding/decoder checks.
- 6 Arrow/import checks.
- 20 selected Apple tests: 3 controller, 5 decoder-study, 3 graph,
  6 MLX decoder-calibration and 3 Metal kernel tests. Zero failures.
- Compilation of the actual selected owning Core and Metal modules, the actual
  selected MLX learner sources with pinned mlx-swift 0.31.3, and the experiment
  CLI. The focused harness does not substitute a physics or neural backend.

Exact full-graph test output:

```text
NUMIBRAIN_FULL_CONNECTOME_KERNEL nodes=166700 edges=25582938 graphSHA256=58314f44a02afe0726e5ba699a533d203b85b2fd6125bc0542b5db72cf993a1c device=Apple Paravirtual device referenceDestinations=130 maxError=2.9802322e-08 productionRootExecuted=false
```

This dispatch processed all graph edges from a declared synthetic initial
activity vector. It checked finite bounded output for all neurons and compared
130 destination values with a CPU reference. The maximum error is the maximum
among those sampled reference destinations, not an all-destination error bound.
It is a sparse-shader conformance result, not a brain/physics closed-loop result.

Passing diagnostic artifact: `10038832202`.
ZIP SHA-256: `9acfddf04fe7e9e7ff87fb03b2c3b60a1e6695d3e62cd3b3b4b98aeed3d2fe1f`.
Source archive SHA-256: `cfdf9539f5d3d3a302f5bfd6c9497cb3ed575223668eeca8618a2ab277080cf4`.
The log includes an `EXACT_SOURCE_MANIFEST` for every copied implementation and
test source. The later revision-2 C++ fingerprint-domain change is not silently
attributed to this earlier Apple run.

## Additional local checks after the Apple checkout

On Linux, all 23 current native tests passed with C++20 and
`-Wall -Wextra -Wpedantic -Werror`, including the new numerical revision hash.
The actual audited graph also passed the current native reader after that
revision. Reader source SHA-256:
`7f7c0445a27ebf27b5c6c8c185f6218ab7f0e27e8e8ff425312ff46a8cddc7f6`.

Materializer checks passed for wrong HEAD, existing affected edits, unsafe
patch output, unchanged dry run, complete application, idempotence and unchanged
Git HEAD. All 22 expanded source hashes match the committed materialization
manifest. These checks do not constitute an Apple execution of the later ABI
revision or a physical training campaign.

## Data identity and model scope

The audited pack contains 166,700 classified neurons and 25,582,938 directed
neuron-pair connections. Pack size: 216,144,031 bytes. Graph fingerprint:
`5e1e89f366e0157a`. Pack SHA-256:
`58314f44a02afe0726e5ba699a533d203b85b2fd6125bc0542b5db72cf993a1c`.

The source artifact is `male-cns-v1.0-classified-neuron-pack`, run
`34173965507`, artifact `10036630660`. The pack uses declared unsigned,
incoming-normalized rate-model weights. It is not a measured physiological
model, a living brain's activity, or an automatically competent robot policy.

The recovered learner changes the actual robot-specific actuator decoder,
keeping graph structure, neural parameters and receptor/readout selections
frozen. Native captures and physical evaluations must be reverified before a
research proposal can be retained. The proposed parameter update is bounded;
that bound is not a bound on robot motion. Proposals remain non-promotable.

## Remaining boundary

The selected passing scope deliberately excludes the production Metal 4 root
tests. Earlier attempts on this hosted device failed to obtain the required
Metal 4 runtime. The normal-root path, multiple body control, complete joint
checkpoint/recovery, native physical campaigns and held-out learned task
outcomes are not qualified by the passing shader and learner arithmetic tests.
No trained robot checkpoint has been produced by this continuation.

After materialization, run the strict scope on a Metal 4-capable Apple machine:

```sh
NUMIBRAIN_CONNECTOME_GRAPH=/absolute/path/to/male-cns-v1.0-neuron-unsigned.numicns \
  python3 tools/run_connectome_apple_tests.py --with-learning --require-metal4
```

The current physical experiment implementation uses the existing 416-muscle
full-body model. Other robot morphologies need their own reviewed sensor,
readout and actuator bindings plus physical evaluation. Read
`docs/CONNECTOME_DECODER_LEARNING.md` in the expanded source for the exact
capture/probe/update workflow. Do not weaken identity, hardware or evidence
checks to label these remaining outcomes complete.
