# Mesoscale neural tissue model v0.16

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

An immutable `uint8` field stores outgoing local-conduction delay class `d_j` for every source site. The configured delay is `d_j` times the model's nominal base timestep. The v0.16 CPU and Metal paths resolve that interval against accepted physical timestamps and linearly interpolate bracketed relay samples. The synthetic layered profile assigns 1–4 ms classes to its four strata; these classes test causal delay handling and do not encode measured axon length, myelination, or conduction velocity.

Long-range connections use a destination-major compressed sparse row graph. Every edge `e=(j,i,w_e,d_e)` names its source and destination sites, an FP32 weight, and its own delay class. Both runtimes convert that class to physical microseconds through the nominal timestep. The default bilateral profile mirrors two synthetic bands across the sheet with one incoming edge per participating site. It exists to exercise disconnected spatial recruitment, sparse GPU execution, and delayed transaction rollback; it is not a corpus callosum model or anatomical connectome.

Runtime input uses an immutable canonical schedule of at most 64 receptor-derived events. Each compiled 64-byte event stores a unique schedule identifier, normalized center and radius, half-open physical-time interval, excitatory and inhibitory drive, bounded noise amplitude, flags, interrupt class, conduction latency, receptor identity, magnitude, and auxiliary metadata. The schedule is neural input after receptor transduction; it is not raw or privileged NumanX state. Before every attempted tissue substep, a Metal kernel compacts the due schedule indices into a private GPU buffer. A device barrier publishes that list before the tissue kernel, so each site scans only the active set. The CPU oracle constructs the same canonical active-index list. Future records may remain in the immutable schedule without entering tissue computation before their timestamps.

After the accepted candidate sequence, `transduce_receptor_interrupts` derives each due onset timestamp as start time plus conduction latency, merges it with any host scheduler events, canonically sorts the result, and leaves the compact queue and count in private GPU memory for `schedule_due_modules`. The first scheduler root includes its lower boundary; later roots exclude it to prevent duplicate onset delivery. This is a root-level causal bridge into regional computation, not yet a mid-physics-substep protective loop.

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

`R-bar` and `I-bar` blend the local site with its four clamped boundary neighbors. Neighbor contributions are weighted by their outgoing coupling and viability. The relay time constant and explicit history delay model different effects: `R` is local axonal filtering, while `d` selects a committed past relay generation. Sparse projections read the same authoritative history with their edge-specific delay, so local and long-range paths share one causal transaction boundary. The finite stencil is the v0.8 numerical approximation to short-range lateral interaction. The implementation uses forward Euler with explicit clamping to the normalized state interval.

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

