# Tissue v0.4 Apple M4 development evidence

This directory captures the noisy receptor-event path at commit `57ee1ee4a5b4cfaa910bb5f7669581067c6f14b9` on an Apple M4 running macOS 26.6. It exercises the v0.4 timestamped event ABI and counter-random generator together with layered local delays, sparse long-range projections, heterogeneous tissue, a partial-viability lesion, Metal 4 execution, CPU parity, exact replay, rejected-substep retry, and root abort.

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
  --output evidence/tissue-v0.4/tissue-evidence.json \
  --snapshot evidence/tissue-v0.4/tissue-activity.png
```

Two matched controls used the same command and exact revision:

- `no-noise-control.json` changed only `--stimulus-noise 0`.
- `alternate-seed-control.json` changed only `--seed 0x4e554d4a`.

Recorded correctness facts:

- 49,152 sites advanced through 70 accepted 1 ms substeps in four root transactions.
- One 48-byte receptor event is timestamp-gated from 5 through 45 ms and uses bounded noise amplitude `0.35`.
- The main counter identity is seed `1314213193`, environment `3`, episode `27`, and tissue module `12`; it owns zero mutable generator bytes.
- The main noisy state hash is `1d4534c321f98fe7`. Disabling noise changes it to `3db4f53ab3fd8e42`; changing only the seed changes it to `73d0eb346080c5de`.
- All three executions replay exactly, pass delayed retry and root-abort checks, and agree with the CPU oracle at `1.1920929e-07` maximum absolute error against a `3e-05` tolerance.
- The CSR graph still contains 4,176 12-step projections with hash `b2b475f34837ab8a`.
- The main event schedule hash is `2e903e4c2c0f3def`, and the final state is finite and bounded.
- The runtime reports 17,317,888 residency-allocated bytes, including the private event, connectome, state, and relay-history allocations.

The PNG was visually inspected. It shows the bright left event response, dark central partial-viability lesion, and spatially separated right response aligned with the synthetic mirrored projection band. The bounded noise perturbs site trajectories but is intentionally subtle at whole-sheet heatmap scale.

This is a diagnostic numerical artifact, not tissue microscopy, measured receptor noise, or anatomical validation. The timing fields are a bounded development probe, not a production benchmark. The first event implementation performs a bounded canonical scan per tissue site; dynamic GPU queue compaction and event-specific indirect dispatch remain unimplemented.

SHA-256:

```text
808b14cfa3780c1c4b0b58314f701e6370c45e88dce101c567ff3184a0c903ae  alternate-seed-control.json
5a6046a712ff711c47793ed81497bc0858d136a58705157d34cdea6c34d69f38  no-noise-control.json
cce9d03b11656e1f2d07cb4c88c765fbee06aeb9dde576842bea578c8fcc2ec2  tissue-evidence.json
7dbbe8c68a73c2ec509f502d7e6e4072aa8d6122ac9efd2db542e42c932711f5  tissue-activity.png
```
