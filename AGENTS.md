# NumiBrain contributor contract

This file applies to the entire repository.

Read `docs/NUMIBRAIN_V1_SPEC.md` before changing architecture, state ownership, scheduling, transactions, observation/action contracts, or learning boundaries.

## Authority and ownership

- NumanX owns authoritative physical state and evolution.
- NumiBrain owns neural state, belief, memory, motivation, decisions, plasticity, and neural control.
- C++ or Objective-C++ compiles and validates stable packs, indices, capacities, ABI, and fingerprints.
- Metal owns the device-resident hot loop: neural execution, sensing, event processing, state, routing, inference, counter-based randomness, and transaction kernels.
- Swift owns bounded rollout orchestration, asynchronous submission/wait boundaries, checkpoint requests, timeouts, resets, revision publication, and typed errors.
- MLX owns batch learning from committed artifacts and publication of new immutable parameter versions. It does not step production physics.

Change the lowest owning layer that can express the requested behavior. Do not introduce a Python stepping path, per-environment host loop, second GPU command timeline, or hot-path readback.

## Non-negotiable runtime rules

- Normal brain inputs must be physically realizable receptor outputs with modeled delay, noise, adaptation, and active-sensing effects. Privileged teacher data remain graph-isolated.
- NumiBrain emits muscle excitation, autonomic commands, sensing commands, and internal control. It never writes authoritative pose, velocity, or contact force.
- Every neural module uses physical simulation time, explicit timestamps, and its configured rate. Emergency routes bypass ordinary sparse capacity.
- A physical retry preserves the high-level decision, stochastic samples, option, plan, episodic intent, and random counters unless committed simulated time advances.
- Only a root commit may publish recurrent state, belief, workspace, delays, CPG phases, drives, plasticity, memory journals, competence updates, allocators, and random counters.
- Only committed transitions enter learning data. Imagined transitions remain identified as imagined and never become lived episodic memory.
- Shared slow parameters are immutable during a rollout cohort and are replaced only by fingerprinted version publication at a synchronization boundary.
- Per-agent recurrent state, memory, drives, plasticity, plans, developmental state, and random streams are never shared between minds.

## Evidence language

Keep these claims separate:

- specified in architecture;
- represented by owning source code;
- builds for an Apple target;
- executes on a named Apple GPU/runtime path;
- passes deterministic transaction/replay tests;
- meets measured throughput, memory, counter, and physical-outcome gates.

Never infer a later claim from an earlier one. Preserve failed or rejected evidence and report the exact revision, device, arguments, artifacts, failed steps, replay result, memory use, and available counters for executable qualification.

## Repository hygiene

- Preserve unrelated and generated user work.
- Keep local `.numi/logs/` and `.numi/runs/` evidence unless explicitly asked to remove it.
- Avoid broad generated scaffolding. Add source directories as their owning phase becomes executable.
- Prefer deterministic, bounded tests before long GPU runs.
- Do not move real hardware without the configured owner approval, verified limits, and an emergency stop.
