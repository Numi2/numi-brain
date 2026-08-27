# Versioned cohort dispatch v0.16

This document defines the first executable active-module cohort-token boundary for NumiBrain. Independent scheduler transactions are compiled into one deterministic, content-addressed dispatch plan, materialized into private Metal 4 buffers under one immutable parameter-version binding, and consumed through GPU-generated indirect dispatch arguments. One indirect consumer expands auditable work records; a second advances independent compact diagnostic state; a third advances an independent authoritative 10,752-scalar recurrent token generation for every active environment. It implements a bounded part of NumiBrain v1.0 Sections 3.7, 3.8, 7, 8, 45, 46, 47, 50, 51, 52, and 62.

The v0.16 cohort token program intentionally contains no long-range routes. A version-identified 32-slot route-history storage profile now exists for the next routed cohort boundary, but it is not activated until scheduler/event capacity is proved and per-agent routing generations are wired. The runtime does not yet perform GPU prefix-sum grouping or execute a complete multi-agent brain tick.

## Stable records

`NumiBrainABI` owns the records and field-wise fingerprints:

| Record | Bytes | Purpose |
| --- | ---: | --- |
| `NBCohortEnvironment` | 40 | Environment identifier, invocation span, source generation, committed time, and target time |
| `NBDispatchGroup` | 24 | One timestamp, clock class, module, and contiguous entry span |
| `NBDispatchEntry` | 16 | Independent environment identifier, invocation reasons, and interrupt mask |
| `NBDispatchPlanHeader` | 48 | Schedule, parameter, source-cohort, and complete-plan identities plus counts and format version |
| `NBDispatchPlanResult` | 32 | Materialized counts, typed status, plan identity, and parameter identity |
| `NBDispatchWorkItem` | 32 | Expanded timestamp, module, environment, reason, interrupt, and source-group work record |
| `NBDispatchCohortUniforms` | 32 | Bound plan and parameter identities plus environment, module, and state counts |
| `NBDispatchTokenUniforms` | 32 | Regional-program and schedule identities plus per-agent and total token-scalar counts |
| `NBRegionalModuleState` | 32 | Compact activation, integration, interrupt salience, phase, counters, and last-update time |

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

`materialize_dispatch_plan` receives private immutable header, group, entry, parameter-binding, and cohort-uniform buffers. Its two-dimensional grid maps:

```text
row    = timestamp / clock class / module group
column = active environment entry within that group
```

The kernel validates the bound format, counts, schedule identity, parameter identity, nonzero source-cohort identity, and group capacities. It copies canonical groups and entries into private region-major output buffers without atomics. The result remains private for a future indirect regional executor.

The materializer writes three private 12-byte `MTLDispatchThreadgroupsIndirectArguments` payloads. After a device barrier:

1. `consume_dispatch_plan` launches from the first GPU-generated count, finds the source group for each flattened entry, and writes one private `NBDispatchWorkItem` per active environment invocation.
2. `advance_cohort_regional_diagnostics` launches from the second GPU-generated count. One lane owns one active environment, copies its input generation to its output generation, walks canonical physical-time groups, finds only that environment's entries, and applies the same FP32 recurrence as `CPURegionalModuleOperator`.
3. `advance_cohort_regional_tokens_unrouted` launches one threadgroup per active environment from the third count. Its 64 lanes copy that agent's private token generation, walk canonical physical-time groups, compute candidates from a stable pre-update module vector, and publish to a separate private generation using the same gated FP32 recurrence and immutable factorized parameters as `CPURegionalTokenOperator`.

There is no count readback between materialization and any consumer. Diagnostic state is stored environment-major and then canonical module-major; token state is environment-major and then canonical regional-scalar-major. Agents never share recurrent values. Initial state may be supplied explicitly and is rejected if its ownership or shape drifts, any scalar is nonfinite, or a diagnostic last-update timestamp is newer than that environment/module's first invocation.

The current public materializer performs an explicit readback only after all four kernels complete to verify exact output and report evidence. It does not recompute the complete field-wise plan fingerprint inside Metal; the compiled C validator owns canonical fingerprint verification before upload, while Metal enforces that authenticated identity against the private parameter binding. The expanded work stream, output diagnostic state, and output token generation receive separate compiled field-wise fingerprints during post-completion verification.

Private byte counts are:

\[
B_{in}=224+24N_G+16N_E+4N_B+64N_M+32N_BN_M+32N_S+4N_BN_S,
\]

\[
B_{out}=80+24N_G+48N_E+40N_BN_M+8N_BN_S,
\]

where \(N_G\) is the number of dispatch groups, \(N_E\) is the number of active environment entries, \(N_B\) is the number of active environments, \(N_M\) is the number of modules, and \(N_S\) is the token-scalar count per environment. Output accounting includes the candidate-token scratch generation and per-module token last-update scratch. The 48 bytes after the result are aligned private storage for three 12-byte indirect argument payloads.

## Evidence gates

1. C++, Swift, and Metal agree on every dispatch, cohort-uniform, module, and regional-state record size.
2. Reordering source environments produces the same source and plan identities.
3. Interrupt-only groups contain only the affected environment, while shared periodic groups retain the complete active cohort.
4. Entry ordering, reason drift, span overflow, serialized fingerprint drift, duplicate identifiers, unversioned cohorts, and mixed versions fail closed.
5. Discarded source shadows change no committed scheduler state, and retry plans are exact.
6. Metal output groups and entries exactly equal the compiled CPU plan.
7. GPU-generated indirect threadgroup counts cover the exact flattened entry count without an intervening CPU readback.
8. Every indirectly consumed work item and the compiled work fingerprint exactly match the CPU plan.
9. Every active environment receives exactly one independently owned compact regional-state vector in canonical identifier order.
10. GPU regional floats match the CPU recurrence within the declared FP32 tolerance; counters and timestamps match exactly.
11. Environment-specific interrupts alter only their owning states, and the summed interrupt counters equal the source delivery count.
12. Repeated Metal materialization, indirect consumption, and regional-state advance are discrete-state exact and have the same state fingerprint.
13. Every active environment receives one independent token vector with the exact compiled scalar count and one GPU-generated threadgroup.
14. Token values match the unrouted CPU operator within the declared FP32 tolerance, while full-cohort ownership, shape, finiteness, and replay fingerprints are exact.
15. A stale parameter generation, routed program, malformed token input, and temporally invalid diagnostic input are rejected before upload.
16. The command-feedback interval is reported only as bounded telemetry, not throughput evidence.

Passing these gates establishes a deterministic versioned dispatch boundary, private Metal materialization, GPU-generated indirect work consumption, independent compact diagnostic state, and independent authoritative unrouted token state. It does not establish GPU-native plan construction, prefix sums, routed cohort execution, production throughput, or the complete 96-module graph. The current diagnostic lane and token threadgroup both scan canonical groups and perform a binary search for their environment. This transparent CPU-parity implementation is not the final compacted regional executor.
