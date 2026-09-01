# NumanX state-of-the-art roadmap

NumanX is the joint embodied runtime formed by NumiBrain and the Numi Human,
MyoSim, NHTENDON, MetalRobo, and Matter physics stack. Its north star is not a
dated feature checklist. It is one causal, replayable, Apple-native agent whose
perception, decision, rigid-body state, deformable state, muscle state, memory,
and publication boundary agree on one accepted root.

This roadmap is promotion-gated. A feature advances only when its owning code,
failure semantics, executable evidence, and scientific claim all agree. A
smaller demonstration is retained as evidence; it is never renamed as the
target architecture to meet a schedule.

## What “state of the art” means here

NumanX has several independent comparison axes. Passing one does not imply the
others:

1. **Runtime integrity** — causal zero-copy ownership, rollback, replay, and
   atomic publication across neural and physical state.
2. **Physical fidelity** — stable coupled rigid/deformable/contact/muscle
   dynamics with measured convergence and independent validation.
3. **Learning capability** — language- and vision-conditioned generalist
   behavior, cross-task and cross-embodiment transfer, long-horizon memory, and
   efficient adaptation.
4. **Throughput** — environments per second, control latency, memory, energy,
   and scaling on comparable hardware and workloads.
5. **Biological usefulness** — muscle activation, tendon force, joint loading,
   metabolic cost, proprioception, and perturbation responses compared with
   independent experimental or accepted model evidence.
6. **Safety** — bounded action, fail-closed authority, observable uncertainty,
   collision/force limits, out-of-distribution behavior, and reproducible fault
   recovery.

The present transactional runtime can become state of the art on the first
axis without yet being a state-of-the-art learned generalist or a validated
digital human. Claims must always name their axis and evidence.

## System map

```text
NumiBrainCore
  root/substep/accepted-physics/commit identities
  deterministic time, random streams, parameter and species identity

NumiBrainMetal
  fast tissue + protective motor path
  sensory transduction
  cognitive state, memory, development, accepted consequence
  private shadow journals and atomic complete-brain publication

NumanX HumanIO
  authoritative NumiBrain motor-candidate admission
  same-device muscle/autonomic/active-sensing leases
  causal unpublished sensor candidate

Numi Human + MyoSim + NHTENDON
  provenance-valid articulated candidate with exact logical nq/nv
  (current full-body asset: nq=129, nv=128; runtime capacity: 161/160)
  muscle activation and source-route generalized loading
  tendon-transfer diagnostics

Matter + CoupledHuman
  implicit FEM/field state
  moving attachments and exact point Jacobians
  Human effective-tangent candidate service
  prepared accepted-state proof and restore authority

NumanX root owner
  physical checkpoint and prepare
  mutation-free proposal
  Brain preflight and GPU ACK
  Matter-then-Human apply/restore
  delayed sensor + physical + Brain publication fence
```

## Non-negotiable root protocol

One production root has exactly one authority chain:

```text
motor candidate
  -> physical checkpoint and candidate
  -> unpublished causal sensor candidate
  -> unpublished Brain fast+cognitive consequence
  -> mutation-free physical proposal
  -> completed Brain preflight
  -> GPU Brain ACK
  -> quarantined Human+Matter apply or restore
  -> validated applied outcome
  -> all fallible publication reservations
  -> private Brain pointer flip
  -> exact joint publication fence
  -> physical+sensor release
  -> public complete-root generation
```

Events provide ordering and liveness only. Versioned records, exact resource
identity, content-derived state evidence, and terminal command completion
provide authority. No event reaching a value can turn a failed command into an
accepted root.

No public reader may observe a mixed root. During a close, component snapshots
are diagnostic and non-authoritative. The production aggregate view must return
either the previous complete root or the next complete root, never a tuple with
new physics and old Brain state (or the reverse).

FNV fingerprints in this protocol provide deterministic integrity and replay
identity inside the trusted same-device process. They are not cryptographic
authentication and must not be described as tamper-resistant security.

## Promotion gates

### Gate A — one exact transactional root

Required evidence:

- The real provenance-valid full-body Human (currently 157 bodies, nq=129,
  nv=128, and 416 muscles), an attached Matter world, HumanIO, and NumiBrain
  execute one complete root through the production interop surface. Runtime
  capacity must remain distinct from logical model dimensions; qualification
  may not pad unowned dynamics coordinates to reach a maximum.
