# Multi-rate scheduler and module ABI v0.7

This document defines the executable runtime-foundation scheduler slice. It establishes a compiled binary contract, deterministic CPU oracle, Metal due-selection kernel, and schedule-driven recurrent regional-token operator. The Metal path shares the tissue runtime's command queue, reusable command buffer, encoder, residency set, and root transaction.

## Ownership boundary

- `NumiBrainABI` C++ owns fixed record sizes, offsets, validation, and descriptor fingerprints.
- `NumiBrainCore` Swift owns the deterministic CPU oracle, typed configuration, checkpoint validation, and evidence orchestration.
- Metal owns due-time advancement, event interruption, invocation compaction, and private shadow clocks in the normal tissue execution path.
- Metal consumes the resulting private due list through the recurrent regional-token kernel.
- Swift publishes clock-generation ownership only after the shared tissue-scheduler GPU submission completes successfully.

This separation prevents Swift object layout or synthesized serialization from becoming an accidental runtime ABI.

## Stable records

ABI version 1 compiles the following standard-layout records:

| Record | Bytes | Purpose |
| --- | ---: | --- |
| `NBModuleDescriptor` | 32 | Immutable module identity, timing, interrupt, and token shape |
| `NBModuleClockState` | 16 | Per-agent next-due and last-update physical time |
| `NBReceptorEvent` | 64 | Canonical tissue drive plus interrupt, latency, receptor identity, and magnitude metadata |
| `NBInterruptEvent` | 24 | Timestamped receptor-derived interrupt class |
| `NBReceptorEventTransductionUniforms` | 40 | Root interval and bounded input/output queue counts |
| `NBReceptorEventTransductionResult` | 16 | Private compacted event counts and typed status |
| `NBDueInvocation` | 32 | Compacted environment/module execution request |
| `NBSchedulerUniforms` | 56 | Root physical-time window, parameter/schedule identity, capacities, and initialization flags |
| `NBSchedulerResult` | 16 | Device invocation count, typed status, and target time |
| `NBRegionalModuleState` | 32 | Compact population trace, counters, phase, and last-update time |
| `NBRegionalTokenLayout` | 32 | Region-major token, incoming-route span, and normal-route budget |
| `NBRegionalRoute` | 24 | Compiled sparse message edge |
| `NBRegionalTokenParameters` | 32 | Immutable factorized recurrence and gate coefficients per scalar |
| `NBRegionalProgramHeader` | 48 | Versioned program counts, routing policy constants, and fingerprint |
| `NBRegionalRouteHistoryState` | 16 | Timestamped causal-message ring cursor |
| `NBRegionalRouteRuntimeState` | 32 | Per-agent route score, strength, selection, persistence, and counters |
| `NBParameterComponent` | 32 | Canonical immutable shared-parameter component identity |
| `NBParameterVersionBinding` | 64 | Version, parent, schedule, regional shape/content, and total-byte identity |

The module descriptor layout is:

| Offset | Field | Type |
| ---: | --- | --- |
| 0 | module identifier | `uint16` |
| 2 | clock class | `uint16` |
| 4 | update period | `uint32` microseconds |
| 8 | conduction delay | `uint32` microseconds |
| 12 | intrinsic timescale | `uint32` microseconds |
| 16 | event-interrupt mask | `uint64` |
| 24 | local token count | `uint16` |
| 26 | local token dimension | `uint16` |
| 28 | flags | `uint32` |

The compiled validator rejects zero identifiers, noncanonical or duplicate identifiers, zero periods, zero intrinsic timescales, and zero token shapes. The fingerprint is FNV-1a over explicit little-endian fields, beginning with ABI version and descriptor count; it never hashes padding bytes.

## Physical-time semantics

Scheduler timestamps are unsigned 64-bit integer microseconds. They represent committed simulation time, not wall time.

Every module owns:

- a stable logical identifier;
- a clock class;
- an explicit update period;
- a conduction delay;
- an intrinsic state timescale;
- an event-interrupt mask;
- a local token shape;
- a per-agent next-due timestamp;
- a per-agent last-update timestamp.

At a target time `T`, a shadow scheduler transaction emits every periodic due time satisfying

\[
t_{next} \le T
\]

and advances the shadow next-due value by the exact integer period until it lies after `T`. A subsequent transaction therefore cannot repeat a boundary already emitted by the previous transaction.

## Event interruption

Interrupt events carry a physical timestamp and a bit mask. An event immediately activates every module whose configured mask intersects the event mask, even if its next periodic update is later. Pain, damaging contact, loss of support, impact, physiological critical state, joint limit, muscle overload, sound onset, visual transients, and rescue have distinct bits.

If a module is both periodically due and interrupted at the same timestamp, the oracle emits one invocation with both reasons. Multiple matching events at the same module and timestamp merge their masks. Interrupts do not reset the periodic clock.

