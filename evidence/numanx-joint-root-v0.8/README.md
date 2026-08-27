# NumiBrain-NumanX joint-root evidence v0.8

Date: 2026-08-27

## Exact revisions

- NumiBrain: `4f8c2200a761609145c6d4d5824da01e055526b7`
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
- NumiBrain tests: 85 passed

Artifact SHA-256 values remain:

```text
68962fe6c2fd822c10287338ae469b50336424def09e5a98c929cb37573fb16d  libmetalrobo_numibrain_myosim_bridge.dylib
dbae02e449ec4ee9490b62b7f34bdfe6bc5dbaf2df699c0c9f5cf0dfbf5844fb  libmetalrobo.dylib
e2a888d2571266298aea614fb06a7b079964e01cdaa844ad9f6edbdedbc1af22  MetalRobo.metallib
91faa4f471653ec859f47af696e89b59a99f19decb0bb77b8bbd02d5725335b8  myosim-fullbody-core-reference.nhrigid
64c1f24fb76e7ebac256688f8f969e7b81232f6cbd7e419e8998622bd3476af1  myosim-fullbody-muscle-reference.nhmyo
```

## New temporal body-load state

The private field no longer disappears on the first accepted root without a
new overload. Each 56-byte active cell retains:

- Core body and endpoint role;
- source tendon;
- original accepted peak force;
- current effective force;
- accepted receptor timestamp;
- accepted physical-state fingerprint;
- field activation timestamp; and
- current field-state timestamp.

`materialize_body_load_field` reads the committed generation, evaluates its
effective force at the new physical target time, merges only accepted current-
root updates, and writes the shadow generation. Fresh loads remain at their
accepted magnitude for a configured persistence interval and then decay
linearly to zero. The initial uncalibrated runtime profile is 40 ms persistence
plus 160 ms decay.

The protective motor kernel now consumes the newly materialized private field
before publishing muscle excitation. A source tendon remains inhibited while
it owns an active peak cell and is released when the field expires. The
existing current-root host mask remains as a conservative redundant path.

The bounded temporal test uses a 1 ms persistence interval and 2 ms decay. Four
committed roots produce full, full, half, and absent field magnitudes. At every
root the private Metal cells equal the CPU temporal oracle exactly. Source
inhibition is present for the first three roots and absent on the fourth.
Abort, rejection, batched-versus-interactive, and retry tests remain active.

## Full 416-muscle regression

Two fresh full-body processes emitted byte-identical 4,574-byte JSON with the
same stdout SHA-256 as v0.7:

```text
5242ff4771f209c8c9193ca53760b9d91179a55224b13d1fb5216c9246b1c49f
```

Selected fields remain:

```json
{
  "status": "pass",
  "device": "Apple M4",
  "numanx_body_count": 157,
  "numanx_muscle_count": 416,
  "committed_body_load_body_identifiers": [34, 41],
  "committed_metal_body_load_body_identifiers": [34, 41],
  "committed_protective_selection_count": 37,
  "committed_protective_source_muscle_identifiers": [215],
  "localized_source_inhibition_excitation": 0,
  "rejected_candidate_replayed_exactly": true
}
```

## Evidence boundary

- Persistence and linear decay are deterministic runtime policy, not calibrated
  pain, damage, vulnerability, fatigue, healing, or receptor biology.
- Only one winning peak source is retained per body. This is not a dense body
  schema and does not preserve every simultaneous sub-peak load.
- Numeric Core bodies still lack source-authoritative anatomical names, body
  side, tissue class, receptor density, and innervation labels.
- Accepted updates are assembled in shared memory by the bounded host bridge;
  the temporal state transition and authoritative field generation are private
  Metal. This is not a fully device-generated sensor path.
- Tendon `215` has zero fixture neural gain and passive force. The full-body run
  proves source-command inhibition identity, not reduced physical load.
- Separate queues, staged diagnostics, CPU articulated integration, sequential
  cross-runtime publication, deliberate rejection, fixture gains, and non-
  performance boundaries from v0.7 still apply.

The revision was synced to the Mac mini. A Mini execution was intentionally not
launched while an unrelated 2,048-environment crow training supervisor and
512-environment policy evaluation owned that GPU.
