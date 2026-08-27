# Implementation status

## Repository

- Canonical repository name: `numi-brain`
- Canonical architecture: NumiBrain v1.0
- Current state: specification, GPU-compacted tissue source slice v0.11, scheduler CPU oracle v0.1, and integrated Metal scheduler/regional path v0.7
- Implemented runtime code: deterministic scheduler, recurrent regional-token, diagnostic-state, route-history, routing-state, and tissue CPU oracles plus a Metal 4 structured delayed-sheet runtime with a compiled 64-byte receptor-event ABI, causal onset-plus-latency interrupt transduction, a private merged interrupt queue, transactional module clocks, due-list compaction and consumption, 10,752 region-major token scalars, immutable factorized parameters, seven candidate sparse regional routes with timestamped conduction history, deterministic content-scored top-k selection, route persistence, emergency bypass, compact selected-route gathering, counter randomness, and a destination-major tissue CSR graph
- Build and test system: Swift Package Manager and XCTest
- Metal kernels: bounded receptor-event compaction, FP32 Wilson-Cowan-family tissue integration, receptor-onset interrupt transduction, compiled-ABI multi-rate due selection, and timestamp-synchronous recurrent regional-token integration with private transactional interrupt, token, diagnostic, route-history, and routing-state generations
- NumanX interop: none
- Checkpoint or replay artifacts: exact JSON replay evidence is checked in; persistent runtime checkpointing is not implemented
- GPU performance evidence: bounded Apple M4 Pro remote correctness probe only; production throughput and counter qualification remain pending

The architecture document remains a design contract. Only the tissue and scheduler behavior owned by the source and tests in this repository is currently live.

## Scheduler foundation evidence

The scheduler foundation currently proves:

- a C++-compiled standard-layout ABI with 32-byte module descriptors, 16-byte module clocks, 24-byte interrupt events, and 32-byte due invocations;
- explicit ABI offsets, compile-time size assertions, validation codes, and field-wise fingerprints independent of struct padding;
- integer physical-microsecond timestamps without wall-clock scheduling or floating-point due-time drift;
- explicit per-module period, conduction delay, intrinsic timescale, interrupt mask, token shape, clock class, and logical identifier;
- deterministic periodic boundaries with no duplicate update when adjacent control transactions share a timestamp;
- event-time pain, damaging-contact, support-loss, impact, physiological-critical, joint-limit, overload, and rescue interruption independent of the normal period;
- merging of a periodic due time and one or more interrupts into one causally timestamped invocation;
- shadow transactions whose abort changes no committed clock and whose retry reproduces the same invocation list;
- checkpoint schedule-fingerprint, clock-count, and committed-time validation;
- independent per-agent scheduler snapshots with shared immutable module descriptors;
- deterministic cohort grouping by timestamp, clock class, module, and environment identifier;
- validated serialization that recomputes and checks the compiled schedule fingerprint;
- C++/Swift/Metal size parity for descriptors, clocks, interrupts, invocations, scheduler uniforms, and result records;
- C++/Swift/Metal size parity for the 64-byte receptor event and 40/16-byte transduction records;
- causal onset-plus-conduction-latency conversion with no future leakage or adjacent-root boundary duplication;
- a private GPU queue that canonically merges receptor-derived and host interrupt packets without a hot-path count readback;
- exact CPU/Metal receptor-interrupt and emergency-module parity through rejected retry and full root abort;
- one `schedule_due_modules` dispatch per root inside the tissue command encoder;
- private committed/shadow clock generations and a private compacted due list;
- exact CPU/Metal parity for periodic boundaries and fractional-time pain/support interrupts;
- joint tissue-scheduler retry, abort, commit, and replay behavior;
- no per-root scheduler readback, with explicit staging only after completion;
- one `advance_due_regional_tokens` threadgroup that consumes the private canonical due list without a host count readback;
- 10,752 FP32 region-major token scalars across the eight executable module shapes;
- compiled 32-byte token layouts with per-receiver normal-route budgets, 24-byte sparse route records, 32-byte per-scalar immutable parameter records, a fingerprinted 48-byte version-2 program header, and 32-byte per-agent route-runtime records;
- seven candidate sparse routes scored from a common causal pre-timestamp state;
- deterministic normal-route top-k selection with canonical route-index tie breaking;
- permanent emergency-route bypass outside the normal budget;
- a 2 ms minimum route-persistence interval and explicit persistence score bonus;
- stable softmax normalization over selected emergency and normal routes;
- compact selected-route index spans consumed by the recurrent scalar gather;
- compiled 0-5 ms route delays resolved from per-route 512-slot timestamped message rings;
- conservative configuration-time capacity validation that rejects a route-history overwrite risk before dispatch;
- gated recurrent updates using module intrinsic timescales, local token context, periodic or interrupt drive, and routed input;
- compact 32-byte module diagnostics with activation, integration, interrupt salience, phase, counters, and last-update time;
- CPU/Metal token, diagnostic, delayed route-history, score, and strength numerical parity plus exact discrete counters, selections, switches, and timestamps;
- a Metal route-ablation test that changes receiver tokens while preserving tissue and diagnostic state;
- recurrent token, route-history, and routing-state replay, retry, abort, and control-interval chunking equivalence.

