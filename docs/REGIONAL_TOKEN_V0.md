# Regional recurrent token operator v0.6

This document defines the first executable regional `H_r` state in NumiBrain. It replaces the former compact population trace as the authoritative neural regional state while retaining that 32-byte per-module record as scheduler diagnostics and evidence metadata.

It implements a bounded eight-module vertical slice of NumiBrain v1.0 Section 8. It is not the complete 96-module graph, a learned production parameter set, or a claim of biological calibration.

## Compiled program

`NumiBrainABI` compiles and validates four standard-layout records:

| Record | Bytes | Purpose |
| --- | ---: | --- |
| `NBRegionalTokenLayout` | 40 | Region-major token shape, scalar/parameter offsets, incoming-route span, dense-weight span, and normal-route budget |
| `NBRegionalRoute` | 24 | Sparse sender, receiver, sender-token, gain, flags, delay, and compiled history layout |
| `NBRegionalTokenParameters` | 32 | Immutable per-scalar candidate and gate coefficients paired with shared dense-local weights |
| `NBRegionalProgramHeader` | 56 | Versioned program counts, dense-parameter count, fingerprint, route-history capacity, persistence interval, and score constants |
| `NBRegionalRouteHistoryState` | 16 | Per-route ring cursor, valid count, and latest publication time |
| `NBRegionalRouteRuntimeState` | 32 | Per-agent score, strength, active flag, selection count, last-selected time, and switch count |

The validator requires layouts to match the canonical module descriptors, scalar, route, and dense-weight spans to be contiguous, each dense span to be exactly `tokenDimension²`, every normal-route budget to fit the receiver's non-emergency candidate count, route endpoints and sender tokens to exist, parameters and gains to be finite, history offsets and message dimensions to be canonical for the compiled capacity, route delays to lie in `0...5000` microseconds, history capacity to lie in `1...512`, the per-scalar parameter count to equal the token-state scalar count, and the program dense count to equal the compiled dense spans. Duplicate route identities, nonzero reserved fields, and budget drift are rejected. A delayed route never silently executes as an undelayed substitute.

The program fingerprint is FNV-1a over explicit little-endian layout, dense-shape, and route-budget fields, program version, history capacity, delay and persistence bounds, score constants, route fields, and exact per-scalar FP32 parameter bit patterns. Padding is excluded. Dense weight bytes are content-addressed by the immutable shared-parameter artifact and parameter-version manifest. The program and shared artifact are immutable for the lifetime of a rollout runtime.

A second compiled shape fingerprint excludes learned FP32 parameter bits and route gains while retaining layout, route identity, delay, history, and budget structure. Parameter publication requires this shape identity to remain compatible while allowing the content fingerprint to change. The active content fingerprint is included in the immutable parameter version and checked again by the Metal regional kernel.

## Executable reference state

The runtime-foundation subset retains the token shapes already carried by the module descriptors:

| Module | Shape | Scalars |
| ---: | ---: | ---: |
| 12 | 4 x 64 | 256 |
| 25 | 16 x 256 | 4,096 |
| 26 | 8 x 64 | 512 |
| 37 | 16 x 128 | 2,048 |
| 77 | 8 x 256 | 2,048 |
| 83 | 8 x 128 | 1,024 |
| 90 | 4 x 64 | 256 |
| 95 | 8 x 64 | 512 |
| Total | region-major FP32 | 10,752 |

Two private 43,008-byte token generations hold committed and shadow state. A separate private candidate buffer supports synchronous timestamp publication. Two private 256-byte diagnostic generations retain update counts, interrupt counts, phase, salience, and last-update time.

The eight compiled dense-local matrices contain 180,224 FP32 values (720,896 bytes): one `tokenDimension x tokenDimension` matrix per module, shared across that module's tokens. The runtime-foundation artifact initializes deterministic small zero-mean weights; they are executable untrained parameters, not biological or learned knowledge.

History capacity is part of both the content and shape fingerprints. The one-agent reference profile retains 512 timestamp slots and 512 copies of each selected sender token. Across the reference graph this is 393,216 FP32 history values. Its two transactional generations use 224 bytes of route metadata, 57,344 bytes of timestamps, and 3,145,728 bytes of message values.

The cohort storage profile compiles 32 slots per route. The same seven routes then require 24,576 FP32 values per agent: 112 bytes of metadata, 1,792 bytes of timestamps, and 98,304 bytes of values per generation. This is a program-shape change with a different immutable parameter identity, not an allocator-side truncation. Runtime capacity validation must prove that the selected window preserves every message that can still satisfy a compiled conduction delay.

Two private routing-state generations add 448 bytes for the seven candidate routes. One private 28-byte selected-route-index span and one private 32-byte per-module selected-count span compact the live gather set at each due timestamp. The scratch spans are derived state; the double-buffered route-runtime records are authoritative per-agent transaction state.

The candidate v0.2 route graph contains seven compiled edges:

```text
37 -2.00 ms-> 25
12 -0.00 ms-> 26  emergency
25 -5.00 ms-> 77
95 -1.00 ms-> 83
26 -0.00 ms-> 95  emergency
83 -0.25 ms-> 95
90 -0.25 ms-> 95
```

These routes exercise sparse causal message ownership and selection. They are synthetic runtime-foundation topology, not anatomical connectivity. Emergency edges never consume the receiver's normal-route budget. The reference program defaults each receiver with normal candidates to a budget of one.

## Deterministic routing policy

For candidate route `j -> r`, the deployment score uses receiver token zero as the query and the route's causal message as the key:

