# Mesoscale neural tissue model v0.4

This is the first executable NumiBrain tissue slice. It models a two-dimensional cortical sheet of coupled excitatory and inhibitory population sites. It is intentionally a mesoscale neural-field model, matching NumiBrain v1.0's standard population representation.

It is not:

- a neuron-by-neuron reconstruction;
- a calibrated model of a named cortical area or species;
- a mechanical constitutive model of brain parenchyma;
- a vascular, ionic, glial, or electrophysiological tissue model;
- evidence of biological prediction or clinical validity.

## State and dynamics

Each site stores normalized excitatory activity `E`, inhibitory activity `I`, slow adaptation `A`, and an axonal relay state `R` in `[0, 1]`. The CPU and Metal state ABI remains one `float4` per site.

An immutable second `float4` field stores the tissue structure at every site:

\[
S=(s_E,s_I,s_C,V),
\]

where `sE` and `sI` scale local excitatory and inhibitory response, `sC` scales outgoing short-range coupling, and viability `V` lies in `[0, 1]`. The default layered profile is a deterministic synthetic test morphology with four depth strata and slight lateral modulation. It is not a histological fit to a named cortical area.

An immutable `uint8` field stores outgoing local-conduction delay class `d_j` for every source site. V0.4 supports integer delays from 0 through 31 accepted integration steps. The synthetic layered profile assigns 1–4 ms classes to its four strata; these classes test causal delay handling and do not encode measured axon length, myelination, or conduction velocity.

Long-range connections use a destination-major compressed sparse row graph. Every edge `e=(j,i,w_e,d_e)` names its source and destination sites, an FP32 weight, and its own 0–31 step delay. The default bilateral profile mirrors two synthetic bands across the sheet with one incoming edge per participating site. It exists to exercise disconnected spatial recruitment, sparse GPU execution, and delayed transaction rollback; it is not a corpus callosum model or anatomical connectome.

Runtime input uses an immutable canonical schedule of at most 64 receptor-derived events. Each event stores a unique identifier, normalized center and radius, half-open physical-time interval, excitatory and inhibitory drive, bounded noise amplitude, and flags. The schedule is neural input after receptor transduction; it is not raw or privileged NumanX state. Future records may reside in the immutable buffer, but their values are gated from tissue computation until their timestamps are due.

The update is a normalized Wilson-Cowan-family system:

\[
\tau_E \dot E = -E + V\,\sigma_E\!\left(s_E(w_{EE}\bar R-w_{EI}I-g_AA+b_E+P)+g_LL_i\right),
\]

\[
\tau_I \dot I = -I + V\,\sigma_I\!\left(s_I(w_{IE}\bar R-w_{II}\bar I+b_I+Q)\right),
\]

\[
\tau_A \dot A = E-A.
\]

\[
\tau_R \dot R = E-R.
\]

The delayed excitatory stencil is

\[
\bar R_i(t)=\frac{1}{4}\sum_{j\in\mathcal N(i)}s_{C,j}V_jR_j(t-d_j\Delta t).
\]

The sparse long-range drive is

\[
L_i(t)=\sum_{e:j\rightarrow i}w_eR_j(t-d_e\Delta t).
\]

For event set `E`, the external drives are

\[
P_i(t)=\sum_{e\in E(t,i)}\left(p_e+a_e\xi(K_{e,i,t,0})\right),
\qquad
Q_i(t)=\sum_{e\in E(t,i)}\left(q_e+a_e\xi(K_{e,i,t,1})\right),
\]

where `E(t,i)` includes only events whose half-open time interval and spatial footprint contain the current accepted time and site. The bounded sample `xi` lies in `[-1,1)` and uses the upper 24 bits of a shared UInt32 counter hash. Its key is

\[
K=(\text{seed},\text{environment},\text{episode},\text{module},
\text{accepted step},\text{event},\text{site},\text{sample lane}).
\]

There is no mutable random-generator state. A rejected candidate addresses the same key on retry; only accepting simulated time advances the step component.

`R-bar` and `I-bar` blend the local site with its four clamped boundary neighbors. Neighbor contributions are weighted by their outgoing coupling and viability. The relay time constant and explicit history delay model different effects: `R` is local axonal filtering, while `d` selects a committed past relay generation. Sparse projections read the same authoritative history with their edge-specific delay, so local and long-range paths share one causal transaction boundary. The finite stencil is the v0.4 numerical approximation to short-range lateral interaction. The implementation uses forward Euler with explicit clamping to the normalized state interval.

A circular lesion lowers `V` inside its normalized footprint. With `V = 0`, a site initializes and remains exactly silent, and its outgoing contribution is zero. Partial viability is an abstract response/transmission attenuation coefficient, not a tissue-damage law.

The uncalibrated v0 parameter set is:

| Quantity | Value |
| --- | ---: |
| Integration step | 1 ms |
| Excitatory time constant | 10 ms |
| Inhibitory time constant | 20 ms |
| Adaptation time constant | 200 ms |
| Axonal relay time constant | 8 ms |
| Excitatory self weight | 10 |
| Inhibitory-to-excitatory weight | 12 |
| Excitatory-to-inhibitory weight | 10 |
| Inhibitory self weight | 2 |
| Excitatory spatial mix | 0.75 |
| Inhibitory spatial mix | 0.15 |
| Adaptation strength | 2 |
| Long-range projection gain | 1 |
| Excitatory bias | -2.5 |
| Inhibitory bias | -3.0 |
| Sigmoid gains | 1, 1 |

