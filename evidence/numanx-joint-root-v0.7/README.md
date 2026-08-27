# NumiBrain-NumanX joint-root evidence v0.7

Date: 2026-08-27

## Exact revisions

- NumiBrain: `fe62c12c2ed140f9f9c44dbe65f66aa692c2716f`
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

## New private Metal body-load field

`materialize_body_load_field` consumes only accepted localized receptor
updates. It deterministically writes one 32-byte peak-load cell per Core body
into the root-shadow Metal generation. Each active cell retains:

- Core body identifier;
- first/terminal endpoint role;
- source tendon identifier;
- maximum accepted force;
- accepted physical timestamp; and
- accepted physical-state fingerprint.

For multiple accepted loads on one body, force, recency, lower source-tendon
identifier, and lower physical fingerprint define the canonical winner. Equal
source observations merge endpoint roles. The CPU reference implements the
same ordering.

The field uses the same ping-pong generation as the scheduler/regional shadow.
Rejected candidates never enter its update list. Root abort leaves the prior
committed private buffer authoritative. Root commit swaps the field generation
with the rest of the accepted brain shadow. A later root with no accepted load
publishes an empty field.

## Executed result

Two fresh processes emitted byte-identical 4,574-byte JSON. A third fresh
process produced the same stdout SHA-256:

```text
5242ff4771f209c8c9193ca53760b9d91179a55224b13d1fb5216c9246b1c49f
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
  "committed_metal_body_load_body_identifiers": [34, 41],
  "committed_metal_body_load_count": 2,
  "committed_protective_selection_count": 37,
  "committed_protective_source_muscle_identifiers": [215],
  "localized_source_inhibition_excitation": 0,
  "localized_source_inhibition_output_fingerprint": 5768508391072991119,
  "rejected_candidate_replayed_exactly": true
}
```

The executable requires the complete private Metal field to equal the CPU
frame's canonical peak cells before it reports `pass`. The suite separately
tests private-field publication, empty-root clearing, and root-abort restoration.
All v0.6 source-inhibition, neighborhood, attachment, physical-motion, and exact
retry checks remained active.

## Evidence boundary

- This is a root-local load field. It does not yet retain or decay load across
  later no-load roots, estimate vulnerability, or learn body dynamics.
- Numeric Core bodies still lack source-authoritative anatomical names, body
  side, tissue class, receptor density, and innervation labels.
- Accepted updates are assembled in shared memory by the bounded host bridge;
  the state materialization and authoritative field generation are private
  Metal. This is not a fully device-generated sensor path.
- Tendon `215` has zero fixture neural gain and passive force. The run proves
  source-command inhibition identity, not reduced physical load.
- The overload threshold remains an uncalibrated fixture value.
- Separate queues, staged diagnostics, CPU articulated integration, sequential
  cross-runtime publication, deliberate rejection, fixture gains, and non-
  performance boundaries from v0.6 still apply.

An M4 Pro execution was intentionally not launched while an unrelated 2,048-
environment crow training workload owned that GPU.
