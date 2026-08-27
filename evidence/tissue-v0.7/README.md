# Tissue v0.7 live regional execution evidence

This directory captures the integrated tissue, scheduler, and compact regional-state path at commit `e73bca33a9d171e30161c3689c2b4ce3d2cbcb1e` on an Apple M4 running macOS 26.6. It exercises `schedule_due_modules` and `advance_due_module_states` after the accepted tissue candidate sequence on the same Metal 4 compute encoder. Scheduler clocks and regional population traces remain private and publish transactionally with tissue state.

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
  --output evidence/tissue-v0.7/tissue-evidence.json \
  --snapshot evidence/tissue-v0.7/tissue-activity.png
```

Two matched controls used the same command and exact revision:

- `no-noise-control.json` changed only `--stimulus-noise 0`.
- `alternate-seed-control.json` changed only `--seed 0x4e554d4a`.

Recorded correctness facts:

- 49,152 tissue sites advanced through 70 accepted 1 ms substeps in four root transactions.
- Metal issued 70 receptor-event compaction dispatches, four scheduler dispatches, and four regional-state dispatches on the integrated command path.
- The eight-module compiled schedule advanced to 70,000 microseconds at committed generation 4. Its final clock snapshot hash was `7f0410c814a02d9c`, exactly matching the CPU scheduler oracle.
- `advance_due_module_states` consumed the private due list without a host count readback. Across the four roots, it executed 271 module updates and produced regional snapshot hash `d78c1c595e2fe734`.
- The regional state uses two private 256-byte generations. Each 32-byte module record contains activation, integrated activation, interrupt salience, phase, update counters, and last-update physical time.
- Regional counters and timestamps matched the CPU oracle exactly. Floating state differed by at most `1.4901161e-08` against a `2e-06` tolerance.
- This artifact supplied no scheduler interrupt events, so its regional interrupt count is zero. Exact fractional-time interrupt delivery, periodic-boundary merging, regional interrupt response, retry, abort, and chunking behavior are covered by the 32-test XCTest suite.
- No scheduler or regional result was read back between roots. Evidence inspection staged private state only after the committed run completed.
- The main noisy tissue state hash remained `1d4534c321f98fe7`. Disabling noise produced `3db4f53ab3fd8e42`; changing only the seed produced `73d0eb346080c5de`.
- All three executions replayed exactly, preserved delayed retry and root abort, matched both CPU oracles, and reported `1.1920929e-07` maximum tissue CPU/Metal error against a `3e-05` tolerance.
- The runtime reported 17,448,960 residency-allocated bytes. The CSR graph retained 4,176 synthetic 12-step projections with hash `b2b475f34837ab8a`.
- Every final tissue state was finite and bounded.

The PNG was visually inspected and is byte-identical to v0.6. It retains the bright left event response, dark central partial-viability lesion, and spatially separated right response aligned with the synthetic mirrored projection band.

This is implementation and numerical-correctness evidence, not biological calibration or a production GPU benchmark. The regional operator is a deterministic compact population trace over an eight-module reference subset. It is not the final trainable recurrent token state, role-specific neural operator, sparse routed graph, or large-cohort indirect dispatch.

SHA-256:

```text
6510a3d19a357b39bf60e35bf1766b4d6d19eb94d330162ac3c92c1d6a96d58c  alternate-seed-control.json
aeff44ef5f5fb579d951e99eec56acd57fde7d1febe4752abd89c9196a15db0d  no-noise-control.json
bd5a4194182b058670b82e79e3f496749ef9613cb32351e7b33cffaf1ea842ea  tissue-evidence.json
7dbbe8c68a73c2ec509f502d7e6e4072aa8d6122ac9efd2db542e42c932711f5  tissue-activity.png
```
