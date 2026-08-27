# NumiBrain

NumiBrain is the standalone Apple-native nervous-system runtime for embodied humans, animals, and robots inside NumiLab. It is designed to couple transactionally to NumanX while keeping the normal perception-to-action loop GPU resident on Apple M4/M5-family hardware through Metal 4.

> Status: formal architecture plus an executable heterogeneous mesoscale neural-tissue slice with matching physical-time CPU and Metal relay paths, deterministic scheduler oracle, a compiled NumanX joint-transaction contract with accepted-only events and corrected-duration interactive Metal retry, and a versioned Metal cohort executor with GPU-generated indirect work, independent authoritative recurrent token state, delayed sparse-route history, and dynamic routing state per agent. The complete NumiBrain runtime is not implemented or qualified yet.

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

The architecture is defined by [NumiBrain v1.0](docs/NUMIBRAIN_V1_SPEC.md). The implemented tissue model and its scientific limits are defined in [TISSUE_MODEL_V0.md](docs/TISSUE_MODEL_V0.md). The compiled module ABI and deterministic scheduler semantics are defined in [SCHEDULER_V0.md](docs/SCHEDULER_V0.md). The executable region-major recurrent state and routing boundary are defined in [REGIONAL_TOKEN_V0.md](docs/REGIONAL_TOKEN_V0.md). Immutable slow-parameter identity and publication are defined in [PARAMETER_VERSIONING_V0.md](docs/PARAMETER_VERSIONING_V0.md). Deterministic multi-agent plan compilation and private Metal materialization are defined in [COHORT_DISPATCH_V0.md](docs/COHORT_DISPATCH_V0.md). The first stable NumanX handoff contract is defined in [JOINT_TRANSACTION_V0.md](docs/JOINT_TRANSACTION_V0.md). Implementation claims and current readiness are tracked in [STATUS.md](STATUS.md).

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
  --receptor-interrupt pain \
  --receptor-latency-us 500 \
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

The executable also supports `--backend cpu` as a deterministic FP32 tissue oracle, `--structure homogeneous`, `--delays instantaneous`, and `--connectome none` as baselines. Its runtime input is an immutable schedule of timestamped receptor events rather than a shader-special-cased stimulus. `--stimulus-noise`, `--seed`, `--environment-id`, and `--episode-id` address bounded counter-random samples without mutable RNG state. `--receptor-interrupt` and `--receptor-latency-us` attach a typed scheduler interrupt and causal conduction delay to the stimulus onset. On Metal, a dedicated kernel merges those due onsets with any host interrupt packets into a canonical private GPU queue before scheduling; there is no hot-path count readback. The Metal path advances the compiled eight-module schedule once per root transaction, then consumes the private due list through a 10,752-scalar recurrent token operator. Seven candidate sparse routes carry 0-5 ms delays; each due receiver deterministically scores causal messages, preserves routes inside a 2 ms minimum-persistence window, selects its configured normal top-k, permanently bypasses that budget for emergency routes, normalizes selected strengths, and gathers only compacted route indices. One compiled immutable parameter generation binds the exact tissue values, schedule, regional shape, and regional content to CPU checkpoints and a private 64-byte GPU record; publication is allowed only after rollout cohorts release the current version. Scheduler clocks, token state, diagnostic records, timestamped route histories, and per-agent routing state use private shadow generations that publish with tissue commit. Layered tissue structure, delay classes, both sparse graphs, event noise, lesion controls, scheduler roles, regional topology, score constants, and initial parameters are synthetic execution fixtures, not anatomical, conduction-velocity, receptor, injury, learned-model, or biological-timing calibration. Schema-v12 JSON evidence records the parameter version and parent, manifest and GPU binding bytes, schedule and regional identities, receptor ABI/transduction identity, token, route-history and routing-state memory, active-route counts, scheduler and regional dispatches, CPU parity, replay, rollback, and tissue CPU–GPU error. PNG output is an inspection heatmap, not biological validation.

Bounded Apple M4 Pro and Apple M4 correctness probes of the v0.12 immutable-parameter path are checked into [evidence/tissue-v0.12](evidence/tissue-v0.12/README.md). The heavy run started through `ssh macmini` only after the unrelated crow workload exited. The preceding receptor-interrupt qualification remains in [evidence/tissue-v0.11](evidence/tissue-v0.11/README.md). These are correctness and visual-inspection artifacts, not production performance qualifications.

## Run the scheduler oracle

The Phase 1 scheduler reference uses integer physical microseconds, compiled C++ ABI records, per-agent transactional clocks, immediate interrupt masks, and deterministic cohort grouping:

```sh
swift run -c release numi-brain-scheduler \
  --duration-ms 200 \
  --control-ms 20 \
  --environments 4 \
  --output artifacts/scheduler-evidence.json
```

This executable remains the standalone CPU oracle for multi-agent scheduler semantics. The tissue executable now runs bounded one-agent due selection and the eight-module recurrent regional-token operator inside its Metal command timeline. It is not the complete 96-module graph or a large-cohort scheduler qualification.

The exact v0.1 four-agent scheduler artifact is checked into [evidence/scheduler-v0.1](evidence/scheduler-v0.1/README.md).

