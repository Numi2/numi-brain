# NumanX exact outbound-v2 contract

This document fixes NumiBrain's independent C/C++ interpretation of the exact
request-v3 authority and the native HumanMatter/sensor/publication response.
It is an additive wire contract. It does not activate physical execution,
publish a sensor packet, or reinterpret any v1/v2 Brain transaction record.

## Ownership and causal chain

NumiBrain produces and validates the exact root, substep, motor candidate,
motor output, motor profile, ready gate, Brain program, fast program, decision
gate, accepted-Brain timestamp, and Brain generation. It folds those immutable
identities into `NBNumanXExactInboundAuthorityV2`.

The native Human/Matter owner produces the accepted state proof, NXAT accepted
physics token, exact sensor timing and channels, sensor packet, and publication
receipt. Brain validates those records independently before they can be treated
as one causal response:

```text
request-v3 root/substep
  -> candidate/output/profile + ready gate/programs
  -> exact inbound authority
  -> HumanMatter accepted proof + NXAT token
  -> exact timing + canonical sensor channels
  -> exact sensor packet
  -> exact joint publication receipt
```

The authority's `accepted_brain_timestamp_nanoseconds` must equal the candidate,
output, ready-gate, and sensor-capture timestamp. Its `brain_generation` must
equal the candidate, output, ready-gate, packet, and publication generation.
This prevents a self-consistent sensor envelope from relabeling which accepted
Brain state caused it.

## Stable layouts and hash domains

All hashes are FNV-1a-64 over explicitly listed little-endian integer fields.
Each outbound record begins with a distinct 32-bit domain word. Host padding is
never hashed. The only process-local values included are the sensor channel's
borrowed Metal-buffer pointer identity and declared GPU slice.

| Record | Bytes | Terminal fingerprint offset | Domain | Canonical golden |
| --- | ---: | ---: | ---: | ---: |
| inbound authority | 112 | 104 | `NXIA` `0x4e584941` | `0x67f243f667d0323d` |
| physics-state identity | n/a | n/a | `NXPS` `0x4e585053` | `0x18c6c3b27fbfde9b` |
| accepted-state proof | 160 | 152 | `NXAP` `0x4e584150` | `0xb9311ace7f609680` |
| accepted-physics token | 64 | 56 | `NXAT` `0x4e584154` | `0x49daecb782375620` |
| sensor timing | 56 | 48 | `NXTM` `0x4e58544d` | `0x5cf5d8e731b234a0` |
| first sensor channel | 144 | 136 | `NXCH` `0x4e584348` | `0x29c4e62cfb2378e8` |
| canonical channel set | n/a | n/a | `NXCS` `0x4e584353` | `0xc5e815775b80108f` |
| sensor packet | 128 | 120 | `NXSP` `0x4e585350` | `0xa2a401361deb9f57` |
| publication | 72 | 64 | `NXPP` `0x4e585050` | `0x7badb8d7c8eea93e` |

The same fixture retains the previously published Brain producer goldens:

- root `0x986252871c867014`;
- substep `0x339760742e9d5b13`;
- candidate `0xd545ffb84702f6cc`;
- motor output `0xd2997dd67ccf83f4`;
- ready gate `0x7a7c4daa7709eef0`.

The native NXAT token has a separate domain and API from the existing
`NBAcceptedPhysicsStateTokenV2`. Their 64-byte shapes are compatible, but their
fingerprints are intentionally not interchangeable.

## Exact time and sensor descriptor rules

Every record is clock domain 2 with a one-nanosecond quantum. Timestamps and
durations are never rounded through microseconds. Delivery must be later than
capture, latency must equal their checked difference, and the native accepted
timestamp must equal sensor delivery.

Channels are strictly increasing by modality. Each values/validity range binds:

- ABI and byte size;
- process-local Metal-buffer identity;
- GPU slice start;
- buffer-relative byte offset and byte count;
- element type and element width.

`gpu_address` denotes the slice start, while `byte_offset` is relative to the
borrowed buffer. Validation checks both address and offset end calculations for
overflow. Slices in one buffer must imply the same base address and have
disjoint offset intervals. Slices from distinct buffers must have disjoint GPU
address intervals. All values and validity slices are pairwise disjoint across
the complete channel set.

## Activation boundary

`mrnx_aggregate_snapshot_v5` is mirrored at 2,392 bytes so C, C++, and Swift can
check the future native publication layout. No Brain code loads a v5 publication
symbol or calls an exact begin function. Native request-v3 must continue to end
at failure stage 900 with no physical or publication touch until the complete
family is executable, persistent-state handling is exact, and owner evidence is
qualified. These CPU contract tests are interoperability evidence only; they
are not an accepted physical root or Metal performance evidence.
