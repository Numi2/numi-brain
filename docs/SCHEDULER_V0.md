# Multi-rate scheduler and module ABI v0.2

This document defines the executable runtime-foundation scheduler slice. It establishes a compiled binary contract, deterministic CPU oracle, and Metal due-selection kernel for physical-time module scheduling. The Metal path shares the tissue runtime's command queue, reusable command buffer, encoder, residency set, and root transaction.

## Ownership boundary

- `NumiBrainABI` C++ owns fixed record sizes, offsets, validation, and descriptor fingerprints.
- `NumiBrainCore` Swift owns the deterministic CPU oracle, typed configuration, checkpoint validation, and evidence orchestration.
- Metal owns due-time advancement, event interruption, invocation compaction, and private shadow clocks in the normal tissue execution path.
- Swift publishes clock-generation ownership only after the shared tissue-scheduler GPU submission completes successfully.

This separation prevents Swift object layout or synthesized serialization from becoming an accidental runtime ABI.

## Stable records

ABI version 1 compiles the following standard-layout records:

| Record | Bytes | Purpose |
| --- | ---: | --- |
| `NBModuleDescriptor` | 32 | Immutable module identity, timing, interrupt, and token shape |
| `NBModuleClockState` | 16 | Per-agent next-due and last-update physical time |
| `NBInterruptEvent` | 24 | Timestamped receptor-derived interrupt class |
| `NBDueInvocation` | 32 | Compacted environment/module execution request |
| `NBSchedulerUniforms` | 40 | Root physical-time window, capacities, identity, and initialization flags |
| `NBSchedulerResult` | 16 | Device invocation count, typed status, and target time |

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

Events earlier than committed scheduler time or later than the current transaction target are rejected. The v0.2 Metal path consumes a bounded committed input view from shared unified memory. Dynamic NumanX-owned GPU event queues will later replace that upload view and retain future packets; neither the CPU nor Metal path silently accepts and drops one.

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

The integrated Metal path uses two private clock generations. `schedule_due_modules` reads the committed generation and overwrites the other generation after the accepted tissue candidate sequence on the same compute encoder. A root commit swaps tissue and scheduler generation ownership together. Abort leaves the committed clock pointer, time, and generation unchanged. Rejected physical attempts affect the accepted target time only when simulated time actually advances.

The compacted due-invocation buffer and result header remain private. Explicit inspection stages them only after command completion; the control loop performs no invocation-count readback. Regional neural operators do not consume this list yet.

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

These are scheduling roles only. They do not yet execute their regional neural operators.

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
11. C++, Swift, and Metal agree on all six ABI record sizes.
12. Metal periodic and fractional-time interrupt invocations exactly equal the CPU oracle.
13. One scheduler dispatch runs on the same encoder after each accepted tissue root sequence.
14. Rejected retry and root abort preserve private scheduler clocks together with tissue history.
15. Schema-v6 inspection reports zero device status, exact CPU scheduler parity, committed time, generation, memory capacity, and snapshot hash without per-root readback.

Passing these gates establishes Metal residence for bounded one-agent due selection and the shared transaction boundary. It does not establish regional module execution, large-cohort throughput, GPU prefix-sum grouping, adaptive periods, biological timing calibration, or Phase 1 completion.
