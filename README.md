# NumiBrain

NumiBrain is the standalone Apple-native nervous-system runtime for embodied humans, animals, and robots inside NumiLab. It is designed to couple transactionally to NumanX while keeping the normal perception-to-action loop GPU resident on Apple M4/M5-family hardware through Metal 4.

> Status: formal architecture plus an executable heterogeneous mesoscale neural-tissue vertical slice and deterministic multi-rate scheduler oracle. The complete NumiBrain runtime is not implemented or qualified yet.

The authoritative causal path is:

```text
receptors
  -> embodied belief and body schema
  -> predictive world model
  -> workspace and memory
  -> goals, options, and planning
  -> cerebellar, brainstem, and spinal control
  -> muscle and autonomic commands
  -> NumanX shadow integration
  -> accepted sensory consequences
  -> atomic joint commit and learning
```

NumanX owns body, material, contact, muscle, organ, and environment physics. NumiBrain owns perception, belief, memory, motivation, action selection, learning, and neural control. A separate developmental environment supplies objects, consequences, social agents, demonstrations, language, challenges, and exploration opportunities.

The system is a mesoscale hierarchical recurrent latent-state architecture: dense local computation, sparse long-range routing, event interrupts, explicit memory, multi-timescale plasticity, world-model planning, and structured motor control. Detailed spiking or compartmental neurons are optional local modules, not the default whole-brain representation.

The architecture is defined by [NumiBrain v1.0](docs/NUMIBRAIN_V1_SPEC.md). The implemented tissue model and its scientific limits are defined in [TISSUE_MODEL_V0.md](docs/TISSUE_MODEL_V0.md). The compiled module ABI and deterministic scheduler semantics are defined in [SCHEDULER_V0.md](docs/SCHEDULER_V0.md). Implementation claims and current readiness are tracked in [STATUS.md](STATUS.md).

## Run the tissue slice

NumiBrain requires macOS 26, Swift 6.2 or later, and an Apple GPU with Metal 4 for the native path.

```sh
swift test
swift run -c release numi-brain-tissue \
  --backend metal \
  --width 256 \
  --height 256 \
  --duration-ms 40 \
  --control-ms 20 \
  --structure layered \
  --delays layered \
  --connectome bilateral \
  --stimulus-noise 0.35 \
  --seed 0x4e554d49 \
  --lesion-x 0.62 \
  --lesion-y 0.5 \
  --lesion-radius 0.10 \
  --lesion-viability 0 \
  --verify-cpu \
  --verify-replay \
  --snapshot artifacts/tissue-activity.png \
  --output artifacts/tissue-evidence.json
```

The executable also supports `--backend cpu` as a deterministic FP32 oracle, `--structure homogeneous`, `--delays instantaneous`, and `--connectome none` as baselines. Its runtime input is now an immutable schedule of timestamped receptor events rather than a shader-special-cased stimulus. `--stimulus-noise`, `--seed`, `--environment-id`, and `--episode-id` address bounded counter-random samples without mutable RNG state. Layered structure, delay classes, the bilateral sparse graph, event noise, and lesion controls are synthetic experiment inputs, not anatomical, conduction-velocity, receptor, or injury calibration. JSON evidence separates wall time from Metal 4 GPU time and records all state and input hashes, random identity, graph and memory sizes, device and execution path, boundedness, delayed-future rollback/retry, replay, and CPU–GPU error. PNG output is an inspection heatmap, not biological validation.

A reproducible Apple M4 development run of the GPU-compacted noisy-event, sparse-projection, delayed, layered-lesion path is checked into [evidence/tissue-v0.5](evidence/tissue-v0.5/README.md). Earlier artifacts remain in [evidence/tissue-v0.4](evidence/tissue-v0.4/README.md), [evidence/tissue-v0.3](evidence/tissue-v0.3/README.md), [evidence/tissue-v0.2](evidence/tissue-v0.2/README.md), and [evidence/tissue-v0.1](evidence/tissue-v0.1/README.md). These are correctness and visual-inspection artifacts, not production performance qualifications.

## Run the scheduler oracle

The Phase 1 scheduler reference uses integer physical microseconds, compiled C++ ABI records, per-agent transactional clocks, immediate interrupt masks, and deterministic cohort grouping:

```sh
swift run -c release numi-brain-scheduler \
  --duration-ms 200 \
  --control-ms 20 \
  --environments 4 \
  --output artifacts/scheduler-evidence.json
```

This executable is deliberately a CPU oracle. It validates the stable record layout and causal scheduling rules before the hot scheduler moves into the single Metal command timeline. It is not GPU-resident scheduler evidence or full 96-module execution.

The exact v0.1 four-agent scheduler artifact is checked into [evidence/scheduler-v0.1](evidence/scheduler-v0.1/README.md).

## Foundational invariants

- Normal observations are causal receptor signals, never perfect or future simulator state.
- Authoritative somatic output is muscle excitation or an equivalent actuator command.
- Body, world, spatial, and self estimates are compatible factors of one belief state.
- Fast reflexes and critical events never wait for slow planning.
- Rejected physical trajectories change no neural history, memory, learning, drives, plasticity, or random counters.
- Shared slow weights are immutable within a rollout cohort; each agent retains an independent mind.
- The hot physics-brain loop stays on the GPU; the CPU is an orchestration and publication boundary.
- Deterministic replay restores physical state, brain state, parameter version, schedules, generations, and counter-based randomness.

## Implementation order

The first executable vertical slice now establishes one regional tissue primitive: FP32 excitatory/inhibitory population dynamics, synthetic per-site heterogeneity, a finite-time axonal relay, explicit conduction history, lesionable short-range coupling, destination-major sparse delayed projections, timestamped noisy receptor events, bounded GPU event compaction, counter-based randomness, adaptation, a CPU oracle, Metal 4 dispatch, and committed/root-shadow/candidate transaction generations. Each attempted substep compacts due event indices into a private GPU buffer before tissue sites scan only that active set. It does not yet implement spiking neurons, calibrated receptors or conduction velocity, parallel cohort-scale event compaction, an anatomical multi-region graph, NumanX interop, learning, memory, or motor control.

The next runtime-foundation work is a Metal-resident multi-rate scheduler using the compiled module ABI, immutable parameter versions, parallel prefix-sum event compaction for large cohorts, indirect active-region dispatch, nested NumanX transaction interop, and private-heap state storage. Later phases add calibrated causal receptor adapters, body schema, protective and motor systems, world modeling, sparse routing, motivation, skills and planning, memory, development, communication, and persistent life mode.

No phase is intended as a throwaway implementation.
