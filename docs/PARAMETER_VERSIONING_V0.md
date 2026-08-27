# Immutable parameter versioning v0.12

This document defines the first executable shared slow-parameter publication boundary for NumiBrain. It implements the version identity and synchronization semantics required by NumiBrain v1.0 Sections 3.7, 3.8, 5, 40, 45, 47, 56, 58, and 62. It does not implement a learner, trained production weights, distributed publication, or persistent checkpoint files.

## Compiled manifest ABI

`NumiBrainABI` owns two padding-independent records:

| Record | Bytes | Purpose |
| --- | ---: | --- |
| `NBParameterComponent` | 32 | Canonical kind, element type, flags, element count, byte count, and content fingerprint |
| `NBParameterVersionBinding` | 64 | Manifest version, component count, monotonic sequence, version and parent identities, compatible schedule/shape identities, active regional-program identity, and total bytes |

Components are strictly ordered by unique kind. The compiled validator rejects empty manifests, unknown element encodings, zero counts or identities, byte-count overflow, noncanonical order, invalid root/successor parent rules, regional-component identity drift, and a recomputed version-fingerprint mismatch. Fingerprinting uses FNV-1a over explicit little-endian fields and never hashes C or Swift padding.

The current runtime-foundation manifest contains:

- 17 FP32 tissue-dynamics values, excluding state, stimulus, time, and random counters;
- the immutable regional operator parameter and route records.

The schedule fingerprint and regional shape fingerprint are compatibility identities. The regional content fingerprint changes when learned parameter bits or route gains change. A successor can therefore publish new values without pretending a changed token or route layout is compatible.

## Publication boundary

`BrainParameterRegistry` holds one immutable current version. `beginCohort` leases that exact fingerprint to a rollout cohort. Publication is rejected until all leases end. A candidate must be the direct monotonic successor of the current version, name the current fingerprint as parent, and retain the same schedule and regional shape.

The registry is thread-safe and fail-closed for duplicate cohorts, stale requested versions, unknown leases, publication during rollout, skipped sequences, stale parents, and shape drift. Per-agent recurrent state, clocks, memories, and random counters are not components of the shared manifest.

## Transaction and GPU binding

CPU scheduler snapshots and transactions carry the parameter-version fingerprint. Checkpoint restoration, transaction commit, and cohort compaction reject mixed identities. The stable snapshot hash includes the version so a replay using different weights cannot compare equal.

`MetalTissueRuntime` validates a supplied manifest against its tissue parameters, schedule, regional shape, and regional content before allocation or dispatch. It uploads one 64-byte binding to private GPU memory. Every root places the same version and schedule fingerprints in the scheduler uniforms. `schedule_due_modules` rejects a mismatch with a typed status; `advance_due_regional_tokens` separately rejects regional-program drift. The runtime stores the version as an immutable `let`, so a pending or committed root cannot swap shared parameters in place.

This establishes content identity and rollout isolation for the current one-agent Metal path. It does not yet provide a learner process, atomic multi-runtime parameter-buffer replacement, remote artifact signing, persistent checkpoint serialization, or a large-cohort synchronization service.

## Evidence gates

1. C++, Swift, and Metal agree on the 32-byte component, 64-byte binding, and 56-byte scheduler-uniform layouts.
2. The compiled validator recomputes the canonical manifest fingerprint and rejects identity drift.
3. Reordered components canonicalize to the same version; duplicate component kinds fail.
4. Serialized version identity is recomputed and tampering fails closed.
5. Regional parameter changes alter content identity while preserving structural shape identity.
6. A publication attempt during an active cohort fails; the direct successor publishes after the synchronization boundary.
7. Stale requested versions, leases, parents, sequences, schedules, and shapes fail.
8. CPU checkpoint restore and cohort compaction reject a different parameter fingerprint.
9. Metal runtime construction rejects a manifest whose tissue or regional content differs from live immutable buffers.
10. Metal scheduler inspection reports the same nonzero version fingerprint as its CPU oracle and returns valid typed status.
11. Replay, retry, and abort retain one immutable version because no runtime mutation API exists.

Passing these gates establishes versioned immutable rollout parameters for the executable foundation slice. It does not establish training quality, biological calibration, or Phase 1 completion.
