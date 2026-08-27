# Tissue v0.12 immutable-parameter evidence

This directory captures the first bounded Apple M4 correctness probe of the immutable shared-parameter generation implemented at source commit `8808f8b28c0aa69fa48b1e5aa03c9accdc89163a`. It extends the v0.11 receptor-interrupt, scheduler, recurrent regional-token, delayed-route, and dynamic-routing path with a compiled parameter manifest, synchronization-boundary publication rules, CPU checkpoint/cohort version identity, and private Metal version validation.

The release runtime was built from committed source after all 48 tests passed locally. The exact command was:

```sh
NUMIBRAIN_REVISION=8808f8b28c0aa69fa48b1e5aa03c9accdc89163a \
  .build/release/numi-brain-tissue \
  --backend metal \
  --width 64 \
  --height 48 \
  --duration-ms 60 \
  --control-ms 20 \
  --structure layered \
  --delays layered \
  --connectome bilateral \
  --stimulus-start-ms 10 \
  --stimulus-end-ms 30 \
  --stimulus-noise 0.35 \
  --receptor-interrupt pain \
  --receptor-latency-us 500 \
  --seed 0x4e554d49 \
  --verify-cpu \
  --verify-replay \
  --snapshot evidence/tissue-v0.12/activity.png \
  --output evidence/tissue-v0.12/run.json
```

## Recorded correctness facts

- Schema `numibrain.tissue-simulation-evidence.v12` reports manifest version 1, root sequence 0, parameter fingerprint `f5e9c9c4aa094246`, zero parent fingerprint, two canonical components, and 344,300 total parameter bytes.
- The scheduler and regional kernels consumed one private 64-byte `NBParameterVersionBinding`. Scheduler uniforms grew to 56 bytes so each root independently supplied the version and schedule fingerprints. Both typed kernel statuses were zero.
- The regional structural fingerprint is `97cc4e9a47c2baa8`; the exact regional content fingerprint is `704931c121ffb989`. Tests independently change learned-form FP32 values and require the content identity to change while structural identity remains stable.
- The scheduler committed at 60,000 microseconds, generation 3, with parameter-bound snapshot hash `79eb6335afc2f14b` and exact CPU snapshot/version parity.
- One 10 ms pain onset plus 500 microseconds of conduction latency entered the receptor path exactly once. Three interrupt deliveries reached the configured pain modules, and the final root did not repeat the event.
- The recurrent regional path retained six active routes, including both emergency routes. CPU-to-Metal diagnostic, token, route-history, and routing-state comparisons all passed their declared FP32 tolerances.
- Tissue CPU/Metal maximum absolute error was `5.9604645e-08` against a `3e-05` tolerance. Replay, rejected retry, and full root abort were exact.
- `activity.png` was visually inspected as the final synthetic activity heatmap. It is implementation-inspection output, not a biological image.

The Apple M4 run reported `0.0381196` GPU seconds for 60 accepted 1 ms steps over 3,072 sites. This is retained only as bounded run telemetry. It was not captured with a profiler or GPU counters and is not a comparative or production performance result.

Mac mini M4 Pro qualification is deliberately deferred while an unrelated 2,048-environment crow training/selection workload owns that GPU. The source commit is already synchronized to its clean `/Users/n/numi-brain` checkout; no NumiBrain build or run will contend with the active workload.

SHA-256:

```text
6c1efa83c15c40c0cd43c4fa24970b45292410d819335288d90801184835cafa  run.json
a5a4425bff453dc11d118241f6a7625734e4bfc929c5284a540de50787669d46  activity.png
```

This establishes immutable version identity for the current bounded one-agent runtime. It does not establish a learner, multi-runtime parameter-buffer activation, persistent checkpoints, large-cohort publication, mid-NumanX-substep interruption, biological calibration, or production GPU performance.
