# NumiBrain-NumanX joint-root evidence v0.2

Date: 2026-08-27

## Exact revisions

- NumiBrain: `20ca7ffb33494565db152f8199d91eb175e28834`
- NumanX isolated interop branch: `cfcef811f606d4b53259304d096914a88492fdfc`
- NumanX base: `b913350fbf46dd88e8eca2a893c08ea4c442b2b0`

The original NumanX checkout was not modified. Its pre-existing visual-probe
change remained outside the isolated interop worktree.

## Device and inputs

- Execution device: Apple M4 MacBook Air, 24 GB
- macOS: 26.6 build 25G5028f
- Swift: 6.3
- Bridge and NumanX dylibs: compiled on Apple M4 Pro, then executed on the M4
- Full-body asset: 157 Core bodies, 128 velocity DoFs, 416 source muscles
- Active proof profile: the first six `.nhmyo` source-tendon identifiers

Artifact SHA-256 values:

```text
df1827f5868241c4e43bf41ae7344b5a1ee64aafbadaca355ccece3475f3d33f  libmetalrobo_numibrain_myosim_bridge.dylib
dbae02e449ec4ee9490b62b7f34bdfe6bc5dbaf2df699c0c9f5cf0dfbf5844fb  libmetalrobo.dylib
e2a888d2571266298aea614fb06a7b079964e01cdaa844ad9f6edbdedbc1af22  MetalRobo.metallib
91faa4f471653ec859f47af696e89b59a99f19decb0bb77b8bbd02d5725335b8  myosim-fullbody-core-reference.nhrigid
64c1f24fb76e7ebac256688f8f969e7b81232f6cbd7e419e8998622bd3476af1  myosim-fullbody-muscle-reference.nhmyo
```

## Executed causal loop

The standalone `numi-brain-numanx-interop` process performed one three-
microsecond joint root:

```text
NumiBrain private FP32 excitation buffer
  -> retained MTLBuffer lease
  -> NumanX MyoSim excitation binding and force evaluation
  -> articulated Core state integration
  -> accepted tendon-local muscle-load transduction
  -> emergency and spinal regional prefix
  -> stronger next NumiBrain excitation
  -> three accepted physical substeps
  -> brain and physical root publication
```

Before the accepted sequence, the process ran and rejected one complete neural
and physical candidate. The retry used a different attempt fingerprint but the
same random-counter generation and produced exactly the same excitation,
muscle force, generalized force, articulated delta, and physical-state
fingerprint. Two fresh process executions then emitted byte-identical JSON.

The exact NumiBrain revision also passed all 80 XCTest cases on the M4.

## Selected result

```json
{"actual_borrowed_buffer":true,"brain_commit_fingerprint":11596874075580636004,"brain_generation":1,"candidate_maximum_configuration_deltas":[1.6653824719304015e-10,3.3307372410443814e-10,4.9960775218315794e-10],"candidate_maximum_excitations":[0.05000000074505806,0.51999998092651367,0.51999998092651367],"candidate_maximum_force_muscle_identifiers":[3,3,3],"candidate_maximum_generalized_forces":[11.332053184509277,11.331860542297363,11.331766128540039],"candidate_maximum_muscle_forces":[67.621917724609375,67.621116638183594,67.620315551757812],"candidate_maximum_velocity_deltas":[0.00016653824719304016,0.00016653547691139795,0.00016653402807871977],"candidate_physical_fingerprints":[18236966636526808663,11393711271465850345,14500061546006164469],"device":"Apple M4","numanx_generation":3,"numanx_motor_profile_fingerprint":16797411339950764209,"numanx_muscle_identifiers":[0,1,2,3,4,5],"numanx_state_fingerprint":14500061546006164469,"physics_generation":103,"receptor_event_source":"accepted-numanx-myosim-muscle-force","receptor_event_threshold":1,"receptor_interrupt":"muscle-overload","rejected_candidate_replayed_exactly":true,"rejected_physical_fingerprint":18236966636526808663,"rejected_random_counter_generation":0,"rejected_substep_fingerprint":5336165883462070331,"retry_random_counter_generation":0,"retry_substep_fingerprint":16947244300629067914,"status":"pass"}
```

The accepted physical consequence raised the next-candidate maximum neural
excitation from `0.05` to `0.52`. Source tendon `3` produced the largest
absolute MyoSim actuator force and became the receptor identity; the scheduler
received the derived overload event, not the authoritative force vector.

## Evidence boundary

This establishes one real same-process causal loop and deterministic rejected-
candidate replay. It does not establish production GPU residence or physical
performance:

- NumiBrain and NumanX use separate Metal command queues. The reference process
  waits for each NumiBrain candidate before NumanX consumes its private buffer.
- NumanX MyoSim force evaluation is on Metal, but this bridge stages diagnostic
  results and advances the articulated Core state on the CPU with a 1 us step.
- Brain and physical roots publish sequentially after validation; there is no
  atomic cross-runtime GPU pointer swap yet.
- The executable deliberately rejects its first candidate. A NumanX solver-
  generated adaptive-step rejection has not yet been qualified end to end.
- The active profile uses real source-tendon identifiers but only six of 416
  muscles. Its withdrawal and bracing gains and the overload threshold are
  deterministic fixtures, not anatomical or biological calibration.
- Tendon identity localizes the event to one selected muscle, not yet to a
  body-side receptor field, joint, skin site, or injury model.
- The run is correctness and causality evidence, not throughput, latency,
  energy, Metal-counter, or biological-behavior evidence.

An M4 Pro run was intentionally not launched while an unrelated 2,048-
environment crow workload owned that GPU.