Grid coordinates are normalized, not millimetres. Event noise is a bounded numerical receptor-drive perturbation, not a fit to receptor or neural noise statistics. V0.11 therefore establishes causal GPU-compacted noisy-event and receptor-interrupt computation with delayed structured neural-field and recurrent regional execution. It does not establish measured sensing, conduction velocity, cortical thickness, anatomical connectivity, learned regional dynamics, lesion pathology, tissue scale, or mid-NumanX-substep emergency latency.

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
- The CPU relay oracle stores accepted physical timestamps, samples delay targets by microseconds, interpolates only between accepted states, and fails closed if a bounded ring has lost a required post-origin bracket.
- A CPU candidate may use a positive duration distinct from the nominal timestep while retaining accepted-step random identity; rejection and root abort append no timestamped relay sample.
- The Metal relay ring stores a timestamp beside each transactional FP32 slot, supports positive candidate durations up to the nominal timestep, and rejects a prospective accepted overwrite when the remaining ring would not cover the maximum configured physical delay.

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
21. CPU active-index selection respects event starts, half-open ends, disabled radii, and overlapping intervals.
22. Metal issues exactly one event-compaction dispatch per candidate attempt, including a rejected retry.
23. The compaction-to-tissue barrier preserves CPU/Metal parity for overlapping noisy events without an active-count readback.
24. Metal due-module and interrupt invocations exactly match the CPU scheduler oracle.
25. Scheduler clocks retry, abort, and commit atomically with tissue state and relay history.
26. Schema-v6 reports the scheduler fingerprint, memory, dispatch count, status, committed generation, snapshot hash, and CPU parity.
27. The private scheduler due list is consumed by `advance_due_regional_tokens` without host inspection.
28. Regional diagnostic state matches the CPU numerical oracle and retains exact discrete counters and timestamps.
29. The 10,752-scalar recurrent token state matches its CPU numerical oracle and consumes seven compiled sparse routes.
30. Regional token and diagnostic state retry, abort, replay, and chunk with the same causal transaction semantics as tissue and scheduler clocks.
31. Route ablation changes the receiver token state without changing tissue or diagnostic scheduler state.
32. Schema-v8 reports program identity, token and route memory, token and diagnostic snapshot hashes, dispatches, update totals, and CPU parity.
33. Compiled regional route delays remain silent until their causal delivery timestamps.
34. Persistent CPU and private Metal route histories agree on ring metadata, message timestamps, and FP32 values.
35. Abort, rejected retry, replay, and control-window chunking preserve the route histories with the same transaction boundary as tokens and clocks.
36. Schema-v9 reports route delays, route-history capacity and memory, route-history snapshot identity, and CPU parity.
37. Candidate regional routes are scored from causal content and compacted through deterministic per-receiver normal top-k budgets.
38. Emergency routes bypass the normal budget and remain active independently of candidate scores.
39. CPU and Metal agree on route scores and normalized strengths within FP32 tolerance and exactly on selections, counters, and timestamps.
40. Routing state retries, aborts, replays, and chunks at the shared tissue, scheduler, token, and route-history transaction boundary.
41. Schema-v10 reports program version, route budgets, routing-state memory, selected-route scratch, active-route counts, routing snapshot identity, and CPU parity.
42. Compiled receptor records include typed interrupt, latency, receptor identity, magnitude, and auxiliary metadata in 64 bytes across C++, Swift, and Metal.
43. CPU and Metal derive the same latency-shifted receptor interrupt without future leakage or adjacent-root boundary duplication.
44. The private transduced interrupt queue is consumed without a hot-path CPU count readback.
45. Rejected retry and full root abort reproduce the same receptor-derived interrupt and regional emergency response.
46. Schema-v11 reports receptor ABI, interrupt and latency configuration, transduction dispatches, private queue memory, typed result status, counts, and CPU parity.
47. A compiled immutable parameter generation fingerprints the 17 tissue dynamics values plus the regional operator without including recurrent state, stimulus, physical time, or random counters.
48. CPU scheduler checkpoint and replay identity includes the parameter version; stale restore and mixed-version cohorts fail closed.
49. Metal scheduler and regional kernels validate one private 64-byte parameter binding before execution.
50. Publication is rejected while a rollout cohort leases the current generation and accepts only its compatible direct successor at a synchronization boundary.
51. Schema-v12 reports manifest, version, parent, component count, bytes, regional shape/content identities, and CPU/Metal version parity.
52. Timestamped CPU relay history returns exact samples at accepted times and deterministic interpolation between irregular accepted samples.
53. Losing a required post-origin time bracket fails closed rather than substituting a temporally incorrect relay value.
54. Variable-duration CPU candidates preserve exact retry, abort, replay, and root-chunking identity.
55. Corrected-duration Metal candidates match the timestamped CPU oracle while rejected retries preserve exact tissue and timestamp ownership.
56. Metal detects insufficient physical-time coverage before overwriting the sole sample needed by the maximum configured delay.

Passing these gates proves an executable replay-deterministic mesoscale tissue field with keyed stochastic input. It does not prove the complete NumiBrain architecture or biological realism.

## Apple execution boundary

The Metal implementation compiles `NeuralTissue.metal` as Metal language version 4.0 with safe FP arithmetic and precise floating-point functions. It submits work through a Metal 4 command queue, reusable command buffer and allocator, compute encoder, argument table, explicit dispatch barriers, and a residency set.

