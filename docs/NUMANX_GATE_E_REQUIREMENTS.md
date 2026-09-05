# Gate E — scale and performance

Status: measurement/evidence implementation present; qualification open until measured on matched Apple workloads.

Gate E measures the exact qualified runtime. It does not infer performance from architecture or kernel counts. Every result binds source revision, executable and metallib SHA-256, complete hardware/OS identity, logical workload dimensions, horizon, timestep, deterministic/fast-math mode, and at least 100 measured root latencies after explicit warmup.

The `NumiBrainQualification` module provides canonical workload/run artifacts, p50/p95/p99 distributions, resident-memory and throughput fields, optional power/energy fields, GPU/caching/bandwidth counters, and hot-path CPU wait/queue/readback counters. `PerformanceSweepVerifier` rejects missing cells, duplicates, mixed source revisions, mixed binaries, mixed metallibs, or mixed hardware. This prevents combining convenient results from incomparable configurations.

`numi-brain-gate-e summarize` computes latency distributions from retained samples. `numi-brain-gate-e verify` evaluates an explicit predeclared protocol. Thresholds are not hard-coded by the implementation; define them before running the campaign. Report deterministic and fast-math modes separately.

Required campaign dimensions remain: environment count, logical DoF, attachments, FEM elements, sensor scalars, model parameter count, horizon and timestep. Report simulated seconds/wall second, environment steps/second, p50/p95/p99/max root latency, peak/steady bytes and bytes/environment, command buffers, waits, queue creation, host payload readback, GPU activity/bandwidth/cache counters when available, and same-device power/energy when available.

A Gate E result is not comparable to Newton, Isaac Lab or MuJoCo Warp unless the model, contacts, sensors, precision, hardware, timestep and acceptance criteria are matched. No comparative SOTA claim is authorized without such a matched study.
