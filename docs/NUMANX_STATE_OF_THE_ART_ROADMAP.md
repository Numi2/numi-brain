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
full tissue realism. Gates B through F therefore remain independent promotion
work.

### Gate B — complete causal sensorium

The aggregate root now publishes all seven listed channel families. Vision,
audition, touch, proprioception, vestibular, and kinesthesia have independent
closed-loop learned-policy interventions on the held-out support task. The
interoceptive producer now has transactionally accepted reduced local energy,
gas-burden, temperature, fatigue, and damage state, plus feature-aware cognitive
aggregation, but its held-out ablation still improves the support outcome and
therefore fails promotion. It also remains short of systemic physiology. Active
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
evidence supplied by this host-authored developmental environment. Promote the
remaining boundaries independently:

- tactile/contact pressure and slip;
- vestibular and base acceleration;
- joint position, velocity, load, and limit state;
- interoceptive muscle/tendon/fatigue/energy state;
- vision and depth with calibrated capture time and rolling/exposure semantics;
- audition and language input;
- autonomous developmental capability discovery/verification beyond the
  current accepted-root-authenticated host claims.

Every channel needs exact capture time, delivery time, latency, shape, validity,
species/profile identity, accepted-root provenance, perturbation tests, and an
ablation showing that the learned policy uses it causally.

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
