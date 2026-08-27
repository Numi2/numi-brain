# Implementation status

## Repository

- Canonical repository name: `numi-brain`
- Canonical architecture: NumiBrain v1.0
- Current state: specification plus noisy-event sparse-projection delayed heterogeneous mesoscale tissue vertical slice v0.4
- Implemented runtime code: deterministic CPU oracle and Metal 4 structured delayed-sheet runtime with timestamped receptor events, counter randomness, and a destination-major CSR graph
- Build and test system: Swift Package Manager and XCTest
- Metal kernels: one FP32 Wilson-Cowan-family tissue step with timestamped noisy events, relay, structure, local delay field, sparse delayed projections, and transactional history ring
- NumanX interop: none
- Checkpoint or replay artifacts: none
- GPU performance evidence: bounded local probe only; remote production-size qualification pending

The architecture document remains a design contract. Only the tissue behavior owned by the source and tests in this repository is currently live.

## Implemented tissue evidence

The v0.4 slice currently proves:

- finite, bounded resting-state integration;
- transient activation from a physically timed localized input;
- short-range recruitment outside the direct input footprint;
- a finite-time axonal relay that lags local population recruitment;
- explicit per-site outgoing delay classes sampled from a 32-step FP32 relay-history ring;
- delayed lateral recruitment relative to an instantaneous-conduction control;
- delayed long-range recruitment at a target outside the source's local stencil;
- deterministic canonicalization and hashing of the destination-major sparse projection graph;
- deterministic canonicalization and hashing of a bounded timestamped receptor-event schedule;
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
- CPU/Metal agreement within an FP32 tolerance.

The current XCTest suite contains 21 passing tests: thirteen CPU oracle tests and eight Metal 4 tests. Golden counter vectors pin the shared random ABI. Causality and seed tests require future-event silence and seed-dependent trajectories. A two-event noisy CPU/Metal test validates event packing and stochastic numerical parity. Dedicated tests still require distant target recruitment, exact nonviable-site silence, and transaction equivalence beyond the sparse projection delay.

The Metal history ring uses two private 32-slot FP32 relay planes plus one rejected-candidate scratch plane. It costs 256 history bytes per site, excluding state, structure, delay, sparse graph, events, scratch, uniforms, and inspection staging. The graph adds four bytes per destination offset and 16 bytes per packed edge. Each immutable event uses three `float4` records, or 48 bytes. A Metal root transaction may accept at most 32 substeps so the abort-authoritative plane cannot be overwritten; the canonical 20 ms control interval is within that boundary.

The latest checked Apple M4 development probe on 2026-08-27 used commit `57ee1ee`, a 256×192 noisy-event sparse-projection delayed layered sheet, a circular partial-viability lesion, and 70 accepted 1 ms substeps. Its primary state hash was `1d4534c321f98fe7`; matched no-noise and alternate-seed controls produced `3db4f53ab3fd8e42` and `73d0eb346080c5de`. All three runs replayed exactly, preserved noisy delayed retry and root abort, and reported `1.1920929e-07` maximum CPU/Metal error. The JSON controls and inspected PNG are in [`evidence/tissue-v0.4`](evidence/tissue-v0.4/README.md). This is implementation evidence, not calibrated receptor or brain-tissue behavior and not a production GPU benchmark.

An M4 Pro v0 throughput run was not promoted because a new external Metal training workload began between the idle check and dispatch. The current source is synchronized to `/Users/n/numi-brain` on `macmini` after each committed development slice, but uncontended production-size v0.4 qualification remains pending.

## Local Numi Lab readiness snapshot

Checked on 2026-08-27:

- Numi Lab: 0.4.0
- Runtime root: `/Users/home/Documents/emergentnumilife/MetalRobo`
- Runtime revision: `25ab4f9`
- Runtime branch: `coupled`
- Workspace: `/Users/home/numi-brain`
- Apple Silicon: available
- Metal tools: available
- MLX learner: available
- `numi doctor`: action required because the existing robot-catalog self-check was killed and reported incompatible

This is an external runtime readiness observation. The shared MetalRobo checkout was not modified while creating this repository.

## First implementation gate

The tissue slice is not Phase 1 completion. Phase 1 is complete only when a minimal brain state can advance, reject, restore, retry, and atomically commit with NumanX without hot-path CPU copies, while preserving counter-based random streams and byte-stable committed replay under physical substep rejection.
