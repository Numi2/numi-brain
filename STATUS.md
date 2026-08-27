# Implementation status

## Repository

- Canonical repository name: `numi-brain`
- Canonical architecture: NumiBrain v1.0
- Current state: specification, tissue source slice v0.18 with variable-duration physical-time CPU and Metal relay paths, scheduler CPU oracle v0.1, immutable parameter-manifest/publication boundary v0.12, compiled NumanX joint-transaction contract v0.7 with accepted-only fast regional prefixes, corrected-duration interactive Metal tissue candidates, and a GPU-resident protective command for the next candidate, versioned cohort-dispatch boundary v0.20 with parallel GPU environment-major invocation compaction plus per-agent routed token, delayed-history, and routing-state generations, and integrated Metal scheduler/regional/protective path v0.10
- Implemented runtime code: deterministic scheduler, immutable shared-parameter registry, compiled versioned cohort plans, recurrent regional-token, diagnostic-state, route-history, routing-state, and tissue CPU oracles including bounded physical-timestamp relay interpolation plus a Metal 4 structured fixed-step delayed-sheet runtime with a compiled 64-byte receptor-event ABI, compiled 32/64-byte parameter manifest records, causal onset-plus-latency interrupt transduction, a private merged interrupt queue, private parameter-version validation, transactional module clocks, due-list compaction and consumption, deterministic multi-agent timestamp/module grouping, private region-major dispatch materialization, GPU-generated work expansion and environment-major invocation compaction, independent compact diagnostic plus 10,752-scalar authoritative routed cohort-token, delayed-history, and dynamic routing-state generations, immutable factorized parameters, seven candidate sparse regional routes with timestamped conduction history, deterministic content-scored top-k selection, route persistence, emergency bypass, compact selected-route gathering, counter randomness, and a destination-major tissue CSR graph
- Build and test system: Swift Package Manager and XCTest
- Metal kernels: bounded receptor-event compaction, FP32 Wilson-Cowan-family tissue integration, receptor-onset interrupt transduction, compiled-ABI multi-rate due selection, version-bound cohort dispatch materialization, GPU-generated indirect work consumption, environment-major invocation compaction, independent compact cohort diagnostic advance, timestamp-synchronous routed regional-token integration for both one-agent and cohort execution, and protective-command derivation with private transactional interrupt, token, diagnostic, route-history, routing-state, and command generations
- NumanX interop: compiled root, nested-substep, accepted-physics, joint-commit, and 64-byte protective-command ABI plus a deterministic Swift coordinator, accepted-only receptor-event handoff, corrected-duration interactive Metal candidate advance/accept/reject/finalize APIs, accepted fast scheduler/regional/protective prefixes between physical candidates, a private GPU command-buffer view, and a joint publication guard; no live NumanX adapter, species/body command-to-muscle mapping, or cross-runtime atomic pointer publication yet
- Checkpoint or replay artifacts: exact JSON replay evidence is checked in; persistent runtime checkpointing is not implemented
- GPU performance evidence: bounded Apple M4 Pro v0.20 and Apple M4 v0.19 routed-cohort correctness, Apple M4 v0.14 lightweight indirect-consumption correctness, Apple M4 Pro accepted-fast-prefix joint v0.6 and interactive-joint v0.4 full-suite correctness, and Apple M4 Pro/M4 v0.12 and earlier tissue correctness probes only; production throughput and counter qualification remain pending

The architecture document remains a design contract. Only the tissue, scheduler, cohort, parameter-version, and transaction-contract behavior owned by the source and tests in this repository is currently live.

## Joint transaction foundation

The compiled v0.7 handoff contract currently proves:

