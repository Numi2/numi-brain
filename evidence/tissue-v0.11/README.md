# Tissue v0.11 receptor-interrupt local evidence

This directory captures a bounded local correctness probe of the integrated tissue, receptor-interrupt, scheduler, recurrent regional-token, delayed-route, and dynamic-routing path at source commit `45f53e405fc332e2397f37f060f6cf762b99452b` on an Apple M4 running macOS 26.6 build 25G5028f. It is not a Mac mini run, an uncontended performance measurement, a large-cohort qualification, a mid-NumanX-substep interrupt qualification, or biological validation.

The release runtime was built from committed source after the full 42-test suite passed. The evidence command was:

```sh
NUMIBRAIN_REVISION=45f53e405fc332e2397f37f060f6cf762b99452b \
  swift run -c release numi-brain-tissue \
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
  --snapshot evidence/tissue-v0.11/activity.png \
  --output evidence/tissue-v0.11/run.json
```

## Recorded correctness facts

- Schema `numibrain.tissue-simulation-evidence.v11` records one compiled 64-byte receptor event with hash `52f0ffca9a184452`, pain mask `1`, and 500 microseconds of conduction latency. The configured 10 ms onset therefore has an effective interrupt timestamp of 10.5 ms.
- Three root transactions issued three `transduce_receptor_interrupts` dispatches. Exactly one receptor onset entered the private 1,536-byte merged interrupt queue; the final root correctly contained zero repeated events.
- The private transduction result reported status zero. The scheduler committed at 60,000 microseconds, generation 3, with snapshot hash `1e425263c7384285` and exact CPU scheduler parity.
- Regional diagnostics recorded three interrupt deliveries, corresponding to the pain-enabled reference modules. The dedicated Metal test pins their timestamp and module identities and also covers rejected retry, root abort, and adjacent-boundary deduplication.
- The 10,752-scalar regional path retained six active routes, including both emergency routes. CPU-to-Metal maximum errors were `1.4901161e-08` for diagnostics, `1.7881393e-07` for tokens and route history, and `7.1525574e-07` for routing state; all passed their declared tolerances.
- Tissue CPU-to-Metal maximum absolute error was `5.9604645e-08` against a `3e-05` tolerance. Replay, rejected retry, and root abort were exact.
- `activity.png` is the inspected final synthetic activity heatmap. It is an implementation-inspection artifact, not a biological image.

The reported `0.0329597` GPU seconds and derived update rates are retained only as bounded run telemetry. The probe was not run under a profiler, did not capture GPU counters, and does not establish production performance.

SHA-256:

```text
4599216052f85048135fed2a8784727b447aaa074dd62a3f612bab336fb45845  run.json
a5a4425bff453dc11d118241f6a7625734e4bfc929c5284a540de50787669d46  activity.png
```

The current root-level bridge preserves causal timestamps and transaction semantics but runs after the accepted tissue candidate sequence. Fast emergency interruption during an in-progress NumanX physical substep remains future Phase 1 interop work.
