# NumiBrain-NumanX joint-root evidence v0.3

Date: 2026-08-27

## Exact revisions

- NumiBrain: `e44009a8e506a6ac44d16b15f31cd69cca8f083f`
- NumanX isolated interop branch: `949821f3e286b5f3d01b9c10a956f7334640bce9`
- NumanX base: `b913350fbf46dd88e8eca2a893c08ea4c442b2b0`

The original NumanX checkout was not modified. Its pre-existing visual-probe
change remained outside the isolated interop worktree.

## Device and inputs

- Execution device: Apple M4 MacBook Air, 24 GB
- macOS: 26.6 build 25G5028f
- Swift: 6.3
- Bridge and NumanX dylibs: compiled on Apple M4 Pro, then executed on the M4
- Full-body asset: 157 Core bodies, 128 velocity DoFs, 416 source muscles
- Output profile: all 416 source muscles in exact `.nhmyo` record order
- Active proof gains: first six channels; remaining 410 channels are explicit,
  valid, zero-rest, zero-gain entries

The 416 source-tendon identifiers span `0...423`; identifiers `210...213` and
`277...280` are absent from the asset. The runtime preserves the 416-record
asset order and does not treat tendon identifiers as dense buffer indices.

Artifact SHA-256 values:

```text
a0de9c9caf71b21ae26e140ec711797f3feab73f22dedb247378b1206aa98240  libmetalrobo_numibrain_myosim_bridge.dylib
dbae02e449ec4ee9490b62b7f34bdfe6bc5dbaf2df699c0c9f5cf0dfbf5844fb  libmetalrobo.dylib
e2a888d2571266298aea614fb06a7b079964e01cdaa844ad9f6edbdedbc1af22  MetalRobo.metallib
91faa4f471653ec859f47af696e89b59a99f19decb0bb77b8bbd02d5725335b8  myosim-fullbody-core-reference.nhrigid
64c1f24fb76e7ebac256688f8f969e7b81232f6cbd7e419e8998622bd3476af1  myosim-fullbody-muscle-reference.nhmyo
```

## Executed causal loop

The standalone `numi-brain-numanx-interop` process performed one three-
microsecond joint root:

```text
NumiBrain 416-channel private FP32 excitation buffer
  -> retained MTLBuffer lease
  -> NumanX 416-muscle MyoSim force evaluation
  -> articulated Core state integration
  -> accepted peak-tendon muscle-load transduction
  -> emergency and spinal regional prefix
  -> stronger next NumiBrain excitation
  -> three accepted physical substeps
  -> brain and physical root publication
```

All 416 muscle activations began at zero. Before the accepted sequence, the
process deliberately rejected one complete neural and physical candidate.
Retry preserved random-counter generation and
reproduced excitation, muscle force, generalized force, articulated delta, and
physical-state fingerprint exactly. Two fresh processes emitted byte-identical
3,216-byte JSON. A third fresh process produced the same stdout SHA-256:

```text
a8a1c6d050e341f9680db9b0bb48d718e335c2813519641a76d017c5cd5742ec
```

The exact NumiBrain revision passed all 80 XCTest cases on the M4.

## Selected result

```json
{
  "actual_borrowed_buffer": true,
  "brain_commit_fingerprint": 9849654721530407033,
  "brain_generation": 1,
  "candidate_maximum_activations": [6.6666671045823023e-06, 7.1999085776042193e-05, 0.00014130784256849438],
  "candidate_maximum_commanded_force_muscle_identifiers": [3, 3, 3],
  "candidate_maximum_commanded_muscle_forces": [31.959905624389648, 31.960380554199219, 31.960857391357422],
  "candidate_maximum_configuration_deltas": [2.4899460921308017e-08, 4.9798921868104943e-08, 7.4698308831218343e-08],
  "candidate_maximum_excitations": [0.05000000074505806, 0.51999998092651367, 0.51999998092651367],
  "candidate_maximum_force_muscle_identifiers": [215, 215, 215],
  "candidate_maximum_generalized_forces": [942.63714599609375, 942.63714599609375, 942.63433837890625],
  "candidate_maximum_muscle_forces": [560.65289306640625, 560.65289306640625, 560.65289306640625],
  "candidate_maximum_velocity_deltas": [0.024899460921308018, 0.02489946094679692, 0.024899386963113411],
  "candidate_physical_fingerprints": [606283178394084460, 8769330556077453051, 16364611731806220639],
  "device": "Apple M4",
  "numanx_generation": 3,
  "numanx_motor_profile_fingerprint": 3884549367025609669,
  "numanx_muscle_count": 416,
  "numanx_state_fingerprint": 16364611731806220639,
  "physics_generation": 103,
  "receptor_event_source": "accepted-numanx-myosim-muscle-force",
  "receptor_event_threshold": 1,
  "receptor_interrupt": "muscle-overload",
  "rejected_candidate_replayed_exactly": true,
  "rejected_physical_fingerprint": 606283178394084460,
  "rejected_random_counter_generation": 0,
  "retry_random_counter_generation": 0,
  "status": "pass"
}
```

The accepted physical consequence raised the next-candidate maximum neural
excitation from `0.05` to `0.52`. Starting from rest, maximum activation rose
on every accepted candidate, and commanded source tendon `3` force rose from
`31.9599056` to `31.9608574`. Source tendon `215` produced the largest global
absolute MyoSim force through the model's passive bias and became the overload
receptor identity. The scheduler received the derived event, not the
authoritative force vector.

## Evidence boundary

This adds exact full-muscle buffer ordering to the v0.2 causal and rollback
proof. It does not establish complete body mapping or production execution:

- Only the first six channels have fixture protective gains. The other 410 have
  zero NumiBrain output gain until attachment-aware or learned control is
  available; their NumanX muscles can still produce passive force.
- The global overload in this probe is a passive-load event from source tendon
  `215`; it is not evidence that the globally strongest muscle was neurally
  activated. Commanded activation and force are reported separately.
- Source-tendon identity is not yet mapped to route sites, body identifiers,
  joint spans, body side, receptor geometry, or anatomical labels.
- NumiBrain and NumanX use separate Metal command queues and synchronize each
  neural candidate before NumanX consumes its private buffer.
- NumanX MyoSim force evaluation is on Metal, but the bridge stages diagnostics
  and advances articulated Core state on the CPU with a 1 us step.
- Brain and physical roots publish sequentially after validation; there is no
  atomic cross-runtime GPU pointer swap.
- The first rejection is deliberate, not generated by an adaptive NumanX
  physical solver condition.
- Gains and the overload threshold are deterministic fixtures, not anatomical
  or biological calibration.
- This is correctness and causality evidence, not throughput, latency, energy,
  Metal-counter, or biological-behavior evidence.

An M4 Pro execution was intentionally not launched while an unrelated 2,048-
environment crow training workload owned that GPU.
