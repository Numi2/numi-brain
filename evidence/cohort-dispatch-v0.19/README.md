# Routed cohort dispatch v0.19 evidence

This directory contains a bounded Apple M4 correctness artifact for routed,
transaction-owned cohort state at source revision
`e4881b53c46fc2fd2c1e947cfbd3e92c6cc1fd07`.

## Apple M4 control run

`apple-m4-16env.json` records one 20 ms root shadow across 16 independent
scheduler states:

- 1,335 source invocations and exact indirectly expanded work items;
- 90 canonical timestamp, clock-class, and module groups;
- an exact 1,335-record GPU-generated environment-major invocation stream;
- 10,752 recurrent token scalars, seven routed connections, and 24,576
  delayed-history scalars per environment;
- independent route rings, scores, normalized strengths, active selections,
  persistence counters, and timestamps for every environment;
- exact retry, discarded-shadow, canonical input order, materialization,
  invocation compaction, routing discrete state, ownership, and replay checks;
- CPU/Metal maximum absolute error of `1.7881393e-7` for recurrent tokens and
  `9.536743e-7` for route-history values, scores, and strengths;
- zero Metal status.

The recorded command-feedback interval is `0.03469612495973706` seconds. It
covers materialization and four indirect consumer dispatches on this bounded
control only. It excludes CPU plan construction, allocation, shader
compilation, upload, inspection readback, and verification. It is not a
throughput, profiler, GPU-counter, or production-cohort qualification.

SHA-256:

```text
d242175c4fccb83dbf6b15c217d56f9274b905bfcae782a2c18058cd87153fd7  apple-m4-16env.json
```

## Boundary

This artifact proves executable routed state ownership and CPU parity for the
eight-module runtime-foundation subset on an Apple M4. The CPU still constructs
the canonical cohort plan, and the GPU invocation compactor currently uses one
lane per environment rather than parallel prefix sums. The 96-module graph,
NumanX joint transaction, learned regional parameters, production throughput,
and M4 Pro qualification remain unimplemented or unqualified.
