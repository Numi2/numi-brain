# Tissue v0.1 development evidence

This folder records one exact-commit correctness and visual-inspection run. It is not a biological calibration or a production GPU benchmark.

- Revision: `77adca9583bc9e50487a7d6e5bbe57c85c1d4cef`
- Device: Apple M4
- OS: macOS 26.6 build 25G5028f
- Grid: 256×192 sites
- Accepted time: 100 ms at 1 ms per step
- Structure: synthetic layered profile with a circular zero-viability lesion
- CPU/Metal maximum absolute error: `1.7881393e-07` at tolerance `3e-05`
- Replay, rejected-retry and root-abort checks: passed
- Finite and normalized-bounded checks: passed
- State hash: `bf5eecda30bfe9d0`
- Structure hash: `b6e62daa60fd9c99`

Artifacts:

- [`apple-m4-layered-lesion-256x192.json`](apple-m4-layered-lesion-256x192.json) — machine-readable configuration, metrics, memory and verification evidence.
- [`apple-m4-layered-lesion-256x192.png`](apple-m4-layered-lesion-256x192.png) — inspected activity heatmap. The driven population is blue, the silent lesion is black, and the background bands reflect synthetic structural strata.

SHA-256:

```text
67f542ea998d2414cb3b21e7e9f579007cde61b95fa58042ee61ceeeb700bd47  apple-m4-layered-lesion-256x192.json
aaacb9dc0f1b0b156407c928115beff055bfa5b5309d238205fbd3dae1f71201  apple-m4-layered-lesion-256x192.png
```

Reproduce from the repository root:

```sh
NUMIBRAIN_REVISION=$(git rev-parse HEAD) \
  .build/release/numi-brain-tissue \
  --backend metal \
  --width 256 --height 192 \
  --duration-ms 100 --control-ms 20 \
  --structure layered \
  --lesion-x 0.62 --lesion-y 0.5 \
  --lesion-radius 0.10 --lesion-viability 0 \
  --stimulus-x 0.45 --stimulus-y 0.5 \
  --stimulus-radius 0.08 --stimulus-drive 7 \
  --stimulus-start-ms 10 --stimulus-end-ms 70 \
  --verify-cpu --verify-replay \
  --snapshot evidence/tissue-v0.1/apple-m4-layered-lesion-256x192.png \
  --output evidence/tissue-v0.1/apple-m4-layered-lesion-256x192.json
```
