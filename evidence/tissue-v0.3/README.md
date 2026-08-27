# Tissue v0.3 Apple M4 development evidence

This directory captures one reproducible execution of commit `68e2d9d17bb790b57569f5631eefbdb7edf1b6fc` on an Apple M4 running macOS 26.6. It exercises the v0.3 destination-major sparse projection graph together with layered local delays, heterogeneous tissue, a partial-viability lesion, Metal 4 execution, CPU parity, exact replay, rejected-substep retry, and root abort.

The command was:

```sh
NUMIBRAIN_REVISION=$(git rev-parse HEAD) .build/release/numi-brain-tissue \
  --backend metal \
  --width 256 \
  --height 192 \
  --duration-ms 70 \
  --control-ms 20 \
  --connectome bilateral \
  --structure layered \
  --delays layered \
  --stimulus-x 0.25 \
  --stimulus-y 0.5 \
  --stimulus-radius 0.055 \
  --stimulus-drive 7 \
  --stimulus-start-ms 5 \
  --stimulus-end-ms 45 \
  --lesion-x 0.5 \
  --lesion-y 0.5 \
  --lesion-radius 0.07 \
  --lesion-viability 0.15 \
  --verify-cpu \
  --verify-replay \
  --output evidence/tissue-v0.3/tissue-evidence.json \
  --snapshot evidence/tissue-v0.3/tissue-activity.png
```

Recorded correctness facts:

- 49,152 sites advanced through 70 accepted 1 ms substeps in four root transactions.
- The CSR graph contains 4,176 edge-specific 12-step projections and has hash `b2b475f34837ab8a`.
- The final state hash is `3db4f53ab3fd8e42`; structure and local-delay hashes are `11bee73e55739745` and `5143e3cd88b1312a`.
- The maximum CPU/Metal absolute error is `1.1920929e-07`, below the declared `3e-05` tolerance.
- Replay is exact, rejected retry is exact after the projection delay, and root abort is exact after the projection delay.
- All output is finite and bounded.
- The runtime reports 17,186,816 residency-allocated bytes, including 196,612 CSR-offset bytes and 66,816 packed-edge bytes.

The PNG was visually inspected. It shows a bright left stimulus response, a dark central partial-viability lesion, and a spatially separated right response aligned with the synthetic mirrored projection band. It is a diagnostic heatmap, not tissue microscopy or validation of an anatomical pathway.

The timing fields are a bounded development probe, not a production benchmark: CPU verification, replay, inspection readback, process overhead, and the small run shape are not a same-workload throughput qualification. The graph, delays, strata, lesion, and normalized spatial scale are synthetic and uncalibrated.

SHA-256:

```text
89adb10a6a1340210ab48d0bfe520c6cb2076228fa07d1b82c140389b61b0f51  tissue-evidence.json
d02bc860a8e4bc92628aca3a78cbcdfe12349d4b1287c2df76f1b42bb699bde2  tissue-activity.png
```