\[
s_{jr}=\frac{q_r^\mathsf{T}m_{jr}}{\sqrt{d_r}}
+0.125\,\operatorname{mean}|m_{jr}|
+0.05\,\mathbf 1[\text{previously active}]
-0.1\,\mathbf 1[\text{inactive}].
\]

A zero-delay message reads the common pre-timestamp sender state. A delayed message reads the newest published sender token no later than the conduction boundary. Undelivered history therefore scores as a zero message rather than observing future state.

Selection is deterministic:

1. append every emergency route in canonical route order;
2. retain previously active normal routes selected less than 2,000 microseconds ago, up to the normal budget;
3. fill the remaining normal budget with scores at least `0.01`, descending by score and breaking exact ties by canonical route index;
4. apply a stable softmax with temperature `0.25` over all selected emergency and normal scores;
5. compact the selected route indices into the receiver's compiled incoming span.

Every selected route increments its saturating selection counter and updates its last-selected timestamp. Every active/inactive transition increments a saturating switch counter. These values are independent per-agent state, not shared weights. Emergency routes remain selected even when their score is lower than normal candidates.

## Numerical operator

For each due receiver token scalar `h`, the operator reads the common pre-timestamp regional state and computes:

\[
p_f = \frac{(W_r h_{token})_f}{\sqrt{d_r}},
\qquad
i = w_L p_f + w_R \sum_{j\in\mathcal A_r} a_{jr}g_{jr}h_{j,f} + w_D d + b,
\]

\[
\widetilde h = \tanh(w_H h + i),
\qquad
z = \sigma(b_z + w_{zH}h + w_{zI}(r+d)),
\]

\[
h' = h + \left(1-e^{-\Delta t/\tau_r}\right)z(\widetilde h-h).
\]

`d` contains periodic and receptor-derived interrupt drive. `W_r` is the module's immutable dense-local matrix from the shared `.regionalDense` parameter component. A route maps the receiver feature to the sender token feature modulo the sender dimension. Every scalar also has explicit immutable FP32 residual and gate coefficients; the current deterministic initializer is an executable parameter fixture, not trained knowledge.

Here `A_r` is the compact selected set and `a_jr` is its normalized route strength. All modules due at one physical timestamp read the same pre-timestamp state. A zero-delay route reads its sender from that common state. A delayed route reads the newest timestamped sender message no later than `t - delay`; if no such publication exists, its routed contribution is zero. Candidates publish only after a device-wide threadgroup barrier, after which due sender messages are appended to their route rings. A cyclic route therefore cannot observe a peer's partially published state. The CPU oracle performs the same timestamp grouping, scoring, selection, normalization, and delayed lookup.

## Apple GPU and transaction ownership

`advance_due_regional_tokens` runs after `schedule_due_modules` on the same Metal 4 compute encoder. One bounded threadgroup owns the current agent and strides across its 10,752 token scalars. It consumes the private scheduler result and due list without reading the invocation count on the CPU, resolves delayed ring slots, scores candidates, compacts selected route indices, gathers only that compact set, and writes the noncommitted token, diagnostic, route-history, and routing-state generations.

Root commit publishes tissue, relay history, scheduler clocks, token state, diagnostics, route history, and routing state together by swapping generation ownership. Abort swaps none. A rejected physical candidate does not dispatch the root scheduler or regional operator until accepted simulated time is known. Retry, replay, and 20 ms versus split control-window execution produce the same committed token values, route history, and route selections.

The one-agent runtime derives a conservative publication bound from configured event capacity, accepted timestep, and maximum compiled route delay. The cohort runtime performs a tighter per-agent proof over the actual root dispatch: it reconstructs the committed active timestamps, simulates bounded and unbounded publication histories in timestamp order, checks every delayed receiver read before same-timestamp sender publication, and rejects before upload if the selected ring would change the resolved timestamp. This makes ring overwrite a checked transaction error rather than silent causal corruption. The one-agent tissue profile compiles 512 slots; the routed cohort profile compiles 32 slots and activates only after this proof passes.

FP32 is used for storage and accumulation in v0.3 to pin CPU/Metal numerical semantics. BF16 or FP16 storage with FP32 accumulation remains a future measured optimization.

## Evidence boundary

The implementation and tests establish:

- C++/Swift/Metal ABI size agreement;
- compiled layout, parameter, route, and program identities;
- compiled history capacity in both content and shape identities, with exact default-512 fingerprint compatibility;
- rejection of zero, over-maximum, and history-layout-mismatched capacities;
- 10,752-scalar GPU-resident recurrent state;
- 180,224 executable shared dense-local FP32 weights with exact CPU/Metal parity;
- scheduler-driven multi-rate updates;
- timestamp-synchronous sparse route gathering;
- causal 0-5 ms per-route message delivery through persistent GPU rings;
- content-dependent deterministic normal-route top-k selection;
- permanent emergency-route bypass, minimum persistence, and normalized selected strengths;
- compact selected-route gather spans rather than full candidate-route scalar scans;
- CPU/Metal FP32 parity;
- exact route-history and routing-state metadata/timestamp parity plus FP32 value, score, and strength parity;
- a Metal route-ablation effect isolated from tissue and scheduler diagnostics;
- exact retry, abort, replay, and control-window chunking behavior for route history and routing state.

They do not establish learned dense weights or context-conditioned score projections, capacity balancing, differentiable training routing, tiled dense-kernel throughput, nonzero fast-plastic basis behavior, role-specific learned models, training, NumanX coupling, calibrated neural dynamics, or production throughput.
