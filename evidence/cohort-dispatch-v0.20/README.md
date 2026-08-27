# Parallel cohort dispatch v0.20 evidence

This directory contains an exact-source Apple M4 Pro correctness artifact for
parallel GPU invocation compaction and routed, transaction-owned cohort state at
source revision `3d81a29e1a1412fa788f9484dccf663691905bda`.

## Apple M4 Pro run

`apple-m4-pro-256env.json` records one 20 ms root shadow across 256 independent
scheduler states:

- 21,255 source invocations in 90 canonical timestamp/module groups;
- exact indirectly expanded work items and an exact GPU-generated,
  environment-major invocation stream;
- 64-lane count, deterministic threadgroup prefix scan, and ordered scatter for
  each environment;
- 10,752 recurrent token scalars, seven routes, and 24,576 delayed-history
  scalars per environment;
- exact retry, discarded-shadow, input-order, materialization, invocation,
  ownership, discrete-routing, and replay checks;
- CPU/Metal maximum absolute error of `1.7881393e-7` for recurrent tokens and
  `9.536743e-7` for route history, scores, and strengths;
- zero Metal status.

The full 58-test suite passed on the same checkout immediately before the run.
The recorded command-feedback interval is `0.034844750072807074` seconds. It
covers materialization and the four indirect consumer dispatches only. It
excludes CPU plan construction, allocation, shader compilation, upload,
inspection readback, and verification, so it is not an end-to-end throughput,
profiler-counter, or production-cohort claim.

SHA-256:

```text
c8f50bdf2c1bb28564f72cbf927901eb82586dad9f702c41865449144236b589  apple-m4-pro-256env.json
```

## Boundary

This artifact qualifies the v0.20 bounded correctness path on an Apple M4 Pro.
The CPU still constructs the canonical cohort plan. The complete 96-module
graph, NumanX joint transaction, learned production parameters, and production
throughput remain unimplemented or unqualified.