- standard-layout 96-byte root, 72-byte substep, 64-byte accepted-physics, and 64-byte commit records;
- field-wise fingerprints that bind environment, episode, control step, immutable parameters, brain and physical generations, physical timestamps, and root random-counter generation;
- validation of record version, identity, time order, generations, flags, fingerprints, and cross-record relations;
- rejected retries that preserve accepted physical time, accepted-substep index, brain shadow generation, and random-counter generation;
- accepted physical tokens as the only operation that advances physical time and generation in the coordinator;
- exact-target commit and abort restoration semantics;
- rejection of stale substeps, wrong physical generations, early commits, oversized candidates, and post-finish mutation;
- an exact ordered resolution ledger for every rejected and accepted physical candidate;
- Metal-root validation against environment, immutable parameter, committed brain generation, accepted physical time, and random generation;
- rejection of ledger-count drift, zero or oversized candidate durations, and stale Metal generations;
- a joint-only Metal publication path that blocks brain-only commit, returns the final compiled receipt, and aborts without publishing tissue, scheduler, token, route-history, or routing-state generations.
- canonical per-candidate receptor-event packets constrained to the candidate's causal time window and marked as receptor-derived;
- rejection of untransduced and out-of-window candidate events;
- accepted candidate events entering the Metal root scheduler while events from rejected NumanX candidates produce no neural interrupt history.
- interactive GPU candidate execution before physical resolution, with accept advancing only root-shadow tissue/history ownership and reject preserving the previous accepted shadow;
- exact interactive-versus-batched committed fingerprints for tissue, scheduler output, regional state, recurrent tokens, delayed route history, and dynamic routing state;
- interactive abort, including an active GPU candidate, publishing no neural state, clock, generation, or random history.
- corrected-duration candidates integrating with their exact physical interval and resolving local and sparse conduction against accepted UInt64 timestamps;
- CPU/Metal agreement for irregular-time interpolation, exact rejected-retry timestamp ownership, and pre-dispatch rejection when the bounded history would lose required physical coverage.
- one canonical scheduler/regional prefix executing immediately after each accepted physical token, before the next candidate;
- rejected candidate events dispatching no fast prefix and leaving the latest accepted scheduler/regional shadow exact;
- final commit publishing the same fast prefix inspected before root finish when no later host-only event is supplied.
- a standard-layout fingerprinted 64-byte protective-command record carrying accepted timestamp and generation, interrupt mask, bounded withdrawal, bracing, motor-inhibition, and autonomic-arousal drives;
- one private command generation derived from the accepted scheduler/regional prefix and exposed as a GPU buffer view to the following physical candidate without a normal-path readback;
- exact CPU/Metal protective-command parity, rejected-event command silence, and root-abort restoration of the committed command.

This is a source and deterministic-test claim. NumanX has not yet returned or atomically published one of these physical-state records. The reference path synchronizes after each Metal candidate. An accepted interrupt can now produce a species-neutral protective command for the next candidate, but there is no body adapter translating it into authoritative muscle excitation or actuator output.

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
- compiled 0-5 ms route delays resolved from version-identified per-route timestamped message rings, with a 512-slot one-agent profile and a 32-slot cohort storage profile;
- history capacity included in both regional content and shape fingerprints while preserving the exact default-512 identities;
- conservative configuration-time capacity validation that rejects a route-history overwrite risk before dispatch;
- gated recurrent updates using module intrinsic timescales, local token context, periodic or interrupt drive, and routed input;
- compact 32-byte module diagnostics with activation, integration, interrupt salience, phase, counters, and last-update time;
- CPU/Metal token, diagnostic, delayed route-history, score, and strength numerical parity plus exact discrete counters, selections, switches, and timestamps;
- a Metal route-ablation test that changes receiver tokens while preserving tissue and diagnostic state;
- recurrent token, route-history, and routing-state replay, retry, abort, and control-interval chunking equivalence.
- compiled canonical component manifests and content fingerprints independent of padding;
- separate regional shape and content identities so compatible successors can change values without changing token/route ABI;
- thread-safe rollout cohort leases that prohibit parameter publication before a synchronization boundary;
- direct-successor, parent, schedule, and shape validation for publication;
- parameter-version-bound CPU transactions, checkpoints, stable hashes, and cohort compaction;
- one private 64-byte GPU binding validated by both scheduler and regional kernels.
- compiled 40-byte cohort-environment, 24-byte dispatch-group, 16-byte dispatch-entry, 48-byte plan-header, and 32-byte result records;
- source-cohort and complete-plan fingerprints that bind independent base generations, physical-time windows, schedule identity, parameter identity, groups, and entries;
- deterministic canonical grouping across input order with per-environment interrupt isolation;
- compiled rejection of group, span, environment-order, reason, identity, and serialization drift;
- one Metal 4 two-dimensional materialization kernel writing canonical timestamp/module rows and active-environment columns to private buffers;
- exact CPU-plan/Metal-output and repeated-Metal replay identity plus stale-version rejection before upload.
- compiled 32-byte expanded work items and a field-wise work-stream fingerprint;
- compiled 32-byte cohort uniforms and a field-wise recurrent cohort-state fingerprint;
- three private GPU-generated threadgroup arguments followed by an explicit device barrier and indirect consumer dispatches;
- exact indirectly consumed work-item identity without an intervening entry-count readback;
- a private GPU-generated canonical invocation span per active environment using contiguous lane ranges, a deterministic threadgroup prefix scan, and ordered scatter, field-wise fingerprinted and checked exactly against the CPU plan before evidence publication;
- one independent environment-major compact recurrent-state vector per active agent, initialized from private input state and written to a separate private output generation;
- CPU/Metal compact-state parity within `2e-6`, with exact update counts, interrupt counts, timestamps, environment ownership, interrupt isolation, and replay identity.
- compiled 32-byte cohort-token uniforms that bind schedule, regional-program, environment, per-agent scalar, and total scalar counts;
- one GPU-generated 64-lane token threadgroup per active environment with private environment-major input, candidate, and output generations;
- 10,752 authoritative recurrent token scalars per environment advanced from immutable factorized parameters without sharing agent state;
- sampled CPU/Metal token parity within `3e-6` plus exact full-cohort ownership, shape, finiteness, and replay fingerprints.
- seven routed message rings, route scores, normalized strengths, active selections, persistence counters, and timestamps owned independently by every cohort environment;
- exact per-root bounded-versus-unbounded timestamp simulation that rejects insufficient compiled route history before Metal upload;
- sampled CPU/Metal route-history, score, and strength parity within `3e-6`, exact discrete routing state, and exact full-cohort routing fingerprints and replay.

