# Implementation status

## Repository

- Canonical repository name: `numi-brain`
- Canonical architecture: NumiBrain v1.0
- Current state: specification plus delayed heterogeneous mesoscale tissue vertical slice v0.2
- Implemented runtime code: deterministic CPU oracle and Metal 4 structured delayed-sheet runtime
- Build and test system: Swift Package Manager and XCTest
- Metal kernels: one FP32 Wilson-Cowan-family tissue step with relay, structure, delay field, and transactional history ring
- NumanX interop: none
- Checkpoint or replay artifacts: none
- GPU performance evidence: bounded local probe only; remote production-size qualification pending

The architecture document remains a design contract. Only the tissue behavior owned by the source and tests in this repository is currently live.

## Implemented tissue evidence

The v0.2 slice currently proves:

- finite, bounded resting-state integration;
- transient activation from a physically timed localized input;
- short-range recruitment outside the direct input footprint;
- a finite-time axonal relay that lags local population recruitment;
- explicit per-site outgoing delay classes sampled from a 32-step FP32 relay-history ring;
- delayed lateral recruitment relative to an instantaneous-conduction control;
- deterministic synthetic tissue strata with per-site excitatory, inhibitory, coupling, and viability coefficients;
- exact silence and blocked outgoing transmission for zero-viability lesion sites;
- inhibitory/adaptation-driven recovery;
- bit-exact CPU replay for a fixed acceptance/rejection schedule;
- bit-exact root abort and rejected-substep retry;
- identical delayed future state after root abort or rejected-substep retry;
- Metal 4 execution through `MTL4CommandQueue`, a reusable `MTL4CommandBuffer`, `MTL4ComputeCommandEncoder`, and `MTL4ArgumentTable`;
- CPU/Metal agreement within an FP32 tolerance.

The current XCTest suite contains 16 passing tests: ten CPU oracle tests and six Metal 4 tests. The strongest parity test advances a delayed, layered, circularly lesioned sheet on both implementations and requires both FP32 agreement and exact zero state at every nonviable site. Transaction tests advance beyond the configured delay after abort or retry so corrupted hidden history cannot pass through an unchanged immediate grid.

The Metal history ring uses two private 32-slot FP32 relay planes plus one rejected-candidate scratch plane. It costs 256 history bytes per site, excluding state, structure, delay, scratch, uniforms, and inspection staging. A Metal root transaction may accept at most 32 substeps so the abort-authoritative plane cannot be overwritten; the canonical 20 ms control interval is within that boundary.

The checked Apple M4 development probe on 2026-08-27 used commit `77adca9`, a 256×192 layered sheet, a circular zero-viability lesion, and 100 accepted 1 ms substeps. It reported `1.7881393e-07` maximum CPU/Metal error, exact replay, retry and root abort, finite bounded output, state hash `bf5eecda30bfe9d0`, and structure hash `b6e62daa60fd9c99`. The JSON and inspected PNG are in [`evidence/tissue-v0.1`](evidence/tissue-v0.1/README.md). This is implementation evidence, not a calibrated brain-tissue result or production GPU benchmark.

An M4 Pro v0 throughput run was not promoted because a new external Metal training workload began between the idle check and dispatch. The current v0.1 revision is synchronized to `/Users/n/numi-brain` on `macmini`, but uncontended production-size qualification remains pending.

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