The executable reference subset contains eight logical roles from the 96-module graph at periods from 1–100 ms. The CPU oracle and bounded one-agent Metal kernels share the compiled ABI and deterministic semantics. The token operator is authoritative regional neural state; the compact trace is diagnostic metadata. Learned/context-conditioned route biases, capacity balancing, differentiable training routing, dense tiled matrices, fast-plastic bases, GPU cohort prefix sums, indirect execution, adaptive periods, learned production weights, and the complete 96-module graph remain unimplemented.

The checked v0.1 scheduler probe on 2026-08-27 used commit `579afea` and advanced four independent scheduler states through 200 ms in ten root transactions. It emitted 3,064 invocations, compacted them into 772 canonical groups, and delivered eight module interrupts from three fractional-time source events with zero timestamp latency. Replay, retry, abort, independent-state, and canonical-order checks passed. The exact JSON is in [`evidence/scheduler-v0.1`](evidence/scheduler-v0.1/README.md). This is CPU semantic evidence, not GPU scheduler or throughput qualification.

## Implemented tissue and regional evidence

The v0.11 source slice retains the v0.10 dynamic-routing behavior and additionally proves a compiled receptor-event ABI, GPU-resident onset interrupt transduction, causal latency, boundary deduplication, emergency-module delivery, and shared transaction semantics. A bounded local Apple M4 artifact is checked into [`evidence/tissue-v0.11`](evidence/tissue-v0.11/README.md). A new checked remote evidence bundle has not yet been produced; the latest checked Apple M4 Pro evidence remains v0.8 because the Mini was occupied by an existing crow evaluation.

The implemented tissue slice currently proves:

- finite, bounded resting-state integration;
- transient activation from a physically timed localized input;
- short-range recruitment outside the direct input footprint;
- a finite-time axonal relay that lags local population recruitment;
- explicit per-site outgoing delay classes sampled from a 32-step FP32 relay-history ring;
- delayed lateral recruitment relative to an instantaneous-conduction control;
- delayed long-range recruitment at a target outside the source's local stencil;
- deterministic canonicalization and hashing of the destination-major sparse projection graph;
- deterministic canonicalization and hashing of a bounded timestamped receptor-event schedule;
- compiled 64-byte receptor records with interrupt class, conduction latency, receptor identity, magnitude, and auxiliary metadata;
- one private GPU receptor-interrupt transduction dispatch per accepted root;
- latency-shifted pain delivery to nociceptive, emergency-bus, and spinal modules at the CPU-oracle timestamp;
- no receptor-onset redelivery at an adjacent committed boundary;
- deterministic half-open active-event selection and maximum-overlap accounting;
- future events do not affect tissue state before their timestamps;
- bounded receptor-drive noise changes across committed sample keys and seeds;
- the counter generator has no mutable state and includes accepted step, event, site, and sample lane in its key;
- deterministic synthetic tissue strata with per-site excitatory, inhibitory, coupling, and viability coefficients;
- exact silence and blocked outgoing transmission for zero-viability lesion sites;
- inhibitory/adaptation-driven recovery;
- bit-exact CPU replay for a fixed noisy-event acceptance/rejection schedule;
- bit-exact root abort and rejected-substep retry;
- identical noisy, delayed local and long-range future state after root abort or rejected-substep retry;
- Metal 4 execution through `MTL4CommandQueue`, a reusable `MTL4CommandBuffer`, `MTL4ComputeCommandEncoder`, and `MTL4ArgumentTable`;
- one GPU `compact_receptor_events` dispatch per attempted substep, including rejected candidates;
- explicit compaction-to-tissue device barriers and private active-index storage with no hot-path CPU readback;
- tissue-site event work restricted to compacted due indices rather than the full immutable schedule;
- CPU/Metal agreement within an FP32 tolerance.
- delayed regional messages remain withheld until their compiled conduction timestamp;
- CPU/Metal agreement for route-history state, publication timestamps, and FP32 message values;
- route-history rollback, retry, replay, and root-window chunking equivalence.
- route scores and normalized strengths agree between CPU and Metal within FP32 tolerance;
- content changes which normal route wins deterministic top-k selection while an emergency route remains continuously active;
- route selection counters, last-selected timestamps, and switch counters agree exactly between CPU and Metal;
- routing state rolls back, retries, replays, and chunks at the same transaction boundary as tokens and route history.

