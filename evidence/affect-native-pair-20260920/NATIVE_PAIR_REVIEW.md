# NumiBrain pain/pleasure native pair review

Date: 2026-09-20

## Result

The frozen 1-second ReachHold comparison did not complete. Each arm reached 103 accepted native roots, then rejected control step 104. No complete run artifact, behavior evaluation, affect-study result, eligibility result, or benefit comparison was produced. The protocol remains unqualified for native behavior benefit.

Both arms used protocol v2 (`protocol-v2.json`, SHA-256 `ccc397bdb04786c05765da6beb02d47ccceacad4f0dfd1624afc767291be5707`) against the same recooked ABI39 world/runtime and initial state. The arms differed only in the affect `isEnabled` setting and run ID. Their per-step sample hashes match across all 104 attempted steps.

## Failure evidence

- Enabled arm capture artifact SHA-256: `972d778c59d7273edcabcf8013fd60ffff0762e8de28a4cc3ec9035c77376c0f`.
- Disabled arm capture artifact SHA-256: `35605c84525dd602495b580ea03679cc4cd1c26baa885ebe1289917c7919b598`.
- Both captures report 104 completed execution records, 103 accepted and one rejected at control step 104. The rejected record has `jointCommitFingerprint=0`; its sample remains at physics generation 103 and committed time 10,400 µs.
- The disabled diagnostic log has 104 Matter/Human diagnostic pairs. The last Matter status is code 6, `NM_STATUS_CONTACT_FAILURE`; the last Human status is code 0. The Matter diagnostics are `[-1, 0, 0.00201139692, 0.000509521575]`.
- That tuple matches the pinned Matter Metal `nm_human_support_certify` check, which rejects a non-finite or negative Human support-contact normal impulse. Both failing row and impulse indices are `UINT_MAX`, so the offending support row/value is not retained. This is not `MR_STEP_MANIFOLD_CAPACITY_OVERFLOW`; that is code 6 in a different MetalRobo status enum.
- The adjacent Human maximum generalized acceleration rises from 140.78 at root 103 to 6092.99756 at rejected root 104. Matter FGMRES reports 10 iterations at roots 102-104. This is a sharp instability signal, but the current artifacts do not identify a safe solver, controller, or initial-state correction. Increasing contact/manifold capacities is unsupported by these diagnostics.
- The next request is rejected with runtime status 7 at request-failure stage 7. Pinned-source validation identifies this as control-step continuity: because step 104 was rejected and not published, the next request used step 105 while the runtime still expected 104. No root 105 was executed.
- The same terminal sequence occurred in both arms. The artifacts do not preserve the enabled arm's step-104 Matter diagnostic, so its exact Matter status is not established independently.

This is a failed/partial capture, not a solved behavior result. The frozen 10,002-root horizon per arm was not reached. Identical samples and matching action artifact hashes do not establish pain/pleasure benefit.

## Isolated diagnostic replays

After the original captures, both arms were replayed from the same prepared
initial state with `MRNX_PHYSICAL_DIAGNOSTICS=1` and an isolated instrumented
Matter product. The diagnostic-only source diff records the first invalid
support row and its unmodified normal impulse; it does not change solve
arithmetic or control behavior. The isolated Matter metallib SHA-256 is
`2b3f9055a63dc189f6badb550c34b4aae1df187257f6edecfaf4252503f04546`; the
diagnostic source diff SHA-256 is
`d058aba19b06821dfd3bece4f21133df4f91398f7f5d8d10e5d0957719b3a1d9`.

Both diagnostic runs again accepted 103 roots and rejected step 104 with
Matter code 6, `NM_STATUS_CONTACT_FAILURE`, on zero-based support row 12. The
normal impulse is `-0.000127762556`, below the certifier's `-1e-7` bound; support
and rigid residual norms are `0.00201139692` and `0.000509521575`. Human's
adjacent maximum contact acceleration rises from `140.778824` at root 103 to
`6092.99756` at rejected root 104. The subsequent runtime status 7, stage 7
is control-step continuity after step 104 failed to publish; step 105 did not
execute.

Source mapping identifies row 12 as authored NHCNT2 primitive 6's capsule
endpoint A: geometry 406 (`foot_col3_l`), engine body 152, mapped by the
MyoSim manifest to source body 101 (`calcn_l`). The contact file SHA-256 is
`c7712daf79cd8a589a6d23942a4df84a7da928e5911455ce19078f9b24daaaf4`; the
NHRIGID2 input SHA-256 is
`6328f7e84663c611c5498624d1386b00b2d5b0e162c4cc2967c7b1dc49ab0c44`. There is
no obvious row identity or left/right source mismatch. These MyoSim witnesses
are described as foot support witnesses against a plane, not as generally
calibrated collision geometry. The captured artifacts do not retain row-12
impulses for roots 1–103, so they cannot show when the sign error began or
support a safe solver/controller/input correction. The rejection threshold
remains unchanged.

The enabled diagnostic replay matches its original accepted sample hashes at
all 103 roots. The disabled replay matches 102/103; its only mismatch is at
control step 30, where all seven channel descriptor/value/validity hashes are
equal but the `sensorPacketFingerprint` differs. The diagnostic arms' step-104
rejected sample hashes agree, but this metadata mismatch means the diagnostic
rerun does not establish exact matched provenance. Neither arm completed the
frozen horizon, and no behavioral benefit is demonstrated. Configs, logs,
reports, and failure artifacts are retained in
[`diagnostic-rerun`](diagnostic-rerun/README.md).

The prepared fixture describes three tiny pelvis samples and does not
establish anatomical or sustained-behavior qualification.

## Native products and workspace restoration

The exact-source rebuilt products are preserved in `native-products/`:

- `libmetalrobo.dylib`: `6a556d5e98b267ac24f9228c5b380180769443062fd8487a012dc4fadc92c233`
- `MetalRobo.metallib`: `01c06a45eed3172dbbf71a51950549259db47adbfddd944f4376f4a2de0003ce`
- `NumiMatter.metallib`: `e47aeed89fdb66d8deea4f9c850aa9655925f65755593800b8e342c4182a965f`

The pre-existing products in `/Users/n/MetalRobo-human-activation-build-20260913/` were restored from the verified snapshot. Their restored hashes are `1ec529857ac312856945ae97aa56d3bd6718602ddc6ab0b539de4ada87ab6054`, `8528bcc13e0da983d154e969518164129e7f31189a444858ce20dca8b9ab8ca0`, and `3b7fcb4fffe099d57d61fe8a9d69e58530b9caadc05f9eabcc1d883d38d79a38`, respectively.
