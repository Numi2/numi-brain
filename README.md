# NumiBrain

NumiBrain is the standalone Apple-native nervous-system runtime for embodied humans, animals, and robots inside NumiLab. It is designed to couple transactionally to NumanX while keeping the normal perception-to-action loop GPU resident on Apple M4/M5-family hardware through Metal 4.

> Status: formal architecture specification. The runtime is not implemented or qualified yet.

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

The architecture is defined by [NumiBrain v1.0](docs/NUMIBRAIN_V1_SPEC.md). Implementation claims and current readiness are tracked in [STATUS.md](STATUS.md).

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

The first authoritative vertical slice is runtime foundation: state ABI, multi-rate scheduling, event queues, regional primitives, immutable parameter versions, deterministic random generation, nested transactions, and NumanX buffer interop. Later phases add causal receptors, body schema, protective and motor systems, world modeling, sparse routing, motivation, skills and planning, memory, development, communication, and persistent life mode.

No phase is intended as a throwaway implementation.