The XCTest suite contains 42 passing tests: 14 tissue CPU tests, 13 scheduler/regional CPU tests, and 15 Metal 4 tests. Golden vectors pin the random and module ABI fingerprints. Causality and seed tests require future-event silence, exact receptor latency and boundary semantics, and seed-dependent trajectories. Metal tests require exact receptor-derived and host scheduler invocation parity, recurrent token, route-history, and routing-state CPU numerical parity, dynamic-selection, delayed-message, emergency-bypass and route-ablation causality, and joint retry, abort, replay, and chunking equivalence.

The Metal history ring uses two private 32-slot FP32 relay planes plus one rejected-candidate scratch plane. It costs 256 history bytes per site, excluding state, structure, delay, sparse graph, events, scratch, uniforms, and inspection staging. The graph adds four bytes per destination offset and 16 bytes per packed edge. Each immutable receptor event uses one compiled 64-byte record. The fixed-capacity active-index buffer uses 260 private bytes: one count plus 64 event indices. The scheduler owns a 1,536-byte private transduced-interrupt queue and a 16-byte private result in addition to the host event view. A Metal root transaction may accept at most 32 substeps so the abort-authoritative plane cannot be overwritten; the canonical 20 ms control interval is within that boundary.

The latest checked Apple M4 Pro development probe on 2026-08-27 used source commit `a237cac`, a 256×192 GPU-compacted noisy-event sparse-projection delayed layered sheet, a circular partial-viability lesion, and 70 accepted 1 ms substeps. It issued 70 event-compaction, four scheduler, and four regional-token dispatches. The eight-module schedule committed to 70,000 microseconds at generation 4 with clock hash `7f0410c814a02d9c`, zero device status, and exact CPU clock parity. The regional program fingerprint was `7693586fd2b592a9`; it consumed 271 module invocations, advanced 10,752 token scalars through seven routes, produced token hash `5cc6cce810370af4`, and reported `1.1920929e-07` maximum CPU/Metal token error. Diagnostic hash `d78c1c595e2fe734` retained exact discrete CPU state and `1.4901161e-08` maximum float error. The primary tissue hash was `1d4534c321f98fe7`; matched no-noise and alternate-seed controls produced `3db4f53ab3fd8e42` and `73d0eb346080c5de`. All three runs replayed exactly, preserved delayed retry and root abort, and reported `1.1920929e-07` maximum tissue CPU/Metal error. The JSON controls and inspected PNG are in [`evidence/tissue-v0.8`](evidence/tissue-v0.8/README.md). This is implementation evidence, not calibrated receptor, learned cognition, or brain-tissue behavior and not a production GPU benchmark.

The source commit and v0.8 evidence were built and executed through `/Users/n/numi-brain` on `macmini` after confirming no competing crow or Numi workload. The recorded 0.0151802 GPU seconds are retained as bounded run telemetry, not promoted as a throughput claim; same-workload counter capture and production-cohort qualification remain pending.

## Local Numi Lab readiness snapshot

Checked on 2026-08-27:

- Numi Lab: 0.4.0
- Runtime root: `/Users/home/Documents/emergentnumilife/MetalRobo`
- Runtime revision: `2035cfd`
- Runtime branch: `coupled`
- Workspace: `/Users/home/numi-brain`
- Apple Silicon: available
- Metal tools: available
- MLX learner: available
- `numi doctor`: action required because the existing robot-catalog self-check was killed and reported incompatible

This is an external runtime readiness observation. The shared MetalRobo checkout was not modified while creating this repository.

## First implementation gate

The tissue slice is not Phase 1 completion. Phase 1 is complete only when a minimal brain state can advance, reject, restore, retry, and atomically commit with NumanX without hot-path CPU copies, while preserving counter-based random streams and byte-stable committed replay under physical substep rejection.
