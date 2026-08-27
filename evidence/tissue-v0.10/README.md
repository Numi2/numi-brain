# Tissue v0.10 dynamic-routing local evidence

This directory captures a bounded local correctness probe of the integrated tissue, scheduler, recurrent regional-token, delayed-route, and dynamic-routing path at source commit `91a4a99469637701816c162cb855ea87788d0c0a` on an Apple M4 running macOS 26.6 build 25G5028f. It is not a Mac mini run, an uncontended performance measurement, a large-cohort qualification, or biological validation.

The debug runtime was built from the committed source after the full 40-test suite passed. The evidence command was:

```sh
NUMIBRAIN_REVISION=91a4a99469637701816c162cb855ea87788d0c0a \
  .build/debug/numi-brain-tissue \
  --backend metal \
  --width 64 \
  --height 48 \
  --duration-ms 20 \
  --control-ms 20 \
  --structure layered \
  --delays layered \
  --connectome bilateral \
  --stimulus-start-ms 2 \
  --stimulus-end-ms 12 \
  --stimulus-noise 0.25 \
  --seed 0x4e554d49 \
  --verify-cpu \
  --verify-replay \
  --output evidence/tissue-v0.10/local-development.json
```

## Recorded correctness facts

- Schema `numibrain.tissue-simulation-evidence.v10` identifies regional program version 2 and fingerprint `704931c121ffb989`.
- The 10,752-scalar regional program exposes seven candidate routes and receiver normal-route budgets `[0, 1, 0, 0, 1, 1, 0, 1]`.
- The committed routing snapshot hash is `d8b24dfc35f669e0`. Six routes were active: four normal routes plus both emergency routes.
- The route-runtime generations use 448 bytes total. Compacted route-index and per-module count scratch use 28 and 32 bytes.
- Route score/strength CPU-to-Metal maximum absolute error was `4.7683716e-07` against a `3e-06` tolerance. Discrete active flags, selection counts, last-selected timestamps, and switch counts matched exactly.
- Token CPU-to-Metal error was `1.7881393e-07`; delayed route-history error was `1.7881393e-07`; diagnostic-state error was `1.4901161e-08`. All passed their declared tolerances.
- The scheduler emitted 83 canonical invocations through one GPU scheduler dispatch. The regional path issued one GPU dispatch, recorded 70 route selections and six active-state switches, and matched the CPU scheduler exactly.
- Replay, rejected retry, and root abort were exact across tissue, clocks, regional diagnostics, tokens, route history, and routing state.
- The tissue result matched the CPU oracle within `8.940697e-08` against a `3e-05` tolerance.

The reported `0.00763683` GPU seconds and derived update rates are retained only as debug-run telemetry. This probe was not run under a profiler, did not capture GPU counters, and did not establish production performance.

SHA-256:

```text
20d686412983dfefd92db25ef5aeea82859bd151c92629e0ac613d0181e4af6f  local-development.json
```

The dedicated tests provide the stronger routing semantics evidence: sender-token content changes the normal top-k winner, emergency bypass remains active, the 2 ms persistence window prevents premature switching, and CPU/Metal states agree. This artifact does not establish learned/context-conditioned routing, capacity balancing, differentiable routing training, calibrated neuroscience, NumanX coupling, the complete 96-module graph, or production throughput.
