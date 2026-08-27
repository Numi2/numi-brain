# Tissue v0.12 immutable-parameter evidence

This directory captures bounded Apple M4 Pro and Apple M4 correctness probes of the immutable shared-parameter generation implemented at source commit `8808f8b28c0aa69fa48b1e5aa03c9accdc89163a`. It extends the v0.11 receptor-interrupt, scheduler, recurrent regional-token, delayed-route, and dynamic-routing path with a compiled parameter manifest, synchronization-boundary publication rules, CPU checkpoint/cohort version identity, and private Metal version validation.

The release runtime was built from committed source after all 48 tests passed on both machines. The local Apple M4 command was:

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

The corresponding heavy command ran through `ssh macmini` from `/Users/n/numi-brain` only after the unrelated crow workload ended. It used `--width 256 --height 192`; every other behavioral flag and the recorded source revision were identical. Its original `/tmp/numibrain-v012-mini-*` outputs are checked in here as `mini-m4-pro.json` and `mini-m4-pro.png` without rewriting the runtime JSON.

## Recorded correctness facts

- Schema `numibrain.tissue-simulation-evidence.v12` reports manifest version 1, root sequence 0, parameter fingerprint `f5e9c9c4aa094246`, zero parent fingerprint, two canonical components, and 344,300 total parameter bytes.
- The scheduler and regional kernels consumed one private 64-byte `NBParameterVersionBinding`. Scheduler uniforms grew to 56 bytes so each root independently supplied the version and schedule fingerprints. Both typed kernel statuses were zero.
- The regional structural fingerprint is `97cc4e9a47c2baa8`; the exact regional content fingerprint is `704931c121ffb989`. Tests independently change learned-form FP32 values and require the content identity to change while structural identity remains stable.
- Both schedulers committed at 60,000 microseconds, generation 3, with parameter-bound snapshot hash `79eb6335afc2f14b` and exact CPU snapshot/version parity.
- One 10 ms pain onset plus 500 microseconds of conduction latency entered the receptor path exactly once. Three interrupt deliveries reached the configured pain modules, and the final root did not repeat the event.
- The recurrent regional path retained six active routes, including both emergency routes. CPU-to-Metal diagnostic, token, route-history, and routing-state comparisons all passed their declared FP32 tolerances.
- Tissue CPU/Metal maximum absolute error was `1.1920929e-07` on the M4 Pro and `5.9604645e-08` on the M4 against a `3e-05` tolerance. Replay, rejected retry, and full root abort were exact on both machines.
- `activity.png` and `mini-m4-pro.png` were visually inspected as final synthetic activity heatmaps. They are implementation-inspection output, not biological images.

The Apple M4 Pro run reported `0.0194467` GPU seconds for 60 accepted 1 ms steps over 49,152 sites; the Apple M4 control reported `0.0381196` seconds over 3,072 sites. These values and derived rates are retained only as bounded run telemetry. Neither run used a profiler or GPU counters, so they are not a comparative or production performance result.

SHA-256:

```text
6c1efa83c15c40c0cd43c4fa24970b45292410d819335288d90801184835cafa  run.json
a5a4425bff453dc11d118241f6a7625734e4bfc929c5284a540de50787669d46  activity.png
6fd0ca94d244478b262c346194c85fca55dbd647a8f670a3da7b7a1ef4d8e557  mini-m4-pro.json
6f39ed81139b9e56668ed1e0ea6391b05a66435dee2ca00de30455522934fbfb  mini-m4-pro.png
```

This establishes immutable version identity for the current bounded one-agent runtime. It does not establish a learner, multi-runtime parameter-buffer activation, persistent checkpoints, large-cohort publication, mid-NumanX-substep interruption, biological calibration, or production GPU performance.