- Motor header, somatic, autonomic, and active-sensing buffers retain exact
  NumiBrain ABI identity and GPU addresses.
- Accepted sensors are produced from the physical candidate, consumed by the
  Brain while unpublished, and published only with the accepted root.
- Accept increments Human, Matter, sensor, physics, fast, cognitive, and public
  Brain generations exactly once.
- Human reject, Matter reject, Brain preflight reject, ACK fault, apply fault,
  and malformed publication fence leave the previous public root unchanged.
- Retry from a rejected root is byte-identical; accepted replay is bitwise for
  every deterministic arena and compact authority record.
- Timeouts retain resources and prevent slot reuse; terminal command failure
  cannot be converted into restore from partially written checkpoints.
- No hot-loop CPU payload copy, command-buffer wait, queue creation, or sensor
  readback.

#### Current qualification — runtime integrity slice complete

On 2026-08-31 the current source completed Gate A for the bounded production
shape: one environment, one 1 ms physical substep per control root, the real
157-body `nq=129`/`nv=128` and 416-muscle assets, and one attached one-tet Matter
world on an Apple M4 MacBook Air (24 GB, macOS 26.6 build 25G5028f, Swift 6.3,
Metal 32023.883).

The executable path published three consecutive roots from persistent
device-resident Human q/v/MyoSim state and the previous jointly published
sensor generation. A fully formed stale-predecessor root failed before native
slot/generation consumption. A fourth root was prepared, sticky-timeout
quarantined, explicitly force-rejected and restored, then retried with the same
transaction identity. Its 64-byte accepted physics token and complete 416x10
proprioceptive plus 416x1 interoceptive payloads were byte-identical to the
rejected attempt. The accepted retry published Brain/physics generation 4 and
sensor generation 5; the rejected sensor generation remained unpublished.

Qualification also included:

- 10/10 focused MetalRobo/HumanIO/CoupledHuman/Matter/owner/bridge CTests,
  passed twice;
- 15/15 Brain ABI4 record tests, 25/25 atomic-publication tests, 13/13 shared
  timeline tests, and 3/3 sensor-interop tests;
- the complete 144-test Swift suite with one environment-dependent skip and no
  failures;
- a production Swift build; and
- strict warning-as-error host/shader checks plus clean diff checks.

The real E2E XCTest completed in 4.96 seconds, but that number includes fixture,
pipeline, and test orchestration. It is not a control-latency or throughput
measurement. Gate E remains open. The Brain species topology used by this test
has the exact 416 actuator/sensor shape but remains a synthetic nervous-system
fixture, and the attached one-tet FEM proves transaction execution rather than
full tissue realism. Gates C through F therefore remain independent promotion
work after the bounded Gate B qualification below.

### Gate B — complete causal sensorium

The aggregate root publishes all seven listed channel families. A task-trained
successor now passes independent closed-loop learned-policy interventions on a
new +0.5-degree held-out support world for vision, audition, touch,
proprioception, vestibular, interoception, and kinesthesia. Interoception owns
transactionally accepted reduced local energy, gas-burden, temperature,
fatigue, and damage state plus feature-aware cognitive aggregation. Its semantic
policy sketch is direction-preserving and validity-gated; ablation no longer
fabricates zero energy/oxygen. Intact sensing realizes mean physical muscle
activation `0.0075913453`, versus `0.0016865405` when absent, under the same
accepted goal and option sequence. It remains short of systemic physiology. Active
sensing now owns a transaction-bound, bounded head-local camera gimbal that
changes ray geometry with deterministic replay and nonvisual isolation. The
ABI4 prepared path now turns FNV-bound host capability claims into private
developmental evidence only after the authoritative GPU accepted-physics gate.
After six accepted roots the reference brain reaches its active-sensing stage;
the seventh decision autonomously commands the physical gimbal, while rejected
or fingerprint-mutated claims cannot unlock it. A command-only ablation leaves
all nonvisual outputs byte-identical while autonomous gaze increases valid
depth and geometry coverage, so the active-sensing causal-benefit criterion is
promoted. Autonomous capability discovery remains a limitation rather than
evidence supplied by this host-authored developmental environment. The bounded
Gate B evidence matrix is complete. Promote these broader research boundaries
independently:

