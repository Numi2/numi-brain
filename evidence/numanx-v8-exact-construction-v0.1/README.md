# NumanX v8 exact-clock construction admission

Status: `construction_admission_passed`

This receipt qualifies one construction boundary only. NumiBrain commit
`87e7b13928c700b1dcbc108c98f55bab003cdd60` passed the native-v8 prepared-state
admission test against clean Numi Human native commit
`b1a9bdd3b27afa6daedff37c276a5b0b2b600c54` on the physical Apple M4 Pro Mac
mini with Metal API validation enabled.

The exact `12,500 ns` word reached the authored Matter runtime without
microsecond rounding; the nested legacy microsecond word was zero. The admitted
tuple bound the Human source, NHEQ2, NHLIM1, NHCNT2, Matter package/world,
NHINIT3 state, visual pack, vision profile, runtime library, and both metallibs.

This does not qualify a Brain accepted root, witness/ACK publication, support-
history continuation, equilibrium, standing, behavior, anatomy, physiology, or
performance. The current Gate C transaction and ACK ABIs still use whole
microseconds and therefore reject this exact-clock configuration.

`receipt.json` contains the immutable identities. `attempt-ledger.json` retains
the failed mixed-source, mixed-visual, and invalid-authoring attempts rather
than hiding them. `native-admission.log` is the passing test output, and
`vision-profile.json` preserves the synthetic, unqualified vision input used by
this construction test.

The relevant local test remains:

```sh
swift test --filter MetalNumanXRuntimeConfigV8Tests
```

The physical test is environment-gated:

```sh
MTL_DEBUG_LAYER=1 swift test --skip-build \
  --filter MetalNumanXBridgeV1EndToEndTests/testExactNanosecondPreparedStateNativeAdmission
```

All sustained or GPU-dependent reruns belong on `ssh macmini` after checking
for competing workloads and available disk.