Grid coordinates are normalized, not millimetres. Event noise is a bounded numerical receptor-drive perturbation, not a fit to receptor or neural noise statistics. V0.4 therefore establishes causal noisy-event, delayed structured neural-field computation and transactional sparse execution, not measured sensing, conduction velocity, cortical thickness, anatomical connectivity, lesion pathology, or tissue scale.

Wilson and Cowan introduced coupled excitatory/inhibitory population dynamics in 1972 and extended the theory to two-dimensional cortical and thalamic sheets with recurrent lateral connections in 1973. Those papers establish the model class, not this repository's chosen parameters or biological calibration:

- H. R. Wilson and J. D. Cowan, “Excitatory and inhibitory interactions in localized populations of model neurons,” *Biophysical Journal* 12(1), 1972. PMID 4332108.
- H. R. Wilson and J. D. Cowan, “A mathematical theory of the functional dynamics of cortical and thalamic nervous tissue,” *Kybernetik* 13, 1973. DOI [10.1007/BF00288786](https://doi.org/10.1007/BF00288786).

## Numerical and transaction contract

- All state uses FP32 in v0.
- Physical simulation time controls event timing and integration.
- Reflecting/clamped boundaries prevent wraparound coupling.
- A candidate substep reads the last accepted root-shadow state.
- Rejecting a candidate discards it without advancing time.
- Root abort preserves the committed grid exactly.
- Root commit publishes the final accepted shadow grid atomically.
- Local and long-range delayed reads use only accepted root-shadow or committed relay generations.
- Counter-random samples are pure functions of committed identity and accepted step; retry, replay, and control-interval chunking do not change them.
- Different configured seeds produce different noisy trajectories without changing event timing or topology.

## Initial evidence gates

1. A no-stimulus resting sheet remains finite, bounded, and numerically stable.
2. During the stimulus response, a localized input produces measurable recruitment outside its footprint; later recovery is evaluated separately.
3. A rejected substep followed by retry equals one directly accepted substep.
4. Root abort leaves the committed state bit-exact.
5. Repeating an acceptance/rejection schedule produces the same state hash.
6. The Metal implementation agrees with the CPU oracle within a declared FP32 tolerance.
7. The production-sized run executes on a named Apple GPU through Metal 4 and reports GPU timing, grid size, state hash, and the exact revision.
8. Heterogeneous structure and lesions produce deterministic structure hashes and preserve CPU/Metal parity.
9. Zero-viability sites remain exactly silent and an axonal relay lags local excitation.
10. Explicit delay classes postpone lateral recruitment relative to the zero-delay control.
11. Abort and rejected retry preserve delayed future state, not only the immediate state grid.
12. A Metal root that would overwrite abort-authoritative relay history rejects before dispatch.
13. A sparse edge recruits a distant site beyond the local stencil only after its configured delay.
14. Sparse delayed execution agrees between CPU and Metal within the declared tolerance.
15. Retry and abort remain exact after advancing beyond the largest local or projection delay.
16. Future receptor events have no effect before their timestamps.
17. Golden counter vectors match the shared CPU and Metal random ABI.
18. Different seeds produce different noisy trajectories while identical keys replay exactly.
19. Rejected noisy candidates reuse their samples and root abort publishes no stochastic history.
20. Multi-event noisy execution agrees between CPU and Metal within the declared tolerance.

Passing these gates proves an executable replay-deterministic mesoscale tissue field with keyed stochastic input. It does not prove the complete NumiBrain architecture or biological realism.

## Apple execution boundary

The Metal implementation compiles `NeuralTissue.metal` as Metal language version 4.0 with safe FP arithmetic and precise floating-point functions. It submits work through a Metal 4 command queue, reusable command buffer and allocator, compute encoder, argument table, explicit dispatch barriers, and a residency set.

Three private state generations preserve transactionality: committed, root shadow, and candidate/scratch. Private immutable buffers hold tissue structure, per-site delay classes, CSR destination offsets, packed `uint4` projection edges, and packed receptor events. Each Metal thread gathers only the incoming edges for its destination site, samples edge-specific history, and scans the bounded canonical event schedule. Relay history uses two private 32-slot FP32 planes. A 32-bit owner mask selects the authoritative plane independently for each logical slot; an accepted candidate writes the opposite plane, while a rejected candidate writes a separate private scratch buffer. Commit publishes the shadow owner mask and step together with state generation ownership. Abort discards those host-side generations and leaves every committed history slot authoritative.

The history allocation is

\[
2\times32\times4=256\text{ bytes per site}.
\]

This is deliberately reported in runtime evidence. A future compressed history representation must demonstrate delayed-trajectory parity and memory/performance benefit before replacing FP32. A tracked shared buffer owns uniforms, and a separate shared staging buffer is used only for initial uploads and explicit inspection after GPU completion. No CPU access occurs between encoded substeps. Moving these private buffers into long-lived placement heaps remains Phase 1 work.

For `N` tissue sites and `E` projections, the immutable sparse graph adds

\[
4(N+1)+16E\text{ bytes}
\]

before allocator alignment. Every event adds another 48 immutable bytes. Graph size, event size, event/random identity, edge count, maximum fan-in, maximum edge delay, and all input hashes are explicit schema-v4 evidence fields.

The bounded event scan is executable but not the final large-cohort event path. Dynamic NumanX event packets, GPU queue compaction, prefix sums, and event-specific indirect dispatch remain Phase 1/2 work and must replace the scan before production-scale claims.
