# Tissue v0.8 recurrent regional-token evidence

This directory captures the integrated tissue, scheduler, and recurrent regional-token path at source commit `a237cace5acc14b09034a54f87dc955414434069` on an Apple M4 Pro running macOS 26.6. The release runtime executes `schedule_due_modules` and `advance_due_regional_tokens` after the accepted tissue candidate sequence on one Metal 4 compute encoder. Scheduler clocks, 10,752 token scalars, and compact diagnostic records remain private and publish transactionally with tissue state.

The primary command ran over `ssh macmini`:

```sh
NUMIBRAIN_REVISION=a237cace5acc14b09034a54f87dc955414434069 \
  .build/release/numi-brain-tissue \
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
  --output evidence/tissue-v0.8/tissue-evidence.json \
  --snapshot evidence/tissue-v0.8/tissue-activity.png
```

Two matched controls used the same release binary and exact source revision:

- `no-noise-control.json` changed only `--stimulus-noise 0`.
- `alternate-seed-control.json` changed only `--seed 0x4e554d4a`.

Before the evidence commands, the Mac mini built the exact checkout and passed all 35 tests: 13 tissue CPU tests, 11 scheduler/regional CPU tests, and 11 live Metal tests.

## Recorded correctness facts

- 49,152 tissue sites advanced through 70 accepted 1 ms substeps in four root transactions.
- Metal issued 70 receptor-event compaction dispatches, four scheduler dispatches, and four recurrent regional-token dispatches on the integrated command path.
- The eight-module schedule committed to 70,000 microseconds at generation 4. Clock snapshot hash `7f0410c814a02d9c` exactly matched the CPU scheduler oracle.
- The regional program fingerprint is `7693586fd2b592a9`. It owns 10,752 FP32 token scalars, seven compiled sparse routes, and 344,064 immutable factorized parameter bytes.
- Two private token generations use 86,016 bytes total; the seven 24-byte route records use 168 bytes. The private candidate scratch generation is runtime-resident but is not included in `tokenStateBytes`.
- `advance_due_regional_tokens` consumed the private due list without a host invocation-count readback. Across four roots it executed 271 module updates and produced token snapshot hash `5cc6cce810370af4`.
- The token CPU/Metal maximum absolute error was `1.1920929e-07` against a `3e-06` tolerance.
- The retained diagnostic record snapshot was `d78c1c595e2fe734`; discrete counters and timestamps matched exactly and floating values differed from the CPU oracle by at most `1.4901161e-08`.
- Replay, rejected retry, and root abort were exact for tissue, scheduler, diagnostic, and recurrent token state.
- The main noisy tissue state hash was `1d4534c321f98fe7`. Disabling noise produced `3db4f53ab3fd8e42`; changing only the seed produced `73d0eb346080c5de`.
- All three tissue executions matched the CPU oracle within `1.1920929e-07` against a `3e-05` tolerance.
- All three controls retained the same scheduler, diagnostic, and token hashes. This is expected: v0.8 has no tissue-to-region sensory encoder, so the regional operator currently receives scheduler periodic/interrupt drive and regional routes, not the tissue grid.
- The primary run reported 17,940,480 residency-allocated bytes and 0.0151802 GPU seconds. This is a bounded correctness probe, not an uncontended production throughput qualification.
- The CSR tissue graph retained 4,176 synthetic delayed projections with hash `b2b475f34837ab8a`.

The PNG was inspected after transfer from the Mac mini and is byte-identical to v0.7. It retains the bright left event response, dark central partial-viability lesion, and separated right response aligned with the synthetic mirrored projection band. It visualizes tissue activity only; regional token state is qualified numerically in the JSON and tests.

The Metal test `testMetalSparseRouteChangesOnlyTheCompiledRegionalProgram` compares the seven-route program against an otherwise identical zero-route program. The receiver token state changes while tissue and diagnostic scheduler state remain equal. This is executable sparse-route causality evidence, not dynamic top-k routing, delayed message delivery, anatomical connectivity, learned behavior, or biological validation.

SHA-256:

```text
def011c22632d9682307b63a9d19bbb49b1e4a88f0a0c20c038dde1f37340fe5  alternate-seed-control.json
d1621587ad0e71da7954ec464e8ea8654827bf5467772f05d37fb9ce478401fa  no-noise-control.json
5e6340f3e8965e106d75bff1f58a97538d0912cb2076a0e7199d3a52af6abd1a  tissue-evidence.json
7dbbe8c68a73c2ec509f502d7e6e4072aa8d6122ac9efd2db542e42c932711f5  tissue-activity.png
```

This is source, device-execution, transaction, replay, and numerical-correctness evidence. It is not calibrated neuroscience, trained cognition, NumanX coupling, a complete 96-module brain, or a production performance claim.
