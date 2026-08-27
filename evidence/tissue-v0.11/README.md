# Tissue v0.11 receptor-interrupt evidence

This directory captures bounded correctness probes of the integrated tissue, receptor-interrupt, scheduler, recurrent regional-token, delayed-route, and dynamic-routing path at source commit `45f53e405fc332e2397f37f060f6cf762b99452b`. The primary larger run used the Mac mini's Apple M4 Pro on macOS 26.6 build 25G72 after confirming the prior crow workload had ended. A smaller Apple M4 run on build 25G5028f is retained as a second-device control. These are not profiler-backed performance measurements, large-cohort qualifications, mid-NumanX-substep interrupt qualifications, or biological validation.

The release runtime was built from committed source after the full 42-test suite passed on both machines. The Mac mini evidence command used a 256x192 sheet; the local command below used 64x48, with all other behavioral flags identical:

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

The corresponding heavy command ran over SSH from `/Users/n/numi-brain` with `--width 256 --height 192`, writing `/tmp/numibrain-v011-mini-run.json` and `/tmp/numibrain-v011-mini-activity.png`; every remaining option and the recorded source revision were identical.

The Mac mini wrote its original artifacts to `/tmp/numibrain-v011-mini-*`; they are checked in here as `mini-m4-pro.json` and `mini-m4-pro.png` without altering the runtime JSON.

## Recorded correctness facts

- Schema `numibrain.tissue-simulation-evidence.v11` records one compiled 64-byte receptor event with hash `52f0ffca9a184452`, pain mask `1`, and 500 microseconds of conduction latency. The configured 10 ms onset therefore has an effective interrupt timestamp of 10.5 ms.
- Three root transactions issued three `transduce_receptor_interrupts` dispatches. Exactly one receptor onset entered the private 1,536-byte merged interrupt queue; the final root correctly contained zero repeated events.
- The private transduction result reported status zero. The scheduler committed at 60,000 microseconds, generation 3, with snapshot hash `1e425263c7384285` and exact CPU scheduler parity.
- Regional diagnostics recorded three interrupt deliveries, corresponding to the pain-enabled reference modules. The dedicated Metal test pins their timestamp and module identities and also covers rejected retry, root abort, and adjacent-boundary deduplication.
- The 10,752-scalar regional path retained six active routes, including both emergency routes. CPU-to-Metal maximum errors were `1.4901161e-08` for diagnostics, `1.7881393e-07` for tokens and route history, and `7.1525574e-07` for routing state; all passed their declared tolerances.
- The 256x192 M4 Pro tissue run matched its CPU oracle within `1.1920929e-07`; the smaller M4 control error was `5.9604645e-08`. Both used a `3e-05` tolerance. Replay, rejected retry, and root abort were exact on both machines.
- `activity.png` is the inspected final synthetic activity heatmap. It is an implementation-inspection artifact, not a biological image.

The M4 Pro run reported `0.0205063` GPU seconds for 60 accepted 1 ms steps over 49,152 sites; the smaller M4 control reported `0.0329597` seconds over 3,072 sites. These values and derived rates are retained only as bounded run telemetry. Neither probe was run under a profiler or captured GPU counters, so they do not establish comparative or production performance.

SHA-256:

```text
4599216052f85048135fed2a8784727b447aaa074dd62a3f612bab336fb45845  run.json
a5a4425bff453dc11d118241f6a7625734e4bfc929c5284a540de50787669d46  activity.png
462fb4410f58124b335b2485ae50198f815c0153ea65f1c3db075198c44058ee  mini-m4-pro.json
6f39ed81139b9e56668ed1e0ea6391b05a66435dee2ca00de30455522934fbfb  mini-m4-pro.png
```

The current root-level bridge preserves causal timestamps and transaction semantics but runs after the accepted tissue candidate sequence. Fast emergency interruption during an in-progress NumanX physical substep remains future Phase 1 interop work.