Events earlier than committed scheduler time or later than the current transaction target are rejected. Receptor events carry an onset, interrupt mask, receptor identity, and conduction latency. Their effective interrupt timestamp is the onset plus latency. The first root includes an onset at its committed lower boundary; later roots exclude that boundary so an event cannot be delivered twice. Future receptor events stay in the immutable schedule without entering the current compact queue.

The Metal path dispatches `transduce_receptor_interrupts` after the accepted tissue sequence. One deterministic lane merges due receptor onsets with the bounded host input view, sorts the combined 24-byte records by timestamp, identifier, mask, and flags, and writes a private GPU interrupt queue plus private result header. `schedule_due_modules` consumes that result after a device barrier without a CPU count readback. The CPU oracle independently derives the same records from the 64-byte receptor ABI. Dynamic NumanX-owned GPU event queues will later replace the host upload view and immutable development schedule.

## Transactions and checkpointing

`beginAdvance` computes shadow clocks and invocations without mutating committed state. A transaction records:

- the schedule fingerprint;
- base generation;
- base committed timestamp;
- target timestamp;
- deterministic invocation list;
- proposed per-module clocks.

Commit succeeds only when the fingerprint, generation, base time, and clock count match the current scheduler. Abort is discarding the value transaction. Repeating a rejected transaction with the same target and events yields the same invocation list.

A checkpoint restore validates schedule identity, clock count, next-due time, and last-update time before accepting state.

Snapshots and transactions also bind a parameter-version fingerprint. Restore, commit, stable snapshot hashing, and cohort compaction reject a different or mixed version. The Metal scheduler validates the same fingerprint and schedule against a private immutable `NBParameterVersionBinding`; the regional kernel separately validates the active regional program. See [PARAMETER_VERSIONING_V0.md](PARAMETER_VERSIONING_V0.md).

The integrated Metal path uses two private clock generations. `schedule_due_modules` reads the committed generation and overwrites the other generation after the accepted tissue candidate sequence on the same compute encoder. A root commit swaps tissue and scheduler generation ownership together. Abort leaves the committed clock pointer, time, and generation unchanged. Rejected physical attempts affect the accepted target time only when simulated time actually advances.

The compacted receptor-interrupt queue, transduction result, due-invocation buffer, and scheduler result header remain private. Explicit inspection stages result metadata only after command completion; the control loop performs no event- or invocation-count readback.

This v0.6 bridge preserves event time and root transaction semantics, but it dispatches after the accepted tissue candidate sequence. It does not yet provide a mid-NumanX-substep protective interrupt path; that requires the nested NumanX transaction interface and fast-system loop.

## Recurrent regional execution

After a device barrier, `advance_due_regional_tokens` assigns one bounded Metal threadgroup to the agent. Its lanes stride across 10,752 region-major FP32 scalars. For each due timestamp, they evaluate local token means, compiled sparse routed input, immutable factorized recurrence, periodic or interrupt drive, and a learned-form update gate. All modules at that timestamp read the same pre-timestamp state; delayed routes resolve the newest timestamped message no later than their conduction boundary, then all candidates and outgoing messages publish after device barriers.

Two private token generations and two private diagnostic generations track the scheduler clock generations. Commit publishes tissue, scheduler clocks, token state, and diagnostics together; abort publishes none. The 32-byte diagnostic record retains update counts, interrupt counts, phase, salience, and last-update time, but is no longer the authoritative regional neural state. The token operator has a deterministic CPU numerical oracle and performs no hot-path readback.

The executable token program is fingerprinted and immutable during rollout. Seven candidate sparse routes provide the first live routed input sum with compiled 0-5 ms delays and transaction-owned 512-slot message rings. At each due receiver timestamp, the deployment path deterministically scores causal messages, retains routes inside a 2 ms minimum-persistence interval, fills the receiver's normal top-k budget with canonical tie breaking, includes every emergency route outside that budget, normalizes the selected strengths, and gathers compact selected indices. Two private route-runtime generations commit scores, selections, timestamps, and counters with tokens and clocks. Learned/context-conditioned routing, capacity balancing, differentiable training routing, dense tiled matrices, fast-plastic bases, and indirect cohort dispatch remain unimplemented. See [REGIONAL_TOKEN_V0.md](REGIONAL_TOKEN_V0.md).

## Cohort compaction oracle

Independent agent transactions share immutable descriptors but retain separate clocks. The CPU reference compacts their invocations into groups ordered by:

1. physical timestamp;
2. clock class;
3. module identifier;
4. environment identifier within the group.

This remains the semantic oracle for later GPU prefix-sum and indirect-dispatch kernels. The current Metal kernel deterministically schedules one agent with one lane inside the integrated runtime. It proves device ownership and transaction semantics, not large-cohort compaction or throughput.

## Executable reference subset

The first executable schedule activates eight logical roles:

