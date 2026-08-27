# Regional recurrent token operator v0.1

This document defines the first executable regional `H_r` state in NumiBrain. It replaces the former compact population trace as the authoritative neural regional state while retaining that 32-byte per-module record as scheduler diagnostics and evidence metadata.

It implements a bounded eight-module vertical slice of NumiBrain v1.0 Section 8. It is not the complete 96-module graph, a learned production parameter set, or a claim of biological calibration.

## Compiled program

`NumiBrainABI` compiles and validates four standard-layout records:

| Record | Bytes | Purpose |
| --- | ---: | --- |
| `NBRegionalTokenLayout` | 32 | Region-major token shape, scalar offset, parameter offset, and incoming-route span |
| `NBRegionalRoute` | 24 | Sparse sender, receiver, sender-token, gain, flags, and route delay |
| `NBRegionalTokenParameters` | 32 | Immutable factorized candidate and gate coefficients for one token scalar |
| `NBRegionalProgramHeader` | 32 | Module, scalar, route, and parameter counts plus program fingerprint |

The validator requires layouts to match the canonical module descriptors, scalar and route spans to be contiguous, route endpoints and sender tokens to exist, parameters and gains to be finite, and the parameter count to equal the token-state scalar count. Version 0 rejects nonzero route delays because regional delay history is not implemented yet. It never silently executes an undelayed substitute.

The program fingerprint is FNV-1a over explicit little-endian layout and route fields plus the exact FP32 parameter bit patterns. Padding is excluded. The program is immutable for the lifetime of a rollout runtime.

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

The fixed v0.1 route graph contains seven compiled edges:

```text
37 -> 25
12 -> 26  emergency
25 -> 77
95 -> 83
26 -> 95  emergency
83 -> 95
90 -> 95
```

These routes exercise sparse causal message ownership. They are synthetic runtime-foundation topology, not anatomical connectivity.

## Numerical operator

For each due receiver token scalar `h`, the operator reads the common pre-timestamp regional state and computes:

\[
i = w_L \bar h_{token} + w_R \sum_{j\rightarrow r} g_{jr}h_{j,f} + w_D d + b,
\]

\[
\widetilde h = \tanh(w_H h + i),
\qquad
z = \sigma(b_z + w_{zH}h + w_{zI}(r+d)),
\]

\[
h' = h + \left(1-e^{-\Delta t/\tau_r}\right)z(\widetilde h-h).
\]

`d` contains periodic and receptor-derived interrupt drive. `bar h_token` is the local token mean. A route maps the receiver feature to the sender token feature modulo the sender dimension. Every scalar has explicit immutable FP32 coefficients; the current deterministic initializer is an executable parameter fixture, not trained knowledge.

All modules due at one physical timestamp read the same pre-timestamp state. Their candidates publish only after a device-wide threadgroup barrier. A cyclic route therefore cannot observe a peer's partially published state. The CPU oracle performs the same timestamp grouping.

## Apple GPU and transaction ownership

`advance_due_regional_tokens` runs after `schedule_due_modules` on the same Metal 4 compute encoder. One bounded threadgroup owns the current agent and strides across its 10,752 token scalars. It consumes the private scheduler result and due list without reading the invocation count on the CPU, gathers only the compiled incoming route spans, and writes the noncommitted token and diagnostic generations.

Root commit publishes tissue, relay history, scheduler clocks, token state, and diagnostics together by swapping generation ownership. Abort swaps none. A rejected physical candidate does not dispatch the root scheduler or regional operator until accepted simulated time is known. Retry, replay, and 20 ms versus split control-window execution produce the same committed token values.

FP32 is used for storage and accumulation in v0.1 to pin CPU/Metal numerical semantics. BF16 or FP16 storage with FP32 accumulation remains a future measured optimization.

## Evidence boundary

The implementation and tests establish:

- C++/Swift/Metal ABI size agreement;
- compiled layout, parameter, route, and program identities;
- 10,752-scalar GPU-resident recurrent state;
- scheduler-driven multi-rate updates;
- timestamp-synchronous sparse route gathering;
- CPU/Metal FP32 parity;
- a Metal route-ablation effect isolated from tissue and scheduler diagnostics;
- exact retry, abort, replay, and control-window chunking behavior.

They do not establish dynamic route scoring or top-k selection, conduction-delay history, dense tiled regional matrices, fast-plastic bases, active-environment cohort compaction, role-specific learned models, training, NumanX coupling, calibrated neural dynamics, or production throughput.
