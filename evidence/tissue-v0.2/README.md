# Tissue v0.2 development evidence

This folder records one exact-commit correctness and visual-inspection run of explicit conduction delays. It is not a biological calibration or a production GPU benchmark.

- Revision: `4e0f6aa073edb7b04a1299af7bf04752dcde21ae`
- Device: Apple M4
- OS: macOS 26.6 build 25G5028f
- Grid: 256×192 sites
- Accepted time: 100 ms at 1 ms per step
- Structure: synthetic layered profile with a circular zero-viability lesion
- Conduction: synthetic layered 1–4 ms outgoing delay classes
- Relay history: two private 32-slot FP32 planes, 12,582,912 bytes
- Three neural state generations: 2,359,296 bytes
- CPU/Metal maximum absolute error: `1.7881393e-07` at tolerance `3e-05`
- Replay and delayed-future rejected-retry/root-abort checks: passed
- Finite and normalized-bounded checks: passed
- State hash: `c8448e95c1c778ec`
- Structure hash: `b6e62daa60fd9c99`
- Conduction hash: `5143e3cd88b1312a`

Artifacts:

- [`apple-m4-delayed-layered-lesion-256x192.json`](apple-m4-delayed-layered-lesion-256x192.json) — machine-readable configuration, conduction, metrics, memory, and verification evidence.
- [`apple-m4-delayed-layered-lesion-256x192.png`](apple-m4-delayed-layered-lesion-256x192.png) — inspected activity heatmap. The driven population is blue, the silent lesion is black, and the background bands reflect synthetic structural strata.

The JSON includes wall and GPU time for auditability. This single small run is not a performance qualification.

SHA-256:

```text
30167679654f4363733a1a84194b3419b72a98299cfab979b8c409c00653f417  apple-m4-delayed-layered-lesion-256x192.json
4cf9645aec174e1e3b1c494126144f726efaa28ccca79e246b877c9300f6ebd9  apple-m4-delayed-layered-lesion-256x192.png
```

Reproduce from the repository root at the recorded revision:

```sh
NUMIBRAIN_REVISION=$(git rev-parse HEAD) \
  .build/release/numi-brain-tissue \
  --backend metal \
  --width 256 --height 192 \
  --duration-ms 100 --control-ms 20 \
  --structure layered --delays layered \
  --lesion-x 0.62 --lesion-y 0.5 \
  --lesion-radius 0.10 --lesion-viability 0 \
  --stimulus-x 0.45 --stimulus-y 0.5 \
  --stimulus-radius 0.08 --stimulus-drive 7 \
  --stimulus-start-ms 10 --stimulus-end-ms 70 \
  --verify-cpu --verify-replay \
  --snapshot evidence/tissue-v0.2/apple-m4-delayed-layered-lesion-256x192.png \
  --output evidence/tissue-v0.2/apple-m4-delayed-layered-lesion-256x192.json
```
