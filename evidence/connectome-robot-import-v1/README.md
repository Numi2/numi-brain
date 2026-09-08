# Decoder forks and native robot import — execution record

Implementation range: `ed70947ac85b95c8196d3a6c5d7c305ef208f598` through
`7612d462baeb87ead73edf0e80e2858bcf989d34`. All source is in ordinary
repository paths; no materialization or encoded patch application is required.

## Published implementation

- `51d2a40641f8df6ab4066b73d37d76777691e1f1`: exact decoder-only checkpoint
  transformation, complete source/physical snapshot lineage, paired-probe
  checks and six byte-preservation/identity/budget regressions.
- `3ca946c0cf33d7ff0459721669b60ab21913ae16`: isolated child construction
  through the owning brain factory, complete native restore validation and a
  strict Metal 4 parent/child restoration test.
- `7612d462baeb87ead73edf0e80e2858bcf989d34`: real NumiLab robot asset
  exporter, joint-frame conversion, typed Swift topology/actuator import,
  position-channel compilation, CLI integration and six import regressions.

The fork compares actual graph bytes and frozen operator settings. It changes
only decoder coefficients/program identity and containing checksums. Neural
activity, hot state, persistent memory, fast-system state, random context,
generations and timestamps are retained. Its lineage remains non-promotable.
The physical checkpoint bytes are retained and hashed but **not restored by
NumiBrain**. The physical owner must restore them into separate worlds and
supply execution evidence before paired physical results can be attributed to
these initial states.

## Observed checked-out Apple result

Run: https://github.com/Numi2/numi-brain/actions/runs/34189003893
Job: `101943016494`, conclusion `success`.
Exact checkout: `7612d462baeb87ead73edf0e80e2858bcf989d34`.
Host: macOS 26.6.2 (25G83), Xcode 26.6 (17F113), Apple Swift 6.3.3, arm64.
Native exporter compiler: Apple clang 21.0.0.

Executed successfully:

- Complete SwiftPM release build of every package and test target; no source
  reconstruction, source substitution or modified checked-out files.
- 41 selected Apple tests, zero failures: six body-contract, three connectivity,
  three controller, six decoder-fork, five decoder-study, three graph,
  six MLX calibration, three Metal kernel and six native robot import tests.
- 23 native C++ pack/binding/decoder tests, 12 native connectivity-audit tests,
  six Arrow/import tests and seven release acquisition tests.
- Actual NumiLab asset export, native kinematic comparison and Swift import of
  Franka, G1 and X500, with the generated export directory explicitly passed
  to the tests (not an unconfigured/skipped real-asset test).

Strict Metal 4 root tests were compiled but NOT selected in this hosted run.
The factory's device restoration/trajectory behavior is not established by
its cold fork tests or by compiling its strict root test.

Artifact: `10041708844`, `connectome-package-7612d462baeb87ead73edf0e80e2858bcf989d34`.
ZIP SHA-256: `890ac3cde11b60a94ab3f4c4f55b39e12b834866fd15efa9c76101eed24a69f5`.
The artifact retains host/revision data, build logs, every selected test result,
real native robot JSON and manifest, and the full-graph kernel result.

The earlier two increments also passed their checked-out source/selected-test
jobs: `34187736649` and `34188138589`. Those results are not substituted for
this final checkout's result.

## Real native assets and coordinate checks

Pinned NumiLab revision: `68f5aa441a8437426de193a5c9beeac5a78113b6`.
Exporter SHA-256: `645b4688cacde9962f37bcf78baf9e1b7807b3e437e32b35379620da94e7d475`.

| RobotPack | Bodies | Joints | Actuator lanes |
|---|---:|---:|---:|
| franka_panda | 11 | 10 | 9 |
| unitree_g1 | 30 | 29 | 29 |
| px4_x500 | 1 | 0 | 4 |

The FP32-transferred COM anchors, parent-frame axes and rest-relative joint
transforms agree with the existing native FP64 analytic kinematics at rest
and two bounded simultaneous joint perturbations, within the declared 1e-6
position/orientation checks. This is a kinematic test, not physics simulation.

The three JSON exports were also independently produced from the same retained
native sources with Linux clang 17 and were byte-identical to the Apple exports:

```text
8cd32a50ebe379f3ad3985e657295b12acf3f4aceb62b07c1aa24b4d7285e54d  franka_panda.json
efdb6e00f4b566785d492191a71c03e32329f72b47ef6887a9784ff0114db0ad  unitree_g1.json
19062c6e316d42e6766554baf6147ea424588c9367bb7d76f9f2878a9bcce40c  px4_x500.json
```

Additional local wrapper checks rejected wrong/short revisions, duplicate and
path-like robot IDs, existing output, missing/symlinked output parents and
untracked native source. Existing output sentinels and the test repository HEAD
were preserved. These checks used an isolated local Git snapshot of the native
sources, not a claim that its synthetic local commit was the upstream commit.

## Full graph shader result

```text
NUMIBRAIN_FULL_CONNECTOME_KERNEL nodes=166700 edges=25582938 graphSHA256=58314f44a02afe0726e5ba699a533d203b85b2fd6125bc0542b5db72cf993a1c device=Apple Paravirtual device referenceDestinations=130 maxError=2.9802322e-08 productionRootExecuted=false
```

All output activity was finite/bounded. The maximum error applies only to the
130 sampled CPU-reference destinations. This remains a sparse-neural shader
conformance result, not full controller or physical task performance.

## Remaining execution boundary

Native robot metadata import does not supply mounted sensor transduction,
physical actuator application, cross-runtime ordering, joint publication or
physical-owner checkpoint restoration. NumiLab's normalized PolicyProgram
action array does not directly accept NumiBrain absolute-position channels.
X500's four rotor-mixer lanes are not joints or four independently specified
rotor thrusts. The adapter deliberately does not make those incompatible casts.
At the pinned native revision, no quadruped is registered and dVRK has no
authored actuator lanes; neither is silently substituted or invented.

The complete connectome brain/body loop, strict decoder-fork device restore,
matched physical probes, four trained robot embodiments and held-out learned
task outcomes still require implementation/execution. This record grants no
policy admission, hardware safety qualification or general robot competence.
See `docs/CONNECTOME_DECODER_FORKS.md` and `docs/NUMILAB_ROBOT_IMPORT.md` for
exact APIs and ownership requirements.