- calibrated tactile pressure/slip, vestibular, and joint-load fidelity beyond
  the current bounded fixture;
- systemic physiology beyond local muscle/tendon fatigue, energy, gas burden,
  temperature, and damage;
- vision/depth with calibrated capture time and rolling/exposure semantics;
- auditory waveforms, speech, and language input; and
- autonomous developmental capability discovery and verification beyond the
  current accepted-root-authenticated host claims.

Any broader channel model still needs exact capture and delivery time, latency,
shape, validity, species/profile identity, accepted-root provenance,
perturbation tests, and a task-relevant causal ablation.

### Gate C — learned embodied foundation policy

Runtime architecture is not a substitute for data or training. Promotion
requires:

- a vision-language-action or equivalent hierarchical policy packaged for the
  Metal GPU timeline;
- a low-level whole-body controller that preserves hard physical/safety gates;
- multimodal pretraining, simulation demonstrations, real or independently
  sourced embodiment data, and explicit dataset provenance;
- action chunking or diffusion/autoregressive control evaluated under the same
  latency budget;
- cross-task, cross-scene, cross-object, and cross-embodiment held-out splits;
- few-shot adaptation measured in examples, wall-clock training, and retained
  prior-task performance;
- long-horizon memory evaluated on delayed consequences, interrupted tasks,
  and state aliasing, not just short demonstrations;
- uncertainty and out-of-distribution detection that can force the root to
  reject or request supervision.

