# NumiBrain-NumanX joint-root evidence v0.5

Date: 2026-08-27

## Exact revisions

- NumiBrain: `be07275f8d70f15de3bc3b309c97ff8e2167980c`
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
- NumiBrain tests: 83 passed

Artifact SHA-256 values:

```text
68962fe6c2fd822c10287338ae469b50336424def09e5a98c929cb37573fb16d  libmetalrobo_numibrain_myosim_bridge.dylib
dbae02e449ec4ee9490b62b7f34bdfe6bc5dbaf2df699c0c9f5cf0dfbf5844fb  libmetalrobo.dylib
e2a888d2571266298aea614fb06a7b079964e01cdaa844ad9f6edbdedbc1af22  MetalRobo.metallib
91faa4f471653ec859f47af696e89b59a99f19decb0bb77b8bbd02d5725335b8  myosim-fullbody-core-reference.nhrigid
64c1f24fb76e7ebac256688f8f969e7b81232f6cbd7e419e8998622bd3476af1  myosim-fullbody-muscle-reference.nhmyo
```

## New committed localization boundary

`LocalizedMuscleLoadReceptorObservation` binds one receptor-derived overload
event to:

- the exact accepted-physics fingerprint;
- the immutable attachment-catalog fingerprint;
- the accepted maximum absolute muscle force; and
- the source tendon plus ordered endpoint bodies and body-local coordinates.

The joint transaction rejects a localized observation unless its physical
fingerprint matches the accepted candidate and its event appears in that
candidate's canonical accepted receptor packet. Rejected candidates cannot
append observations. Root commit publishes the canonical accepted list only
after the Metal root publishes; root abort leaves the preceding committed list
unchanged. A later successful root commit replaces the list, including with an
empty list when no localized overload was accepted.

## Executed result

Two fresh processes emitted byte-identical 4,011-byte JSON. A third fresh
process produced the same stdout SHA-256:

```text
a46056efbb9410787a66de71e6e00f653f0564b8378574e59bd4bf2052c3a787
```

Selected fields:

```json
{
  "status": "pass",
  "device": "Apple M4",
  "numanx_body_count": 157,
  "numanx_muscle_count": 416,
  "numanx_attachment_catalog_fingerprint": 7376770455185784103,
  "committed_localized_muscle_load_count": 1,
  "committed_localized_muscle_load_catalog_fingerprint": 7376770455185784103,
  "candidate_maximum_force_muscle_identifiers": [215, 215, 215],
  "candidate_maximum_force_first_body_identifiers": [41, 41, 41],
  "candidate_maximum_force_terminal_body_identifiers": [34, 34, 34],
  "candidate_maximum_force_route_node_counts": [6, 6, 6],
  "candidate_maximum_commanded_force_muscle_identifiers": [3, 3, 3],
  "candidate_maximum_activations": [6.6666671045823023e-06, 7.1999085776042193e-05, 0.00014130784256849438],
  "candidate_maximum_commanded_muscle_forces": [31.959905624389648, 31.960380554199219, 31.960857391357422],
  "rejected_candidate_replayed_exactly": true
}
```

The committed observation is tendon `215`, route bodies `41 -> 34`, with the
same force and local endpoint coordinates returned by the accepted NumanX
candidate. All v0.4 attachment, activation-from-rest, physical-motion,
accepted-feedback, joint-commit, and exact-retry checks remained active.

## Evidence boundary

- The committed list is a bounded Swift transaction sidecar, not a GPU body-
  schema tensor, a long-term sensory history, or an episodic-memory record.
- Endpoint order is mechanical source-route identity, not anatomical
  proximal/distal, body-side, vulnerability, or innervation semantics.
- Protective output is still selected from the global interrupt command. It
  does not yet target the affected endpoint bodies or nearby muscles.
- The overload threshold remains an uncalibrated fixture value.
- Separate queues, staged diagnostics, CPU articulated integration, sequential
  cross-runtime publication, deliberate rejection, fixture gains, and non-
  performance boundaries from v0.4 still apply.

An M4 Pro execution was intentionally not launched while an unrelated 2,048-
environment crow training workload owned that GPU.
