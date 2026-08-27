# Tissue v0.5 Apple M4 development evidence

This directory captures bounded GPU receptor-event compaction at commit `df63ce8f6e94813a65a8a88575150182908ea0ed` on an Apple M4 running macOS 26.6. It exercises the v0.5 compaction kernel and active-only tissue scan together with timestamped counter-random receptor input, layered local delays, sparse long-range projections, heterogeneous tissue, a partial-viability lesion, Metal 4 execution, CPU parity, exact replay, rejected-substep retry, and root abort.

The primary command was:

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
  --stimulus-noise 0.35 \
  --seed 0x4e554d49 \
  --environment-id 3 \
  --episode-id 27 \
  --lesion-x 0.5 \
  --lesion-y 0.5 \
  --lesion-radius 0.07 \
  --lesion-viability 0.15 \
  --verify-cpu \
  --verify-replay \
  --output evidence/tissue-v0.5/tissue-evidence.json \
  --snapshot evidence/tissue-v0.5/tissue-activity.png
```

Two matched controls used the same command and exact revision:

- `no-noise-control.json` changed only `--stimulus-noise 0`.
- `alternate-seed-control.json` changed only `--seed 0x4e554d4a`.

Recorded correctness facts:

- 49,152 sites advanced through 70 accepted 1 ms substeps in four root transactions.
- Metal issued 70 `compact_receptor_events` dispatches, exactly one per attempted substep, then crossed a device barrier before the tissue dispatch.
- The compactor wrote a private 260-byte allocation containing one active count and capacity for 64 canonical schedule indices. The recorded maximum simultaneous active count was one.
- Tissue sites scanned only compacted due indices. No active count or index was read back by the CPU during the control loop.
- The one 48-byte receptor event remained half-open and causal from 5 through 45 ms with bounded noise amplitude `0.35`.
- The main noisy state hash remained `1d4534c321f98fe7`, exactly matching v0.4. Disabling noise produced `3db4f53ab3fd8e42`; changing only the seed produced `73d0eb346080c5de`.
- All three executions replayed exactly, passed delayed retry and root-abort checks, and agreed with the CPU oracle at `1.1920929e-07` maximum absolute error against a `3e-05` tolerance.
- The CSR graph contains 4,176 12-step projections with hash `b2b475f34837ab8a`; the event schedule hash is `2e903e4c2c0f3def`.
- The runtime reported 17,317,888 residency-allocated bytes, including private event schedule and active-index buffers.
- Every final state was finite and bounded.

The PNG was visually inspected. It shows the bright left event response, dark central partial-viability lesion, and spatially separated right response aligned with the synthetic mirrored projection band.

This is a diagnostic numerical artifact, not tissue microscopy, measured receptor noise, or anatomical validation. Timing is a bounded local development probe, not a production benchmark. The compactor is a deterministic single-lane kernel for the 64-record v0 schedule; parallel prefix-sum cohort compaction, dynamic NumanX packet ingestion, and event-specific indirect dispatch remain unimplemented.

SHA-256:

```text
ca88cc8bd68548283ab834cb760cabfa5b862642e8ea250533b50369b98cb3f3  alternate-seed-control.json
abdb3025606c7eba07ec106bbc4eae57573aa54f8f3cf4c101b1f99956431cf9  no-noise-control.json
58c1b29c2a47cba3db6cfc6604a6902fef67fd23361a55bfb488bab99b5ee516  tissue-evidence.json
7dbbe8c68a73c2ec509f502d7e6e4072aa8d6122ac9efd2db542e42c932711f5  tissue-activity.png
```
