# NumiBrain-NumanX joint-root evidence v0.4

Date: 2026-08-27

## Exact revisions

- NumiBrain: `c0f2bf8e00fe003c8e3831af05408ae6759f0f86`
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

## New attachment boundary

The NumanX bridge now exposes, in exact muscle-record order:

- source tendon identifier;
- first and terminal route-site Core body identifiers;
- first and terminal body-local route-site coordinates;
- route-node count;
- body count; and
- one canonical full-catalog fingerprint.

NumiBrain reconstructs that data into an immutable, Codable attachment
catalog. It rejects duplicate muscles, out-of-range bodies, routes shorter than
two nodes, nonfinite coordinates, serialization fingerprint drift, motor-
profile order drift, and C++/Swift catalog fingerprint disagreement.

First and terminal retain source route order. They do not assert anatomical
proximal/distal or left/right semantics.

## Executed result

Two fresh processes emitted byte-identical 3,895-byte JSON. A third fresh
process produced the same stdout SHA-256:

```text
06d1dc1ed0dce68cab0360b2ff2ef9523fb01a933adf94ca141a75d905d72a3b
```

Selected fields:

```json
{
  "status": "pass",
  "device": "Apple M4",
  "numanx_body_count": 157,
  "numanx_muscle_count": 416,
  "numanx_attachment_catalog_fingerprint": 7376770455185784103,
  "candidate_maximum_force_muscle_identifiers": [215, 215, 215],
  "candidate_maximum_force_first_body_identifiers": [41, 41, 41],
  "candidate_maximum_force_terminal_body_identifiers": [34, 34, 34],
  "candidate_maximum_force_route_node_counts": [6, 6, 6],
  "receptor_attachment_first_local_point": [0.022691911086440086, 0.004122359212487936, -0.0013849650276824832],
  "receptor_attachment_terminal_local_point": [0.074710026383399963, 0.0064713223837316036, -0.0013830797979608178],
  "candidate_maximum_commanded_force_muscle_identifiers": [3, 3, 3],
  "candidate_maximum_commanded_force_first_body_identifiers": [16, 16, 16],
  "candidate_maximum_commanded_force_terminal_body_identifiers": [1, 1, 1],
  "candidate_maximum_commanded_force_route_node_counts": [2, 2, 2],
  "candidate_maximum_activations": [6.6666671045823023e-06, 7.1999085776042193e-05, 0.00014130784256849438],
  "candidate_maximum_commanded_muscle_forces": [31.959905624389648, 31.960380554199219, 31.960857391357422],
  "rejected_candidate_replayed_exactly": true
}
```

The cross-language catalog fingerprint is `665f8da52af1fd27`. The passive-load
event from tendon `215` is now mechanically localized to the route from body
`41` to body `34`, with its source body-local endpoints retained. Commanded
tendon `3` is independently localized from body `16` to body `1`.

All v0.3 transaction, activation-from-rest, force, physical-motion, accepted-
feedback, joint-commit, and rejected-retry checks remained active and passed.

## Evidence boundary

This is route-endpoint mechanical localization, not anatomical interpretation:

- Core body indices do not yet carry stable human-readable anatomical names,
  body side, vulnerability class, receptor density, or sensory innervation.
- The catalog records endpoint sites and total route-node count, not every
  intermediate site/wrap body in NumiBrain.
- The overload event still uses tendon ID as its scheduler identifier. Endpoint
  geometry is available to the body adapter but is not yet a body-schema token.
- Protective output remains a global fixture; it does not yet select muscles
  from the affected endpoint bodies.
- The separate-queue synchronization, staged diagnostics, CPU articulated
  integration, sequential publication, deliberate rejection, fixture gains,
  and non-performance boundaries from v0.3 still apply.

An M4 Pro execution was intentionally not launched while an unrelated 2,048-
environment crow training workload owned that GPU.
