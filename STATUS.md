# Implementation status

## Repository

- Canonical repository name: `numi-brain`
- Canonical architecture: NumiBrain v1.0
- Current state: specification plus mesoscale tissue vertical slice v0
- Implemented runtime code: deterministic CPU oracle and Metal 4 cortical-sheet runtime
- Build and test system: Swift Package Manager and XCTest
- Metal kernels: one FP32 Wilson-Cowan-family tissue step
- NumanX interop: none
- Checkpoint or replay artifacts: none
- GPU performance evidence: bounded local probe only; remote production-size qualification pending

The architecture document remains a design contract. Only the tissue behavior owned by the source and tests in this repository is currently live.

## Implemented tissue evidence

The v0 slice currently proves:

- finite, bounded resting-state integration;
- transient activation from a physically timed localized input;
- short-range recruitment outside the direct input footprint;
- inhibitory/adaptation-driven recovery;
- bit-exact CPU replay for a fixed acceptance/rejection schedule;
- bit-exact root abort and rejected-substep retry;
- Metal 4 execution through `MTL4CommandQueue`, a reusable `MTL4CommandBuffer`, `MTL4ComputeCommandEncoder`, and `MTL4ArgumentTable`;
- CPU/Metal agreement within an FP32 tolerance.

A lightweight Apple M4 development probe on 2026-08-27 used a 48×48 grid for 40 accepted 1 ms substeps. It reported `5.9604645e-08` maximum CPU/Metal error, exact replay and rollback, and finite bounded output. This is implementation evidence, not a calibrated brain-tissue result or production GPU benchmark.

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
