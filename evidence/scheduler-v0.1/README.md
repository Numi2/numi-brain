# Scheduler v0.1 deterministic oracle evidence

This directory captures the compiled module ABI and deterministic multi-rate scheduler oracle at commit `579afea9ab55d4c989ff07abdadeaf2abcd952b7` on macOS 26.6.

The command was:

```sh
NUMIBRAIN_REVISION=$(git rev-parse HEAD) .build/release/numi-brain-scheduler \
  --duration-ms 200 \
  --control-ms 20 \
  --environments 4 \
  --output evidence/scheduler-v0.1/scheduler-evidence.json
```

Recorded correctness facts:

- C++ compiled and validated ABI version 1 with 32-byte module descriptors, 16-byte module clock states, 24-byte interrupt events, and 32-byte due invocations.
- The eight-module reference subset has descriptor fingerprint `c0162952817e2b01` and explicit periods from 1–100 ms.
- Four independent scheduler states advanced for 200 ms of physical time through ten 20 ms root transactions.
- The oracle emitted 3,064 module invocations: 3,056 periodic invocations and eight event-interrupted module invocations.
- Cohort compaction produced 772 deterministic timestamp/module groups with at most four environment entries per group.
- Three source events at 7,500, 63,750, and 120,125 microseconds reached matching modules at exactly those timestamps.
- Replay, rejected retry, root abort, independent-state, and canonical-cohort-order checks all passed.
- All four final scheduler snapshots had hash `6a376bec76ac5326`. Identical hashes reflect identical final clocks, while the independent-state check separately verifies that advancing one mind does not mutate another.

The recorded wall time covers two complete oracle executions plus the independence probe. It is a bounded correctness observation, not a scheduler throughput benchmark.

This evidence does not establish a GPU-resident scheduler, neural module execution, the complete 96-module graph, adaptive biological rates, delay-line message delivery, or NumanX coupling. The CPU oracle defines deterministic semantics for the future Metal scheduler and indirect dispatch path.

SHA-256:

```text
dcee87ea485be87b06e7e4a6cbbcae24f161d4afd0031388312f2c4ea5a0a7b5  scheduler-evidence.json
```
