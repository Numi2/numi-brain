# NumiBrain-NumanX joint-root evidence v0.6

Date: 2026-08-27

## Exact revisions

- NumiBrain: `d9569278fd757c982568c2d88f9e4a83d7638844`
- NumanX isolated interop branch: `5cdee510fb4240af4269474f996ed8e016d4ac0e`
- NumanX base: `b913350fbf46dd88e8eca2a893c08ea4c442b2b0`

The original NumanX checkout was not modified. Its pre-existing visual-probe
change remained outside the isolated interop worktree.

## Device and inputs

- Execution device: Apple M4 MacBook Air, 24 GB
- macOS: 26.6 build 25G5028f
- Swift: 6.3
- Bridge and NumanX dylibs: compiled on Apple M4 Pro, then executed on the M4
- Full-body asset: 157 Core bodies and 416 source muscles
- NumiBrain tests: 84 passed

Artifact SHA-256 values:

```text
68962fe6c2fd822c10287338ae469b50336424def09e5a98c929cb37573fb16d  libmetalrobo_numibrain_myosim_bridge.dylib
dbae02e449ec4ee9490b62b7f34bdfe6bc5dbaf2df699c0c9f5cf0dfbf5844fb  libmetalrobo.dylib
e2a888d2571266298aea614fb06a7b079964e01cdaa844ad9f6edbdedbc1af22  MetalRobo.metallib
91faa4f471653ec859f47af696e89b59a99f19decb0bb77b8bbd02d5725335b8  myosim-fullbody-core-reference.nhrigid
64c1f24fb76e7ebac256688f8f969e7b81232f6cbd7e419e8998622bd3476af1  myosim-fullbody-muscle-reference.nhmyo
```

## New body-load and protection boundary

The accepted localized overload now produces three transaction-owned layers:

1. A `CommittedBodyLoadFrame` bound to the exact joint commit, attachment
   catalog, accepted physical token, timestamp, tendon, force, endpoint roles,
   and Core body identifiers.
2. A `LocalizedProtectiveMuscleSelection` containing every motor channel whose
   route shares an affected endpoint body, while marking the actual overloaded
   source tendon separately.
3. A transaction-local Metal mask that zeros the overloaded source channel in
   the next protective motor output and marks the output header with localized
   source inhibition.

The full-body frame contains two samples on bodies `34` and `41`. The mechanical
neighborhood contains 37 source-order motor channels, with tendon `215` as its
only overloaded source. Neighbor selection does not command those neighbors;
safe excitation direction requires anatomical and functional labels.

Rejected physical candidates cannot update the mask, frame, or selection. Root
abort publishes none of their state. A successful root commit publishes the
frame and selection after the Metal root, while the fingerprinted inhibited
motor output is already available to the following physical candidate.

## Executed result

Two fresh processes emitted byte-identical 4,485-byte JSON. A third fresh
process produced the same stdout SHA-256:

```text
a1fd898b01040c2609e9592de1681ddcaebd3dc432d6180261846b5efb8fb04b
```

Selected fields:

```json
{
  "status": "pass",
  "device": "Apple M4",
  "numanx_body_count": 157,
  "numanx_muscle_count": 416,
  "committed_body_load_body_identifiers": [34, 41],
  "committed_body_load_sample_count": 2,
  "committed_body_load_maximum_force": 560.65289306640625,
  "committed_body_load_frame_fingerprint": 15527732247218478807,
  "committed_protective_selection_count": 37,
  "committed_protective_source_muscle_identifiers": [215],
  "committed_protective_selection_fingerprint": 4220600085854809261,
  "localized_source_inhibition_excitation": 0,
  "localized_source_inhibition_output_fingerprint": 5768508391072991119,
  "candidate_maximum_commanded_force_muscle_identifiers": [3, 3, 3],
  "candidate_maximum_activations": [6.6666671045823023e-06, 7.1999085776042193e-05, 0.00014130784256849438],
  "candidate_maximum_commanded_muscle_forces": [31.959905624389648, 31.960380554199219, 31.960857391357422],
  "rejected_candidate_replayed_exactly": true
}
```

The 84-test suite includes a nonzero-gain synthetic muscle and verifies exact
CPU/Metal parity: only the accepted overloaded source channel becomes zero and
the output fingerprint changes. The full-body run verifies that the same Metal
path addresses the real source-order tendon `215`.

## Evidence boundary

- Tendon `215` has zero neural gain in the current 416-channel fixture. Its
  measured `560.6529` force is passive. The full-body run therefore proves
  source-command inhibition and identity, not a reduction in physical load.
- The 37-muscle neighborhood is endpoint connectivity, not anatomy. It carries
  no body side, agonist/antagonist role, vulnerability, or innervation label.
- The body-load frame and neighborhood are compact Swift sidecars. Only the
  source-inhibition mask and motor output are consumed by Metal; a GPU body-
  schema tensor and persistent load dynamics are not implemented.
- The overload threshold remains an uncalibrated fixture value.
- Separate queues, staged diagnostics, CPU articulated integration, sequential
  cross-runtime publication, deliberate rejection, fixture gains, and non-
  performance boundaries from v0.5 still apply.

An M4 Pro execution was intentionally not launched while an unrelated 2,048-
environment crow training workload owned that GPU.