## Run cohort dispatch materialization

The v0.20 dispatch executable preserves independent version-bound scheduler shadows, compiles their active module work into canonical timestamp/module groups, materializes the flattened plan into private Metal 4 buffers, and launches four consumer dispatches from three GPU-generated indirect arguments:

```sh
swift run -c release numi-brain-dispatch \
  --environments 8192 \
  --control-ms 20 \
  --output artifacts/cohort-dispatch-evidence.json
```

The first consumer emits exact auditable work records. The second advances a distinct environment-major compact diagnostic-state generation for each active agent. The third assigns contiguous plan-row ranges to 64 lanes per environment, performs a deterministic threadgroup prefix scan of match counts, and scatters a canonical private invocation span. The fourth launches one 64-lane threadgroup per agent and jointly advances its authoritative 10,752-scalar recurrent tokens, seven delayed route rings, and dynamic route scores, selections, strengths, persistence counters, and timestamps from that compact span and immutable factorized parameters. All modules due at one physical timestamp read one stable pre-timestamp token generation before publishing together. The executable verifies retry and discarded-shadow identity, canonical input ordering, exact GPU materialization, work consumption and invocation compaction, FP32 CPU-reference diagnostic, token, history, score, and strength parity, exact discrete routing state, interrupt isolation, full-cohort ownership, and exact replay fingerprints. A compiled 32-publication ring is accepted only when a pre-dispatch proof shows that the root plan cannot overwrite a delayed value it may still read. The CPU currently owns plan construction; Metal owns private region-major materialization and the no-readback handoff into all four dispatches. This is not GPU-native plan construction or cohort throughput qualification.

An exact-source 256-environment Apple M4 Pro correctness artifact for v0.20 is in [evidence/cohort-dispatch-v0.20](evidence/cohort-dispatch-v0.20/README.md); the preceding 16-environment Apple M4 control is in [v0.19](evidence/cohort-dispatch-v0.19/README.md). The exact 8,192-environment v0.14 indirect-consumption artifact remains in [v0.14](evidence/cohort-dispatch-v0.14/README.md), with the preceding materialization-only artifact in [v0.13](evidence/cohort-dispatch-v0.13/README.md). Command-feedback timings cover only the named kernels and are not production performance claims.

Physical-time Metal conduction and accepted fast scheduler/regional prefixes have an exact-source 74-test Apple M4 Pro qualification in [evidence/joint-transaction-v0.6](evidence/joint-transaction-v0.6/README.md). The earlier interactive-lifecycle and CPU-oracle qualification remains in [v0.4](evidence/joint-transaction-v0.4/README.md). These are correctness artifacts, not live NumanX coupling or throughput evidence.

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

The first executable vertical slice now establishes an FP32 excitatory/inhibitory tissue field plus a schedule-driven recurrent regional primitive: synthetic per-site heterogeneity, finite-time axonal relay and physical-timestamp conduction history, lesionable short-range coupling, destination-major sparse delayed tissue projections, timestamped noisy receptor events, a compiled 64-byte receptor-event ABI, GPU event and interrupt compaction, counter-based randomness, private scheduler clocks, 10,752 region-major token scalars, immutable factorized slow parameters, seven candidate sparse regional routes with per-agent transaction-owned timestamped delivery rings, deterministic content-scored top-k selection, emergency bypass, normalized strengths, compact selected-route gathering, matching CPU oracles, versioned multi-agent dispatch plans, private Metal cohort materialization, GPU-generated indirect work expansion, independent compact diagnostic, recurrent-token, route-history, and routing-state generations, Metal 4 dispatch, committed/root-shadow/candidate transactions, and compiled root/substep/physical-acceptance/commit tokens for NumanX handoff. The interactive bridge executes corrected-duration candidate tissue steps on Metal, samples local and sparse conduction by physical microseconds, advances root-shadow value/timestamp ownership only after a matching physical acceptance token, overwrites rejected scratch generations on retry, filters rejected events, and publishes the accepted tissue, scheduler, token, history, and routing generations only through joint commit. Each accepted physical token now dispatches a canonical GPU scheduler/regional prefix immediately, so pain, support-loss, impact, and other accepted interrupts are available before the next physical candidate; a rejected candidate dispatches no such prefix and leaves the accepted fast shadow exact. It does not yet implement a live NumanX adapter, protective motor output, calibrated receptors or conduction velocity, learned/context-conditioned routing, differentiable training routing, dense tiled regional matrices, GPU-native plan construction, the complete 96-module graph, learning, memory, or motor control.

The next runtime-foundation work maps the accepted fast regional shadow into protective spinal/brainstem output for the following physical candidate, then connects that loop to a live NumanX adapter. Incremental fast regional generations can replace the current bounded canonical-prefix recomputation after exact parity is retained. GPU-native plan construction, immutable successor-buffer activation across runtimes, persistent checkpoints, and private-heap state storage follow. Routing still needs learned/context-conditioned biases, capacity balancing, and its differentiable training form. Later phases add calibrated causal receptor adapters, body schema, protective and motor systems, world modeling, motivation, skills and planning, memory, development, communication, and persistent life mode.

No phase is intended as a throwaway implementation.
