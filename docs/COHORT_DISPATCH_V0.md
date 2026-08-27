# Versioned cohort dispatch v0.13

This document defines the first executable active-module cohort boundary for NumiBrain. Independent scheduler transactions are compiled into one deterministic, content-addressed dispatch plan and materialized into private Metal 4 buffers under one immutable parameter-version binding. It implements a bounded part of NumiBrain v1.0 Sections 3.7, 3.8, 7, 45, 47, 50, 51, 52, and 62.

It does not yet perform GPU prefix-sum grouping, indirect regional execution, per-agent recurrent-state gathering, or a complete multi-agent brain tick.

## Stable records

`NumiBrainABI` owns the records and field-wise fingerprints:

| Record | Bytes | Purpose |
| --- | ---: | --- |
| `NBCohortEnvironment` | 40 | Environment identifier, invocation span, source generation, committed time, and target time |
| `NBDispatchGroup` | 24 | One timestamp, clock class, module, and contiguous entry span |
| `NBDispatchEntry` | 16 | Independent environment identifier, invocation reasons, and interrupt mask |
| `NBDispatchPlanHeader` | 48 | Schedule, parameter, source-cohort, and complete-plan identities plus counts and format version |
| `NBDispatchPlanResult` | 32 | Materialized counts, typed status, plan identity, and parameter identity |

The records are standard-layout C values mirrored explicitly in Metal. Compile-time assertions and Swift tests require exact size agreement. Fingerprints mix explicit little-endian fields and never hash struct padding. They are deterministic content identities, not cryptographic signatures.

## Canonical compilation

Every source environment retains its own scheduler transaction. `BrainDispatchPlan` first sorts unique environment identifiers, requires one nonzero schedule fingerprint and one nonzero immutable parameter fingerprint, and fingerprints the source transaction boundaries. It then groups due invocations by:

1. physical timestamp;
2. clock class;
3. module identifier;
4. environment identifier inside the group.

Each group owns one contiguous span in the flattened entry array. Emergency interruptions remain isolated to the environments that received them; periodic work shared by a cohort occupies the same group without merging agent state.

The compiled validator fails closed on null spans, unsupported format or flags, missing identities, noncanonical group order, empty or discontinuous entry spans, duplicate or unordered environments, invalid reason/interrupt combinations, and fingerprint drift. Decoding a serialized Swift plan recomputes this validation and rejects tampering.

## Transaction and version identity

The source-cohort fingerprint includes every environment's base generation, committed physical time, target physical time, and invocation span. The complete plan identity additionally includes the shared schedule and parameter fingerprints plus every group and entry. A discarded scheduler shadow leaves committed state unchanged; recompiling the same retry produces the same plan. Committing the source transaction changes the next cohort identity.

A plan cannot mix parameter generations. `MetalDispatchPlanRuntime` validates the full C parameter manifest and requires the plan's schedule and parameter identities to match before allocating or uploading work. A stale successor is rejected before Metal dispatch.

## Metal materialization

`materialize_dispatch_plan` receives private immutable header, group, entry, and parameter-binding buffers. Its two-dimensional grid maps:

```text
row    = timestamp / clock class / module group
column = active environment entry within that group
```

The kernel validates the bound format, counts, schedule identity, parameter identity, nonzero source-cohort identity, and group capacities. It copies canonical groups and entries into private region-major output buffers without atomics. The result remains private for a future indirect regional executor.

The current public materializer performs an explicit readback only after command completion to verify exact output and report evidence. It does not recompute the complete field-wise plan fingerprint inside Metal; the compiled C validator owns canonical fingerprint verification before upload, while Metal enforces that authenticated identity against the private parameter binding.

Private byte counts are:

\[
B_{in}=48+24N_G+16N_E+64,
\]

\[
B_{out}=24N_G+16N_E+32,
\]

where \(N_G\) is the number of dispatch groups and \(N_E\) is the number of active environment entries.

## Evidence gates

1. C++, Swift, and Metal agree on all five dispatch-record sizes.
2. Reordering source environments produces the same source and plan identities.
3. Interrupt-only groups contain only the affected environment, while shared periodic groups retain the complete active cohort.
4. Entry ordering, reason drift, span overflow, serialized fingerprint drift, duplicate identifiers, unversioned cohorts, and mixed versions fail closed.
5. Discarded source shadows change no committed scheduler state, and retry plans are exact.
6. Metal output groups and entries exactly equal the compiled CPU plan.
7. Repeated Metal materialization is discrete-state exact.
8. A stale parameter generation is rejected before upload.
9. The command-feedback interval is reported only as bounded telemetry, not throughput evidence.

Passing these gates establishes a deterministic versioned dispatch boundary and private Metal materialization. It does not establish GPU-native plan construction, prefix sums, indirect execution, cohort neural-state updates, production throughput, or the complete 96-module graph.