Three private state generations preserve transactionality: committed, root shadow, and candidate/scratch. Private immutable buffers hold tissue structure, per-site delay classes, CSR destination offsets, packed `uint4` projection edges, and packed receptor events. A bounded `compact_receptor_events` dispatch writes one count and the due canonical event indices into a 260-byte private buffer. After an explicit device barrier, each Metal tissue thread gathers only the incoming edges for its destination site, samples edge-specific history by physical microseconds, and scans only those compacted event indices. Relay history uses two private 32-slot FP32 planes plus two matching UInt64 timestamp planes. A 32-bit owner mask selects the authoritative value and timestamp plane independently for each logical slot; an accepted candidate writes the opposite plane, while a rejected candidate writes a separate private relay scratch buffer and no timestamp. Commit publishes the shadow owner mask, accepted timestamps, and step together with state generation ownership. Abort discards those host-side generations and leaves every committed history slot authoritative. The host validates maximum-delay coverage before dispatch; the shader performs deterministic lower/upper timestamp selection and linear interpolation without a history readback.

After the accepted tissue candidate sequence, the same encoder dispatches `transduce_receptor_interrupts`, barriers its canonical private event queue, then dispatches `schedule_due_modules`. The scheduler validates a private immutable parameter-version binding, reads private immutable module descriptors and the committed private clock generation, then writes the other clock generation plus a private due-invocation list. Root commit publishes tissue, relay, and scheduler ownership together. Abort publishes none of their neural effects. Scheduler inspection is an explicit post-completion staging operation and never occurs between control roots.

After another device barrier, `advance_due_regional_tokens` consumes the private result and due list with one 256-lane threadgroup. Lanes stride across 10,752 FP32 region-major token scalars and resolve delayed messages from per-route timestamp rings. At each due timestamp, one lane per receiver scores its causal candidate messages, compacts every emergency route plus the configured normal top-k, preserves active routes inside a 2 ms minimum interval, and normalizes selected strengths. Scalar lanes gather only those compacted indices before publishing the timestamp synchronously. The kernel writes the other private token, diagnostic, route-history, and per-agent routing-state generations. Regional ownership is published with scheduler clock and tissue generations. The factorized parameter and score fixtures have learned-model form but are not trained production models; learned/context-conditioned routing and its differentiable training form remain absent.

The history allocation is

\[
2\times32\times4=256\text{ bytes per site}.
\]

The timestamp planes add a fixed

\[
2\times32\times8=512\text{ bytes per runtime}.
\]

This is deliberately reported in runtime evidence. A future compressed history representation must demonstrate delayed-trajectory parity and memory/performance benefit before replacing FP32. A tracked shared buffer owns uniforms, and a separate shared staging buffer is used only for initial uploads and explicit inspection after GPU completion. No CPU access occurs between encoded substeps. Moving these private buffers into long-lived placement heaps remains Phase 1 work.

For `N` tissue sites and `E` projections, the immutable sparse graph adds

\[
4(N+1)+16E\text{ bytes}
\]

before allocator alignment. Every event adds another 64 immutable bytes. The fixed active-event allocation is

\[
4(1+64)=260\text{ bytes},
\]

holding one 32-bit count and up to 64 32-bit schedule indices. The default scheduler adds 256 descriptor bytes, two 128-byte private clock generations, a 1,536-byte shared host-interrupt capacity, a second 1,536-byte private transduced-interrupt capacity, 40 shared transduction-uniform bytes, a 16-byte private transduction result, 56 shared scheduler-uniform bytes, a 64-byte private immutable parameter binding, a 131,072-byte private invocation capacity, and a 16-byte private scheduler result. Regional execution adds two 256-byte diagnostic generations, two 43,008-byte token generations, one 43,008-byte candidate buffer, 344,064 immutable parameter bytes, 256 layout bytes, 168 route bytes, a 48-byte program header, two 224-byte route-runtime generations, a 28-byte selected-route-index span, and a 32-byte selected-count span before allocator alignment. Graph, event, scheduler, parameter-version, regional, routing, memory, transaction, and input identities are explicit schema-v12 evidence fields.

The bounded one-lane GPU compactor removes inactive schedule entries from per-site work, but it is not the final large-cohort event path. Dynamic NumanX event packets, parallel prefix-sum cohort compaction, event-specific indirect dispatch, and queue-capacity pressure handling remain Phase 1/2 work before production-scale claims.
