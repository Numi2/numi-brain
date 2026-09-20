# Pain and pleasure native comparison attempt

Status: **partial; no completed behavior comparison or benefit result**.

Protocol v2 attempted a matched ReachHold run with affect enabled and disabled
on 2026-09-20. Each arm reached 103 accepted native roots and rejected control
step 104, far short of the frozen 10,002-root horizon. The original capture
artifacts omitted the exact support row and impulse. Isolated diagnostic
replays later identified the same invalid support impulse in both arms, but
the disabled replay had one step-30 sensor-packet fingerprint mismatch against
its original accepted prefix. The pair remains incomplete and no benefit is
demonstrated. See [NATIVE_PAIR_REVIEW.md](NATIVE_PAIR_REVIEW.md) for the full
failure analysis and [diagnostic-rerun/README.md](diagnostic-rerun/README.md)
for the retained diagnostic replays.

A separate follow-up retained accepted row-12 support impulses at roots 98–103. The traces are identical across affect-enabled and disabled runs; after a root-99 peak, the final value is below root 98 before both reject step 104. The pair remains partial, and this bounded trace supplies neither a safe correction nor a behavior/benefit result; see [support-history diagnostic](support-history-diagnostic/README.md).

The protocol and capture inputs are retained here:

- `protocol-v2.json`, SHA-256 `3af89a431c40159dcd4cf6b325e41c10467ccf3a22089df07974498729a265ea`
- `study-v2.json`, SHA-256 `babbcf0242ccf7c1d973a88e33188dd6b61272aec2a017a906857504a62ff954`
- `disabled-capture-v2.json`, SHA-256 `45fced3fe7aee1de9b8eeaaf6183301521e0161e5309c071c37ee076d70c5fff`
- `disabled-capture-v2.log`, SHA-256 `fc538e4e87bdeaabdd4dcbbcd8aa1263a32d40dc6497cfb62d39c5a3cef5485c`
- `artifacts/972d778c59d7273edcabcf8013fd60ffff0762e8de28a4cc3ec9035c77376c0f.artifact`, the enabled capture report (SHA-256 matches its filename).
- `artifacts/35605c84525dd602495b580ea03679cc4cd1c26baa885ebe1289917c7919b598.artifact`, the disabled capture report (SHA-256 matches its filename).

The current review SHA-256 is
`eebf0b4df6f83eb3228f197794212665c29706682b4d1014b33ac49b1a7ecea3`.
The full 2,287-file, 279 MB content-addressed artifact store and rebuilt native
products remain on the Mac mini at
`/Users/n/numi-brain-affect-native-pair-20260920/`; per-run capture hashes and
the restored pre-existing product hashes are listed in the review. This
repository snapshot retains both capture reports and the failure record
without importing the full per-step artifact store. The additional small
diagnostic logs, configs, reports, and failure artifacts are preserved under
`diagnostic-rerun/`.

The pair must remain ineligible until both runs reach the frozen horizon and
produce complete behavior evaluations. No behavioral benefit is claimed.
