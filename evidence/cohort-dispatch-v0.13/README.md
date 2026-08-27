# Cohort dispatch v0.13 evidence

This directory contains a bounded Apple M4 correctness artifact for the versioned cohort-dispatch compiler and Metal 4 materializer introduced at source revision `dce5d5df1b6b204921c9ff3ec330e04da9f446ce`.

## Apple M4 development-profile run

`apple-m4.json` records one 20 ms source transaction across 8,192 independent scheduler states:

- 679,943 source invocations and flattened dispatch entries;
- 90 canonical timestamp, clock-class, and module groups;
- a maximum of 8,192 active environments in one group;
- 11 interrupt deliveries isolated to the configured source environments;
- shared schedule fingerprint `c0162952817e2b01`;
- immutable parameter fingerprint `f5e9c9c4aa094246`;
- source-cohort fingerprint `dda9ac241e3ce636`;
- complete dispatch-plan fingerprint `51a78f0bcdbe4665`;
- 10,881,360 private input bytes and 10,881,280 private output bytes;
- zero Metal status;
- exact retry, discarded-shadow, canonical-input-order, CPU-plan/Metal-output, Metal replay, and stale-version rejection checks.

The recorded Metal command-feedback interval is 0.000539249973371625 seconds. It covers the materialization dispatch only. It excludes CPU plan construction, allocation, shader compilation, upload, inspection readback, and verification, and is not a production throughput, profiler, or GPU-counter qualification.

SHA-256:

```text
a95370d258d10ff375672f2b30b837015f2e1845ec9411b4573ce7a2dd004acb  apple-m4.json
```

## Boundary

This artifact proves deterministic compiled plan identity and exact private Metal materialization for the eight-module runtime-foundation subset. The CPU still constructs the compact plan. GPU prefix-sum construction, indirect regional execution, per-agent recurrent-state gathering, the complete 96-module graph, NumanX coupling, and production cohort performance remain unimplemented or unqualified.