The executable reference subset contains eight logical roles from the 96-module graph at periods from 1–100 ms. The CPU oracle and bounded Metal kernels share the compiled ABI and deterministic semantics. The token operator is authoritative regional neural state; the compact trace is diagnostic metadata. Cohort plan construction remains on the CPU, while invocation compaction and routed cohort state advancement are GPU-resident after upload. Learned/context-conditioned route biases, capacity balancing, differentiable training routing, dense tiled matrices, fast-plastic bases, GPU-native cohort plan construction, adaptive periods, learned production weights, and the complete 96-module graph remain unimplemented.

The checked v0.1 scheduler probe on 2026-08-27 used commit `579afea` and advanced four independent scheduler states through 200 ms in ten root transactions. It emitted 3,064 invocations, compacted them into 772 canonical groups, and delivered eight module interrupts from three fractional-time source events with zero timestamp latency. Replay, retry, abort, independent-state, and canonical-order checks passed. The exact JSON is in [`evidence/scheduler-v0.1`](evidence/scheduler-v0.1/README.md). This is CPU semantic evidence, not GPU scheduler or throughput qualification.

The checked v0.13 Apple M4 cohort probe on 2026-08-27 used source commit `dce5d5d` and compiled one 20 ms shadow transaction across 8,192 version-bound scheduler states. It flattened 679,943 independent invocations into 90 canonical groups, materialized 10,881,280 output bytes in private Metal buffers, preserved three source-event classes as 11 isolated module deliveries, and returned zero device status. Retry, discarded-shadow, input-order, CPU-plan/Metal-output, Metal replay, and stale-version checks passed. The exact JSON is in [`evidence/cohort-dispatch-v0.13`](evidence/cohort-dispatch-v0.13/README.md). Its recorded GPU interval covers only the materialization dispatch and is not end-to-end cohort throughput, profiler, or counter evidence.

The checked v0.14 Apple M4 cohort probe on 2026-08-27 used source commit `487c248` with the same 8,192-state, 679,943-entry plan. The materializer wrote 10,625 private indirect threadgroups, crossed a device barrier, and launched the consumer without an entry-count readback. The consumer expanded 21,758,176 private bytes of exact work items with fingerprint `1e3c0e0c326b212e`; total private output was 32,639,472 bytes and device status remained zero. The exact JSON is in [`evidence/cohort-dispatch-v0.14`](evidence/cohort-dispatch-v0.14/README.md). Its recorded GPU interval covers only materialization, the barrier, and indirect consumption and is not end-to-end throughput, profiler, or counter evidence.

The checked v0.19 Apple M4 control on 2026-08-27 used source commit `e4881b5` and advanced 16 independent routed agents through one 20 ms root. Metal generated an exact 1,335-record environment-major invocation stream and independently owned 10,752 recurrent scalars, seven route states, and 24,576 history scalars per agent. Token CPU/Metal error was `1.7881393e-7`; route-history, score, and strength error was `9.536743e-7`; discrete routing state and replay were exact. The JSON and limits are in [`evidence/cohort-dispatch-v0.19`](evidence/cohort-dispatch-v0.19/README.md). This is a bounded correctness control, not M4 Pro or production-cohort qualification.

The checked v0.20 Apple M4 Pro run on 2026-08-27 used source commit `3d81a29` and advanced 256 independent routed agents through one 20 ms root after all 58 tests passed on that checkout. The 64-lane per-environment compactor produced an exact 21,255-record invocation stream from 90 canonical groups; token, route ownership, discrete routing, retry, abort isolation, and replay checks passed. Token CPU/Metal error was `1.7881393e-7`, and route-history, score, and strength error was `9.536743e-7`. The JSON and evidence boundary are in [`evidence/cohort-dispatch-v0.20`](evidence/cohort-dispatch-v0.20/README.md). The recorded GPU interval is bounded command-feedback telemetry, not production throughput or counter qualification.

## Implemented tissue and regional evidence