This gate is compared with current generalist systems such as
[Gemini Robotics 2](https://deepmind.google/blog/gemini-robotics-2-brings-whole-body-intelligence-to-robots/),
[Gemini Robotics On-Device 2](https://deepmind.google/models/gemini-robotics/on-device/),
[NVIDIA Isaac GR00T 1.7](https://developer.nvidia.com/blog/develop-humanoid-robot-policies-end-to-end-with-nvidia-isaac-gr00t/),
and [pi0.5](https://www.physicalintelligence.company/download/pi05.pdf).
NumanX must run comparable held-out tasks before making a comparative
generalist claim.

The first Gate C production boundary is now executable but is not a promotion:
`BrainFoundationPolicyPackage` binds exact learned parameter bytes, architecture,
species/runtime/owner/controller/safety identities, dataset and split provenance,
and all required evidence axes into a deterministic content-addressed
version-2 `.nbpolicy`.
The evidence verifier streams retained artifacts, proves split disjointness,
recomputes predeclared axis-specific metrics, requires authoritative NumanX
root provenance, and issues an in-process receipt bound to the exact package.
The Metal factory requires that receipt and rejects seeds, sensor/program/
controller drift, unsupported action-generation geometry, and model-family/
revision/goal/precision/uncertainty metadata that does not name its exact
executable contract. The
`numi-brain-policy` CLI can inspect, structurally validate, or verify a retained
artifact store. Package thresholds now bind the executable Metal decision and
motor gates: unpublished uncertainty can request supervision or reject before
physical handoff. Authoritative accepted/rejected release can emit a version-4
root transcript, while pending, failed, and quarantined attempts cannot. The
production `numi-brain-gate-c` runner now captures exact settled sensor tensors,
canonical sample manifests, terminal executions, all nine immutable learning-
batch sections, and non-promotable run manifests from the real 157-body ABI4
bridge. Its verifier reopens the complete artifact graph and recomputes the
live Metal learning-batch fingerprints. A deterministic three-root MLX
candidate and its honest 1-millisecond +0.5-degree `2/3` failure remain retained.
Those historical "support" task names do not denote active ground contact in
the present prepared Human/Matter v1 path: it supplies an unconstrained `A0`,
disables contacts and root assistance, and lacks the nullspace/KKT/Schur
tangent authority needed for constrained support dynamics. A 1,000-root M4
trace (`0ebe5548ef25fafe55dccc8b1d848c40d31c7edf17484d616d265e062aea0992`)
accepted every root while root vertical velocity reached `-1.0136935711 m/s`
and root/head height fell about 5.17/5.19 cm. It is free-fall evidence, not
balance evidence. All older support-labeled results are therefore retained only
as runtime, artifact, replay, rejection, latency, memory, or synthetic-input
diagnostics.

The production support implementation is now deliberately scoped as one
monolithic constraint solve, not a second Stand contact pass. Matter must
import the exact NHCNT point-plane rows through the Human candidate point
Jacobians, solve their unilateral/friction state in the same Newton/FGMRES KKT
as the attached material, and return the resulting generalized Human reaction
through the existing staged `A0 * deltaV / h` publication seam. The owner
therefore keeps its independent contact pass disabled; enabling it after the
Matter solve would double-apply contact and invalidate the accepted candidate.
Support multipliers, active/friction state, and their exact NHCNT source
identity must be checkpointed and included in accepted-state proof authority,
then drive tactile/support consequences. A frozen square projector is not an
acceptable substitute for unilateral Coulomb contact because its active set
depends on the coupled solution.

The first contact-independent physical Gate C task is now
`head-posture-lift-v1`, whose external goal carries exact target body 23 through
the fixed-size Metal goal ABI. A causal Metal test proves that selecting body 0
versus body 23 changes the final 416-muscle descending output. A coordinate-
exact, disjoint-scene 100-root baseline/candidate comparison then produced
identical head-relative-to-root change (`-0.00009346008 m`) and zero candidate
advantage against a predeclared `0.000001 m` minimum. Evaluation
`56d7e56eb642547ef9c273ceb63988b5b02221320995bdca254da2570d9d966b`
is explicit, byte-recomputable negative evidence.

A signed MLX physical objective now binds exact accepted vestibular/action
evidence to the DecisionState motor-drive and task-space gains. The first
candidate changed 104 muscle commands but retained zero lift advantage
(`c3b3ed313fd7d50fd274af414b52a67bb3b6a605063e32059d05e0ef8defdaf1`).
A stronger bounded exploratory update produced a measurable harmful
`-0.23841858` micrometre response
(`a316e273a8a7785a5d29e08068ca4944c8aae4fb0c380c95f9c21e676d328200`).
The learner now accepts that result only as a transitive causal calibration,
records gain direction `-1`, and rejects missing, zero, mismatched, or recursive
calibration. Calibrated candidate
`30b2b27bab02a05120e9eb19cef1f16b97e9c2cf3e37f8250b2c46e416b4fb25`
completed a third fresh 100-root scene and materially changed muscle output,
but its exact lift advantage remained zero
(`b3fbf5057e6cbea049b87e2230aa8de34f18984c36f76ea5bb99e6550c413ad3`).
A predeclared fourth-scene 1,000-root comparison then completed 1,000/1,000
accepted roots for both policies. Baseline/candidate head-relative lift was
`-0.00029051304/-0.00029039383 m`, a positive `0.11920929`-micrometre
candidate advantage but only about 12 percent of the unchanged one-micrometre
minimum. Evaluation
`961066d605aa89efa4f8de364ba3e2d35ba536cbfdab9baebc2a6074a4b4cbc0`
independently verifies and remains non-promotable. One predeclared stronger
successor then increased the calibrated learning rate from `4` to `12` while
retaining objective weight `4` and the existing `+/-4` parameter bound.
Training run
`933ed5614e07bcbd8a51d2fadce887b5fff47b5b9780ae4a4f00979570f6ff2a`
emitted signed learning artifact
`0f7be2cafc56e1e07f1d5c4bfc41b339a166fdf459588085e55fb04fc1b3fecb`
and candidate
`c60c18f708a81310a1caf396066af10eb98799eb602992f289ac6a5d7b115314`
was tested on a fifth fresh scene; baseline
`eaaf071d7034aa85c271924c85c40aea64142a6ec9bf68e1b538248f21428b3b`
and candidate run
`c524ca3b2beff3fbf5a9985f995794b5aa65c0cdf432424e305def4896e6d6d9`
both completed 1,000/1,000 accepted roots, but both measured exactly
`-0.00029051304 m` head-relative lift. Evaluation
`11d2c107be2eb59fbceed6205d101bace5fee8e37a345928cbaabe31c591a472`
independently verifies the exact `0 m` advantage. Gate C remains open. Its next
promotion-directed step needs a newly justified causal update or another
calibrated body metric that clears its fixed threshold on a fresh held-out
scene, or the larger constrained-dynamics authority required before genuine
support learning can be claimed. Post-hoc parameter sweeps and threshold
relaxation are not acceptable substitutes.

The anatomical identification path no longer uses a nonzero learned-effect
vector as its only completion marker. An exact accepted-attempt bit now
advances past a probe whose 10-microsecond endpoint delta is below resolution,
and muscle-model residuals remain actuator-local epistemic evidence rather
than whole-body damage authority. A matched 20-root Apple M4 diagnostic
retained 20/20 accepted roots for baseline
`a2c20d9e3897453d08d703759aec174efa2242f9eaa0368eab047f5341de783a`
and body-23 goal
`e5a599775b13515b3b3f77c7ff755ac3594f3c7180fa9f3b2bfc2ef0fa7d0467`.
The goal issued one learned command per root across actuators 22, 23, and
32 through 42 before risk inhibition, producing matched-baseline differences
only in proprioceptive and muscle-receptor payloads from root 3 onward. Exact
vestibular root-relative head height remained unchanged. This is positive
local causal-response evidence and negative task-response evidence over only
200 microseconds; it does not change the 100-microsecond qualified default or
close Gate C.
The runner now binds its exact native timestep through motor duration,
timestamps, species transport, and the run manifest. At 100 microseconds, a
new candidate trained from 11 accepted roots and both baseline/learned
held-out cohorts complete 10/10 post-bootstrap observations. An independent
repeat matches sensor contents, generations, outcomes, and physical metrics
across all 22 roots while producing fresh transaction authority identities.
The learned-minus-baseline success delta is still zero. Metal-feedback latency
now passes its predeclared 20 ms p99 budget over 100 learned roots. A separate
20-ID/20-all-invalid local invalid-sensor cohort recomputes AUROC 1.0,
supervision-or-reject recall 1.0, and unsafe acceptance 0 from authoritative
accepted/rejected transcripts while rejected roots preserve generation 20.
An additional same-root emergency cohort challenges 40/40 roots and retains
exact GPU protective-command and per-muscle output evidence. It includes 20
authoritative uncertainty rejections, observes a maximum nonzero learned drive
of `0.18392205238342285`, and recomputes zero protective bypasses and zero
safety violations. This is stable local cross-scene, synthetic OOD, and bounded
same-root safety evidence, not learned advantage, independent-distribution or
independent-embodiment calibration, or promotion. No production
package, independent embodiment source, complete disjoint Gate C dataset
matrix, or passing evaluation matrix exists yet. Absolute species-critical
sensor rules now consume the raw validity-gated receptor plane, preventing
learned sensory bias from fabricating a physiological emergency stop; a real
two-root M4 regression covers the former healthy-interoception failure. A
fresh, coordinate-exact 8-example adaptation still yields zero success gain on
the legacy 5-degree metadata variant (`0.4 -> 0.4`) while retaining `1.0`
prior-task success. Its successor changes all 416 actuator commands, but the
1.1-millisecond free-fall trajectory is unchanged, and a four-example
pre-failure calibration suppresses output rather than improving support. The
few-shot contract requires a 10-point gain, a task-conditioned learning
objective, and a meaningful physical horizon; this remains negative evidence
and Gate C remains open. See
[NUMANX_GATE_C_REQUIREMENTS.md](NUMANX_GATE_C_REQUIREMENTS.md).

The long-horizon evidence path now retains complete committed memory batches on
both sides of every authoritative root plus an address- and generation-free
semantic motor-action artifact. Verification enforces exact memory continuity,
accepted-root advance, and rejected-root no-mutation. This prevents a future
delayed/interrupted/state-aliasing benchmark from substituting run labels for
recomputable memory and action evidence. Fixed local Apple M4 protocols now pass
all three 10-cohort axes at `1.0`: state-alias pairs use byte-identical semantic
sensor content with distinct memory/action evidence; interrupted roots reject
without memory mutation and recover on the next root; delayed cues remain live
across two waits through the consequence deadline. These are non-promotable
same-device, same-body, same nominal-task-family development results. Independent
task sources, scenes, objects, embodiments, and laboratories remain required.

### Gate D — physical and biological validation

Required suites include:

- Human effective-tangent action/inverse consistency and finite differences;
- attachment virtual work, impulse, angular momentum, and energy accounting;
- timestep, stiffness, mass-ratio, friction/stiction, and contact-stack sweeps;
- monolithic versus any asynchronous fast-path error and failure-rate curves;
- zero-stiffness and zero-attachment reductions to the standalone Human;
- no duplicate MyoSim/NHTENDON generalized force;
- held-out muscle activation, tendon force, joint reaction, pose, and effort
  comparisons;
- perturbation recovery and lesion/sensor ablation with confidence intervals;
- material calibration on held-out mechanical tests, not visual agreement.

### Gate E — scale and performance

Measure before optimizing and compare equivalent workloads. Report:

- control-root latency distribution, not only mean kernel time;
- simulated seconds per wall second and environments per second;
- peak and steady resident bytes per environment;
- command-buffer, synchronization, and residency overhead;
- GPU occupancy, bandwidth, cache behavior, counter samples, and System Trace;
- deterministic and fast-math modes separately;
- scaling across environment count, DoF, attachment count, FEM resolution,
  sensor count, model size, and horizon;
- same-device power/energy when available.

Reference baselines include [Newton](https://github.com/newton-physics/newton),
[Isaac Lab](https://arxiv.org/abs/2511.04831), and
[MuJoCo Warp](https://github.com/google-deepmind/mujoco_warp). Their published
throughput is not directly comparable until the model, contacts, sensors,
precision, hardware, and acceptance criteria match.

Apple-native inference should use a packaged GPU-timeline path when it is a
better fit than custom kernels. Metal 4 explicitly supports
[machine-learning passes on the GPU timeline](https://developer.apple.com/documentation/metal/running-a-machine-learning-model-on-the-gpu-timeline),
allowing inference results to feed later compute without a CPU handoff.

### Gate F — safety and deployment

- layered semantic, kinematic, contact, force, thermal, and actuator limits;
- red-team malformed records, stale generations, resource aliasing, and event
  replay;
- deterministic emergency/protective path with bounded end-to-end latency;
- independent watchdog and safe-state behavior for GPU/process/device failure;
- calibrated uncertainty and explicit human-supervision transitions;
- reproducible incident capture without exposing rejected shadow state;
- versioned model/data/runtime manifests and rollbackable releases.

## Benchmark matrix

Every promoted release carries one machine-readable manifest with source
revision, binary and metallib hashes, hardware, OS/SDK, configuration,
determinism mode, and retained artifacts.

| Axis | Minimum benchmark | Promotion statistic |
| --- | --- | --- |
| Root integrity | accept/reject/fault/retry matrix | zero split publication; bitwise replay |
| Coupled physics | attachment/contact stiffness and mass-ratio sweep | convergence, impulse, energy, failures |
| Motor control | held-out whole-body tasks and perturbations | success, tracking, force, effort |
| Generalization | unseen instruction/object/scene/action/embodiment | success with confidence intervals |
| Adaptation | fixed example and compute budgets | examples, time, retained prior performance |
| Sensor causality | modality ablation and timestamp perturbation | performance delta and failure behavior |
| Long horizon | interrupted multi-stage tasks | completion, recovery, memory accuracy |
| Scale | matched deterministic and throughput modes | p50/p95/p99 latency, env/s, bytes/env |
| Safety | collision/force/OOD/red-team scenarios | violation and safe-stop rates |

## Execution order

The gates are not dates, but dependencies still impose an order:

1. Finish and independently audit Gate A on one exact Apple GPU revision.
2. Retain that root as the correctness oracle while adding modalities and
   cohort execution.
3. Add training/data infrastructure and a packaged learned policy without
   weakening the hard transactional and physical gates.
4. Establish held-out generalization and physical-validation corpora.
5. Profile the exact qualified workloads; optimize only measured bottlenecks.
6. Add deployment safety, manifests, and observability around the already
   qualified root.

## Evidence language

- **Source implemented** means owning code exists and was reviewed.
- **Build qualified** means the exact source and products compiled.
- **Executable qualified** means a named command passed on named hardware.
- **Replay qualified** means retained outputs match under the stated mode.
- **Performance qualified** requires measured counters/traces on a matched
  workload.
- **Physically validated** requires independent physical/model evidence.
- **Generalist** requires held-out task, scene, object, instruction, and
  embodiment results.
- **State of the art** requires a named metric, comparable baseline, and result;
  it is never inferred from ambition or architecture.