| Module | Role | Period |
| ---: | --- | ---: |
| 12 | temperature and nociception | 1 ms |
| 25 | workspace broadcast | 50 ms |
| 26 | emergency interrupt bus | 1 ms |
| 37 | fast sensory dynamics | 20 ms |
| 77 | latent planner | 100 ms |
| 83 | cerebellar context selector | 5 ms |
| 90 | locomotor CPG | 2 ms |
| 95 | reflex interneuron network | 1 ms |

These names define scheduling roles. Every role currently executes the common factorized recurrent operator with its own shape and parameter span, not its final role-specific learned model.

## Evidence gates

1. C++ compile-time sizes and offsets equal the published ABI.
2. Descriptor order is canonical and the golden fingerprint is stable.
3. Adjacent control windows do not duplicate their shared boundary.
4. Fractional-time critical events interrupt matching modules without waiting for their period.
5. Periodic and interrupt reasons merge at an identical timestamp.
6. Rejected and retried transactions are identical.
7. Root abort leaves committed clocks unchanged.
8. Restored checkpoints reproduce the same future schedule.
9. Stale transactions, stale events, and corrupted serialized fingerprints fail closed.
10. Cohort groups retain canonical environment order and independent per-agent state.
11. C++, Swift, and Metal agree on all scheduler and regional ABI record sizes.
12. Metal periodic and fractional-time interrupt invocations exactly equal the CPU oracle.
13. One scheduler dispatch runs on the same encoder after each accepted tissue root sequence.
14. Rejected retry and root abort preserve private scheduler clocks together with tissue history.
15. Schema-v6 inspection reports zero device status, exact CPU scheduler parity, committed time, generation, memory capacity, and snapshot hash without per-root readback.
16. C++, Swift, and Metal agree on the 32-byte regional-state ABI.
17. Every accepted root dispatches one regional kernel after due selection on the same encoder.
18. Regional floating state matches the CPU oracle within FP32 tolerance; counters and timestamps match exactly.
19. Regional state is bit-exact across replay and rejected retry, unchanged by abort, and state-equivalent across control chunking.
20. Schema-v7 records regional diagnostic dispatches, state bytes, update totals, snapshot hash, and CPU parity.
21. The compiled token layouts cover 10,752 contiguous region-major FP32 scalars and exactly seven canonical incoming routes.
22. Delayed routes remain silent before their conduction boundary and match the persistent CPU route-history oracle after delivery.
23. Route-history metadata, timestamps, and values are restored on abort and reproduce under retry, replay, and control-window chunking.
24. Configurations whose event and timestep bounds could overwrite an undelivered route message fail before dispatch.
25. C++ validation rejects layout, route, token-range, nonfinite-parameter, delay-range, and history-layout drift.
26. CPU and Metal token states agree within declared FP32 tolerance across consecutive roots.
27. A Metal route ablation changes the compiled receiver token state while tissue and scheduler diagnostics remain identical.
28. Token generations are exact across replay and rejected retry, unchanged by abort, and state-equivalent across control-window chunking.
29. Schema-v9 records program fingerprint, token and route-history snapshot hashes, token, parameter, and route-history memory, and CPU parity.
30. Version-2 regional programs fingerprint per-receiver route budgets, minimum persistence, and score constants.
31. CPU and Metal agree on route scores and strengths within FP32 tolerance and exactly on active flags, selection counters, last-selected timestamps, and switch counters.
32. Different sender-token content changes the normal top-k winner while the emergency route remains active.
33. Route-runtime generations retry, abort, replay, and chunk at the same transaction boundary as tokens, history, clocks, and tissue.
34. Schema-v10 records route budgets, routing memory, active-route counts, routing snapshot identity, and CPU parity.
35. C++, Swift, and Metal agree on the 64-byte receptor record and 40/16-byte transduction records.
36. A receptor onset plus conduction latency produces the same timestamped interrupt in the CPU oracle and private Metal queue, without future leakage.
37. A committed lower-bound onset is included only for initialization and is not delivered again in the adjacent root.
38. Rejected candidates and full root abort do not change the derived interrupt, scheduler clocks, or regional effects on retry.
39. Schema-v11 records receptor ABI size, interrupt class, latency, transduction dispatches, private queue/result memory, event counts, typed status, and CPU parity.
40. C++, Swift, and Metal agree on the 32-byte parameter component, 64-byte binding, and 56-byte scheduler uniforms.
41. CPU snapshots, transactions, restore, stable hashes, and cohort compaction bind one parameter fingerprint.
42. Metal scheduler and regional execution validate one private immutable version binding before publishing neural state.
43. Schema-v12 records sequence, version, parent, components, parameter bytes, shape/content identity, binding memory, and exact CPU version parity.

Passing these gates establishes Metal residence for bounded one-agent due selection, recurrent regional token execution, deterministic delayed top-k sparse messages, and the shared transaction boundary. It does not establish learned production weights or route projections, differentiable training routing, dense tiled operators, large-cohort throughput, GPU prefix-sum grouping, adaptive periods, biological timing calibration, or Phase 1 completion.
