# Implementation status

## Repository

- Canonical repository name: `numi-brain`
- Canonical architecture: NumiBrain v1.0
- Current state: specification and repository foundation only
- Implemented runtime code: none
- Build and test system: none
- Metal kernels: none
- NumanX interop: none
- Checkpoint or replay artifacts: none
- GPU performance or physical-behavior evidence: none

The architecture document is a design contract, not evidence that any subsystem is live.

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

Phase 1 is complete only when a minimal brain state can advance, reject, restore, retry, and atomically commit with NumanX without hot-path CPU copies, while preserving counter-based random streams and byte-stable committed replay under physical substep rejection.
