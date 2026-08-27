# Tissue v0.6 transactional Metal scheduler evidence

This directory captures the integrated tissue and scheduler path at commit `7a287c0bdbfb399ab70c2d9736836d423e5877d1` on an Apple M4 running macOS 26.6. It exercises the v0.6 bounded `schedule_due_modules` kernel after the accepted tissue candidate sequence on the same Metal 4 compute encoder, with private scheduler clocks and due invocations published transactionally with tissue state.

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
  --output evidence/tissue-v0.6/tissue-evidence.json \
  --snapshot evidence/tissue-v0.6/tissue-activity.png
```

Two matched controls used the same command and exact revision:

- `no-noise-control.json` changed only `--stimulus-noise 0`.
- `alternate-seed-control.json` changed only `--seed 0x4e554d4a`.

Recorded correctness facts:

- 49,152 tissue sites advanced through 70 accepted 1 ms substeps in four root transactions.
- Metal issued 70 receptor-event compaction dispatches and four scheduler dispatches. Each root used one reusable command buffer and encoder; scheduler selection followed the tissue sequence after a device barrier.
- The eight-module compiled schedule advanced to 70,000 microseconds at committed generation 4. Its final clock snapshot hash was `7f0410c814a02d9c`, exactly matching the CPU scheduler oracle.
- The last 10 ms root produced 37 private due invocations with device status zero. This artifact supplied no scheduler interrupt events; exact fractional-time interrupt delivery, periodic-boundary merging, retry, and abort behavior are covered by the Metal XCTest suite.
- The scheduler allocation records 256 descriptor bytes, two 128-byte clock generations, 1,536 shared input-event capacity bytes, 40 shared uniform bytes, 131,072 private invocation-capacity bytes, and a 16-byte private result.
- No scheduler result or invocation count was read back between roots. Evidence inspection staged clocks and due invocations only after the committed run completed.
- The main noisy tissue state hash remained `1d4534c321f98fe7`. Disabling noise produced `3db4f53ab3fd8e42`; changing only the seed produced `73d0eb346080c5de`.
- All three executions replayed exactly, preserved delayed retry and root abort, matched the CPU scheduler clock oracle, and reported `1.1920929e-07` maximum tissue CPU/Metal error against a `3e-05` tolerance.
- The runtime reported 17,448,960 residency-allocated bytes. The CSR graph retained 4,176 synthetic 12-step projections with hash `b2b475f34837ab8a`.
- Every final tissue state was finite and bounded.

The PNG was visually inspected. It retains the bright left event response, dark central partial-viability lesion, and spatially separated right response aligned with the synthetic mirrored projection band.

This is implementation and numerical-correctness evidence, not biological calibration or a production GPU benchmark. The scheduler kernel is a deterministic single-agent lane over an eight-module reference subset. The private due list does not yet dispatch regional neural operators; large-cohort prefix-sum compaction, indirect execution, dynamic NumanX GPU event queues, and the complete 96-module graph remain unimplemented.

SHA-256:

```text
39ba93bddb11bc8a10a4f9ee3099b8b22768685308057afec24c544556992542  alternate-seed-control.json
000c2689b7e34d7333f699728df798edb7c6903399833ded8cac7aba1e962cce  no-noise-control.json
4a99799413e6ecbf17f4dbf742c8cc2a37a12707a4ca7981ac8f05c4255e8063  tissue-evidence.json
7dbbe8c68a73c2ec509f502d7e6e4072aa8d6122ac9efd2db542e42c932711f5  tissue-activity.png
```