The v0.12 source slice retains the v0.11 receptor-interrupt behavior and adds compiled immutable parameter manifests, synchronization-boundary publication, CPU checkpoint/cohort version identity, separate regional shape/content fingerprints, and private Metal version validation. Bounded Apple M4 Pro and Apple M4 artifacts are checked into [`evidence/tissue-v0.12`](evidence/tissue-v0.12/README.md). The heavy run began only after the unrelated crow workload ended; earlier M4 Pro/M4 artifacts remain in [`evidence/tissue-v0.11`](evidence/tissue-v0.11/README.md).

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

The XCTest suite contains 76 passing tests locally: 19 tissue and timestamped-history CPU tests, 30 scheduler/regional/parameter/dispatch/joint/protective CPU tests, and 27 Metal 4 tests. Golden vectors pin the random, module, and protective-command ABI fingerprints. Tissue tests require physical-microsecond delay sampling, deterministic interpolation, fail-closed coverage loss, and exact variable-duration retry, abort, and chunking identity. Parameter, dispatch, and joint tests require canonical compiled fingerprints, serialization tamper rejection, content/shape separation, synchronization-only publication, stale checkpoint/cohort rejection, exact retry/discard identity, span-capacity rejection, independent interrupt routing, accepted-only event history, and canonical protective-drive validation. Causality and seed tests require future-event silence, exact receptor latency and boundary semantics, and seed-dependent trajectories. Metal tests require corrected-duration CPU parity, exact physical timestamp ownership, fail-closed coverage, accepted fast-prefix response, CPU-identical protective command derivation, rejected-prefix and command silence, receptor-derived and host scheduler invocation parity, immutable version identity, mismatched-manifest rejection, exact cohort materialization and replay, recurrent token, route-history, and routing-state CPU numerical parity, dynamic-selection, delayed-message, emergency-bypass and route-ablation causality, unsafe cohort-history rejection, interactive-versus-batched joint parity, and joint retry, abort, replay, and chunking equivalence.

The Metal history ring uses two private 32-slot FP32 relay planes plus one rejected-candidate scratch plane. It costs 256 history bytes per site, excluding state, structure, delay, sparse graph, events, scratch, uniforms, and inspection staging. The graph adds four bytes per destination offset and 16 bytes per packed edge. Each immutable receptor event uses one compiled 64-byte record. The fixed-capacity active-index buffer uses 260 private bytes: one count plus 64 event indices. The scheduler owns a 1,536-byte private transduced-interrupt queue and a 16-byte private result in addition to the host event view. Protective output adds two private 64-byte command generations and one shared 16-byte derivation uniform. A Metal root transaction may accept at most 32 substeps so the abort-authoritative plane cannot be overwritten; the canonical 20 ms control interval is within that boundary.

The latest checked Apple M4 Pro development probe on 2026-08-27 used source commit `45f53e4`, a 256×192 GPU-compacted noisy-event sparse-projection delayed layered sheet, and 60 accepted 1 ms substeps. It issued 60 tissue event-compaction dispatches plus three receptor-interrupt, scheduler, and regional dispatches. One 10 ms pain onset with 500 microseconds of conduction latency entered the private interrupt queue, produced three regional interrupt deliveries, and was not repeated in the final root. The scheduler committed to 60,000 microseconds at generation 3 with hash `1e425263c7384285`, zero scheduler and transduction status, and exact CPU clock parity. Tissue CPU/Metal error was `1.1920929e-07`; regional, token, route-history, and routing errors passed their declared tolerances. Replay, rejected retry, and root abort were exact. The JSON and inspected PNG are in [`evidence/tissue-v0.11`](evidence/tissue-v0.11/README.md). This is implementation evidence, not calibrated receptor, learned cognition, mid-physics-substep interruption, biological behavior, or a production GPU benchmark.

The previous v0.8 M4 Pro probe remains available for its lesion, no-noise, and alternate-seed control set. It predates dynamic regional routing and receptor-interrupt transduction.

The v0.12 source and full 48-test suite were synchronized, built, and executed through `/Users/n/numi-brain` on `macmini` after confirming no competing crow, MetalRobo, Swift, or NumiBrain workload. The M4 Pro run retained the same parameter fingerprint `f5e9c9c4aa094246`, structural fingerprint `97cc4e9a47c2baa8`, regional content fingerprint `704931c121ffb989`, and scheduler snapshot hash `79eb6335afc2f14b` as the M4 control. Recorded GPU seconds remain bounded telemetry, not a throughput or counter qualification.

The v0.11 source and full 42-test suite were synchronized, built, and executed through `/Users/n/numi-brain` on `macmini` after confirming no competing crow, MetalRobo, Swift, or NumiBrain workload. The recorded GPU seconds are retained as bounded run telemetry, not promoted as a throughput claim; same-workload counter capture and production-cohort qualification remain pending.

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
