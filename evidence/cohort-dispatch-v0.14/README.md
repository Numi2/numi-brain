# Cohort indirect dispatch v0.14 evidence

This directory contains a bounded Apple M4 correctness artifact for the versioned cohort materializer and GPU-generated indirect consumer at source revision `487c2483e20a1929b113726a1833d59bf30fdccf`.

## Apple M4 development-profile run

`apple-m4.json` records one 20 ms source transaction across 8,192 independent scheduler states:

- 679,943 source invocations, flattened dispatch entries, and indirectly consumed work items;
- 90 canonical timestamp, clock-class, and module groups;
- a maximum of 8,192 active environments in one group;
- 11 interrupt deliveries isolated to the configured source environments;
- shared schedule fingerprint `c0162952817e2b01`;
- immutable parameter fingerprint `f5e9c9c4aa094246`;
- source-cohort fingerprint `dda9ac241e3ce636`;
- complete dispatch-plan fingerprint `51a78f0bcdbe4665`;
- expanded work fingerprint `1e3c0e0c326b212e`;
- 10,625 GPU-generated threadgroups of 64 lanes covering the flattened stream;
- 10,881,360 private input bytes, 32,639,472 private output bytes, and 21,758,176 private work-item bytes;
- zero Metal status;
- exact retry, discarded-shadow, canonical-input-order, CPU-plan/Metal-output, indirect-consumption, Metal replay, and stale-version rejection checks.

The recorded Metal command-feedback interval is 0.001240041572600603 seconds. It covers the materialization kernel, device barrier, and indirectly launched consumer only. It excludes CPU plan construction, allocation, shader compilation, upload, inspection readback, and verification, and is not a production throughput, profiler, or GPU-counter qualification.

SHA-256:

```text
28e25b9286704f8cfb9cc1e6c6015f2af67ab76c08305ac85b8ea6b78245ca1d  apple-m4.json
```

## Boundary

This artifact proves deterministic compiled plan identity, exact private Metal materialization, and a no-count-readback GPU handoff into indirect work consumption for the eight-module runtime-foundation subset. The CPU still constructs the compact plan. The consumer emits canonical work items but does not update recurrent regional state. GPU prefix-sum construction, cohort neural-state execution, the complete 96-module graph, NumanX coupling, and production cohort performance remain unimplemented or unqualified.
