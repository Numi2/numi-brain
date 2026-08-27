# Mesoscale neural tissue model v0

This is the first executable NumiBrain tissue slice. It models a two-dimensional cortical sheet of coupled excitatory and inhibitory population sites. It is intentionally a mesoscale neural-field model, matching NumiBrain v1.0's standard population representation.

It is not:

- a neuron-by-neuron reconstruction;
- a calibrated model of a named cortical area or species;
- a mechanical constitutive model of brain parenchyma;
- a vascular, ionic, glial, or electrophysiological tissue model;
- evidence of biological prediction or clinical validity.

## State and dynamics

Each site stores normalized excitatory activity `E`, inhibitory activity `I`, and slow adaptation `A` in `[0, 1]`. A fourth FP32 lane is reserved so the CPU and Metal state ABI is one `float4` per site.

The update is a normalized Wilson-Cowan-family system:

\[
\tau_E \dot E = -E + \sigma_E(w_{EE}\bar E-w_{EI}I-g_AA+b_E+P),
\]

\[
\tau_I \dot I = -I + \sigma_I(w_{IE}\bar E-w_{II}\bar I+b_I+Q),
\]

\[
\tau_A \dot A = E-A.
\]

`E-bar` and `I-bar` blend the local site with its four clamped boundary neighbors. This finite stencil is the v0 numerical approximation to short-range lateral interaction. The implementation uses forward Euler with explicit clamping to the normalized state interval.

The uncalibrated v0 parameter set is:

| Quantity | Value |
| --- | ---: |
| Integration step | 1 ms |
| Excitatory time constant | 10 ms |
| Inhibitory time constant | 20 ms |
| Adaptation time constant | 200 ms |
| Excitatory self weight | 10 |
| Inhibitory-to-excitatory weight | 12 |
| Excitatory-to-inhibitory weight | 10 |
| Inhibitory self weight | 2 |
| Excitatory spatial mix | 0.75 |
| Inhibitory spatial mix | 0.15 |
| Adaptation strength | 2 |
| Excitatory bias | -2.5 |
| Inhibitory bias | -3.0 |
| Sigmoid gains | 1, 1 |

Grid coordinates are normalized, not millimetres. V0 therefore establishes neural-field computation and transactional execution, not a measured conduction velocity, cortical thickness, anatomical connectivity, or tissue scale.

Wilson and Cowan introduced coupled excitatory/inhibitory population dynamics in 1972 and extended the theory to two-dimensional cortical and thalamic sheets with recurrent lateral connections in 1973. Those papers establish the model class, not this repository's chosen parameters or biological calibration:

- H. R. Wilson and J. D. Cowan, “Excitatory and inhibitory interactions in localized populations of model neurons,” *Biophysical Journal* 12(1), 1972. PMID 4332108.
- H. R. Wilson and J. D. Cowan, “A mathematical theory of the functional dynamics of cortical and thalamic nervous tissue,” *Kybernetik* 13, 1973. DOI [10.1007/BF00288786](https://doi.org/10.1007/BF00288786).

## Numerical and transaction contract

- All state uses FP32 in v0.
- Physical simulation time controls stimulus timing and integration.
- Reflecting/clamped boundaries prevent wraparound coupling.
- A candidate substep reads the last accepted root-shadow state.
- Rejecting a candidate discards it without advancing time.
- Root abort preserves the committed grid exactly.
- Root commit publishes the final accepted shadow grid atomically.
- The v0 model is deterministic and contains no stochastic term. Counter-based stochastic channels will be introduced only with explicit keyed replay tests.

## Initial evidence gates

1. A no-stimulus resting sheet remains finite, bounded, and numerically stable.
2. During the stimulus response, a localized input produces measurable recruitment outside its footprint; later recovery is evaluated separately.
3. A rejected substep followed by retry equals one directly accepted substep.
4. Root abort leaves the committed state bit-exact.
5. Repeating an acceptance/rejection schedule produces the same state hash.
6. The Metal implementation agrees with the CPU oracle within a declared FP32 tolerance.
7. The production-sized run executes on a named Apple GPU through Metal 4 and reports GPU timing, grid size, state hash, and the exact revision.

Passing these gates proves an executable deterministic mesoscale tissue field. It does not prove the complete NumiBrain architecture or biological realism.

## Apple execution boundary

The Metal implementation compiles `NeuralTissue.metal` as Metal language version 4.0 with safe FP arithmetic and precise floating-point functions. It submits work through a Metal 4 command queue, reusable command buffer and allocator, compute encoder, argument table, explicit dispatch barriers, and a residency set.

Three state generations preserve transactionality: committed, root shadow, and candidate/scratch. Rejected candidates never become an input generation. Root abort changes only host-side generation ownership and leaves committed bytes untouched. V0 uses tracked shared buffers in Apple unified memory so the CPU can perform explicit evidence snapshots after GPU completion; no CPU access occurs between encoded substeps. Moving hot state to private heaps with an explicit inspection-copy boundary remains Phase 1 work.
