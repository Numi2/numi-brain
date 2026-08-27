# Implementation status

## Repository

- Canonical repository name: `numi-brain`
- Canonical architecture: NumiBrain v1.0
- Current state: specification plus sparse-projection delayed heterogeneous mesoscale tissue vertical slice v0.3
- Implemented runtime code: deterministic CPU oracle and Metal 4 structured delayed-sheet runtime with a destination-major CSR graph
- Build and test system: Swift Package Manager and XCTest
- Metal kernels: one FP32 Wilson-Cowan-family tissue step with relay, structure, local delay field, sparse delayed projections, and transactional history ring
- NumanX interop: none
- Checkpoint or replay artifacts: none
- GPU performance evidence: bounded local probe only; remote production-size qualification pending

The architecture document remains a design contract. Only the tissue behavior owned by the source and tests in this repository is currently live.

## Implemented tissue evidence

The v0.3 slice currently proves:

- finite, bounded resting-state integration;
- transient activation from a physically timed localized input;
- short-range recruitment outside the direct input footprint;
- a finite-time axonal relay that lags local population recruitment;
- explicit per-site outgoing delay classes sampled from a 32-step FP32 relay-history ring;
- delayed lateral recruitment relative to an instantaneous-conduction control;
- delayed long-range recruitment at a target outside the source's local stencil;
- deterministic canonicalization and hashing of the destination-major sparse projection graph;
- deterministic synthetic tissue strata with per-site excitatory, inhibitory, coupling, and viability coefficients;
- exact silence and blocked outgoing transmission for zero-viability lesion sites;
- inhibitory/adaptation-driven recovery;
- bit-exact CPU replay for a fixed acceptance/rejection schedule;
- bit-exact root abort and rejected-substep retry;
- identical delayed local and long-range future state after root abort or rejected-substep retry;
- Metal 4 execution through `MTL4CommandQueue`, a reusable `MTL4CommandBuffer`, `MTL4ComputeCommandEncoder`, and `MTL4ArgumentTable`;
- CPU/Metal agreement within an FP32 tolerance.

The current XCTest suite contains 18 passing tests: eleven CPU oracle tests and seven Metal 4 tests. Dedicated tests require distant target recruitment through an edge-specific delay and CPU/Metal agreement for that sparse path. The layered-lesion parity test still requires exact zero state at every nonviable site. Transaction tests include the sparse graph and advance beyond its configured delay after abort or retry, so corrupted hidden history cannot pass through an unchanged immediate grid.

The Metal history ring uses two private 32-slot FP32 relay planes plus one rejected-candidate scratch plane. It costs 256 history bytes per site, excluding state, structure, delay, sparse graph, scratch, uniforms, and inspection staging. The graph adds four bytes per destination offset and 16 bytes per packed edge. A Metal root transaction may accept at most 32 substeps so the abort-authoritative plane cannot be overwritten; the canonical 20 ms control interval is within that boundary.

The latest checked Apple M4 development probe on 2026-08-27 used commit `4e0f6aa`, a 256×192 delayed layered sheet, a circular zero-viability lesion, and 100 accepted 1 ms substeps. It reported `1.7881393e-07` maximum CPU/Metal error, exact replay, delayed-future retry and root abort, finite bounded output, state hash `c8448e95c1c778ec`, structure hash `b6e62daa60fd9c99`, and conduction hash `5143e3cd88b1312a`. The JSON and inspected PNG are in [`evidence/tissue-v0.2`](evidence/tissue-v0.2/README.md). This is implementation evidence, not a calibrated brain-tissue result or production GPU benchmark.

An M4 Pro v0 throughput run was not promoted because a new external Metal training workload began between the idle check and dispatch. The current source is synchronized to `/Users/n/numi-brain` on `macmini` after each committed development slice, but uncontended production-size v0.2 qualification remains pending.

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
