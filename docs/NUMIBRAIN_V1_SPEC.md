<!--
Canonical standalone architecture supplied by the repository owner.
Imported without semantic rewriting; only Markdown presentation was normalized.
-->

# NumiBrain v1.0

Apple-Native Developmental Embodied Nervous System

Status: Formal standalone architecture specification
Primary target: Apple m4 M5-family GPUs through Metal 4
Execution model: GPU-resident, multi-rate, event-driven, transactional
Coupling target: NumanX
Numerical class: Hierarchical recurrent latent-state system with sparse routing, explicit memory, local plasticity, world-model planning and structured motor control

---

## 1. Definition

NumiBrain is the authoritative nervous-system runtime for embodied humans, animals and robots inside NumiLab.

Its purpose is to let an embodied agent:

* Perceive through physically simulated senses.
* Infer its own body and the external world.
* Control muscles and autonomic systems.
* Learn from interaction.
* Form working, episodic, semantic and procedural memories.
* Develop reusable skills.
* Select actions from goals, needs, threats and curiosity.
* Plan through predicted consequences.
* Adapt after physical change or injury.
* Develop increasingly complex behavior over a lifetime.

The complete system is

\[
\boxed{
\text{NumiLab}

\text{NumanX}
+
\text{NumiBrain}
+
\text{developmental environment}
}
\]

where:

* NumanX owns authoritative body, material, contact, muscle, organ and environment physics.
* NumiBrain owns perception, belief, memory, motivation, action selection, learning and neural control.
* The developmental environment supplies objects, consequences, social agents, demonstrations, language, challenges and opportunities for autonomous exploration.

NumiBrain is not a collection of independent policies. Every subsystem participates in one causal nervous-system state and one embodied learning loop.

NumiBrain is not a neuron-by-neuron reconstruction. Its standard representation is a mesoscale population model with:

* Dense local neural computation.
* Sparse long-range communication.
* Explicit event pathways.
* Trainable recurrent regional states.
* Explicit memory stores.
* Multi-timescale plasticity.
* Species-specific sensory and motor structures.

Detailed spiking or compartmental neurons are optional local modules for timing-critical or neuroscience-specific experiments. They are not the default representation of the complete brain.

---

## 2. Authoritative causal loop

The canonical loop is

\[
\boxed{
\begin{aligned}
\text{physical state}
&\rightarrow
\text{biological sensor transduction}
\
&\rightarrow
\text{belief and body-state inference}
\
&\rightarrow
\text{world-model update}
\
&\rightarrow
\text{memory retrieval}
\
&\rightarrow
\text{goal and option selection}
\
&\rightarrow
\text{motor and autonomic commands}
\
&\rightarrow
\text{NumanX physical evolution}
\
&\rightarrow
\text{new sensory consequences}
\
&\rightarrow
\text{memory and learning}.
\end{aligned}
}
\]

The high-level brain does not receive perfect simulator state. It receives only physically realizable sensor signals, delayed and transformed by receptor models.

Privileged NumanX state may be used during training for auxiliary supervision. It is carried through a separate teacher channel and is never exposed as a normal NumiBrain observation.

---

## 3. Non-negotiable invariants

### 3.1 Causal perception

NumiBrain receives no future observations and no perfect body state.

### 3.2 Embodied action

The authoritative somatic output is muscle excitation or an equivalent actuator command. NumiBrain does not directly write body position, velocity or contact force.

### 3.3 Unified belief

The body schema, world model, spatial model and self-model are factors of one compatible belief state. They cannot maintain contradictory authoritative estimates.

### 3.4 Multi-rate operation

Every subsystem runs at its required biological and computational timescale. Fast reflexes do not wait for slow planning.

### 3.5 Event interruption

Pain, damaging contact, loss of support, impact and critical physiological changes can interrupt slower processing immediately.

### 3.6 Committed experience only

Rejected NumanX trajectories do not alter memory, learning, drive state, plasticity or neural history.

### 3.7 Shared weights, independent minds

Training environments may share slow model parameters. Every agent retains independent recurrent state, working memory, episodic memory, drives, plasticity and action history.

### 3.8 Versioned learning

Shared parameters remain immutable throughout a rollout cohort. Updated parameters are published as a new version at a synchronization boundary.

### 3.9 No lifetime backpropagation

NumiBrain uses truncated gradients, replay, local plasticity and explicit memory. It never backpropagates through an agent’s full lifetime.

### 3.10 Species specialization

Human, quadruped, bird and other brains share the runtime contract, not one identical anatomical graph.

### 3.11 GPU residence

The normal physics–brain loop remains on the GPU. CPU intervention is limited to orchestration, checkpointing, inspection and exceptional control paths.

### 3.12 Deterministic rollback

A physical retry reuses the same neural decision, stochastic samples and random counters unless simulated time actually advances.

---

## 4. Complete system state

At committed simulation time (t), define

\[
\boxed{
C_t=
\left(
S_t,
B_t,
\Theta^{(v)},
\Gamma_s
\right)
}
\]

where:

* (S_t): authoritative NumanX physical state.
* (B_t): committed per-agent NumiBrain state.
* (\Theta^{(v)}): immutable shared slow parameters, version (v).
* (\Gamma_s): species and developmental template.

The per-agent brain state is

\[
\boxed{
B_t=
\left(
H_t,
\Xi_t,
W_t,
\mathcal M_t^E,
\mathcal M_t^S,
\mathcal M_t^P,
D_t,
N_t,
F_t,
\Pi_t,
A_t^{\mathrm{dev}},
\Lambda_t
\right).
}
\]

### 4.1 Regional state

\[
H_t={H_{r,t}}_{r=1}^{R}
\]

contains recurrent neural-population states for all functional modules.

### 4.2 Belief state

\[
\Xi_t
\]

contains the posterior distribution over the estimated body, environment, other agents, physiological condition and task context.

### 4.3 Workspace

\[
W_t
\]

contains the small set of currently broadcast goal, object, body, memory, plan and error tokens.

### 4.4 Episodic memory

\[
\mathcal M_t^E
\]

stores event-segmented personal experiences.

### 4.5 Semantic memory

\[
\mathcal M_t^S
\]

stores explicit concepts, facts, relations and confidence values.

### 4.6 Procedural memory

\[
\mathcal M_t^P
\]

stores reusable motor and cognitive skills.

### 4.7 Drives

\[
D_t
\]

contains physiological deficits, motivational demands and active goal pressures.

### 4.8 Neuromodulation

\[
N_t
\]

contains functional modulatory channels controlling learning, routing, gain, vigor, salience and memory.

### 4.9 Fast plasticity

\[
F_t
\]

contains eligibility traces and compact per-agent fast-plastic coefficients.

### 4.10 Active control state

\[
\Pi_t
\]

contains the current intention, selected option, plan, controller phase, cerebellar context and spinal state.

### 4.11 Developmental state

\[
A_t^{\mathrm{dev}}
\]

contains developmental age, maturation stage, plasticity schedule, active critical periods and currently unlocked structures.

### 4.12 Runtime state

\[
\Lambda_t
\]

contains clocks, delay lines, event queues, oscillator phases, memory allocator state, transaction generations and random-number counters.

---

## 5. Shared parameter state

The versioned shared parameters are

\[
\Theta^{(v)}

\left{
\Theta^{\mathrm{sens}},
\Theta^{\mathrm{belief}},
\Theta^{\mathrm{world}},
\Theta^{\mathrm{route}},
\Theta^{\mathrm{memory}},
\Theta^{\mathrm{value}},
\Theta^{\mathrm{policy}},
\Theta^{\mathrm{motor}},
\Theta^{\mathrm{cerebellar}},
\Theta^{\mathrm{plasticity}}
\right}^{(v)}.
\]

Shared weights include:

* Sensor encoders.
* Regional recurrent operators.
* World-model dynamics.
* Route projections.
* Memory encoders.
* Value and risk predictors.
* Skill policies.
* Motor transforms.
* Cerebellar experts.
* Bases for fast plasticity.

They do not include:

* Per-agent recurrent activations.
* Per-agent memories.
* Per-agent drives.
* Per-agent fast-plastic coefficients.
* Per-agent active plans.
* Per-agent random counters.

---

## 6. Species template

A species template is

\[
\boxed{
\Gamma_s=
\left(
\mathcal G_s^{\mathrm{region}},
\mathcal G_s^{\mathrm{body}},
\mathcal T_s^{\mathrm{sense}},
\mathcal T_s^{\mathrm{motor}},
\mathcal R_s^{\mathrm{reflex}},
\mathcal C_s^{\mathrm{CPG}},
\mathcal P_s^{\mathrm{physiology}},
\mathcal I_s^{\mathrm{innate}},
\mathcal U_s^{\mathrm{development}},
\mathcal K_s^{\mathrm{capacity}}
\right).
}
\]

It defines:

* Functional region graph.
* Body and muscle graph.
* Receptor geometry.
* Sensory resolution and latency.
* Motor nuclei and synergy structure.
* Reflex circuits.
* Central pattern generators.
* Reduced or detailed physiological dynamics.
* Innate protective behavior.
* Developmental schedule.
* Regional capacity allocation.

A species template may:

* Disable a reference module.
* Split one reference module into several modules.
* Merge several modules.
* Add a species-specific module.
* Change regional dimensions.
* Change sensory or motor topology.
* Change developmental timing.

The runtime interfaces remain stable.

---

## 7. Time model and scheduler

NumiBrain uses physical simulation time, not wall-clock execution time.

Let the main NumiLab control interval be

\[
\Delta_{\mathrm{control}}=20\text{ ms}.
\]

NumanX integrates this interval through accepted physical substeps

\[
\delta_k\le 5\text{ ms}.
\]

Every NumiBrain module has:

* A next-due timestamp.
* An update period.
* A conduction delay.
* An intrinsic timescale.
* An event-interrupt mask.

The initial schedule is:

System	Update period
Physical contact and muscle integration	(1)–(5) ms
Emergency nociceptive and support events	Event-time
Spinal reflexes	(1)–(5) ms
Locomotor and respiratory CPGs	(2)–(5) ms
Cerebellar prediction and correction	(5) ms
Proprioceptive and tactile fusion	(5)–(10) ms
Vestibular fusion	(5)–(10) ms
Early auditory processing	(5)–(10) ms
Early visual processing	(10)–(20) ms
Sensorimotor cortex	(10)–(20) ms
Body schema	(10)–(20) ms
Fast world-model level	(20) ms
Basal-ganglia option gate	(20)–(40) ms
Workspace broadcast	(50) ms
Scene and event model	(50)–(100) ms
Deliberate planning	(100) ms
Homeostatic planning state	(100) ms
Abstract and social state	(100)–(500) ms
Replay and consolidation	Event-driven during rest

Module periods adapt through

\[
\tau_{r,t}

\tau_r^0
\exp
\left[
g_r
\left(
D_t,
N_t,
W_t,
U_t
\right)
\right],
\]

where (U_t) is current uncertainty.

Arousal can shorten integration periods and raise routing bandwidth. Fatigue and sleep pressure can reduce cortical update rates while increasing replay allocation.

All inter-module messages carry timestamps. A receiving module obtains both message content and message age.

---

## 8. Regional computation primitive

For region (r),

\[
H_{r,t}
\in
\mathbb R^{B\times n_r\times d_r},
\]

where:

* (B): environment cohort size.
* (n_r): number of local state tokens.
* (d_r): token dimension.

The input is

\[
\begin{aligned}
I_{r,t}
={}&
E_r(O_t,E_t)
+
\sum_{j\in\mathcal A_{r,t}}
G_{jr,t}
P_{jr}
H_{j,t-\ell_{jr}}
\
&+
P_r^W W_t
+
P_r^D D_t
+
P_r^N N_t
+
P_r^\Pi \Pi_t.
\end{aligned}
\]

Here:

* (O_t): receptor observations.
* (E_t): event tokens.
* (\mathcal A_{r,t}): active incoming route set.
* (G_{jr,t}): route strength.
* (\ell_{jr}): communication delay.

The effective regional weights are

\[
\Theta_{r,t}^{\mathrm{effective}}

\Theta_r
+
\sum_{\ell=1}^{L_r}
f_{r\ell,t}B_{r\ell},
\]

where (B_{r\ell}) are shared plasticity bases and (f_{r\ell,t}) are per-agent coefficients.

The regional update is

\[
\widetilde H_{r,t+\Delta_r}

F_r
\left(
H_{r,t},
I_{r,t};
\Theta_{r,t}^{\mathrm{effective}}
\right),
\]

\[
H_{r,t+\Delta_r}

H_{r,t}
+
\alpha_{r,t}
Z_{r,t}
\odot
\left(
\widetilde H_{r,t+\Delta_r}

H_{r,t}
\right),
\]

with

\[
\alpha_{r,t}

1-
\exp
\left(
-\frac{\Delta_r}{\tau_{r,t}}
\right).
\]

(Z_{r,t}) is a learned state-update gate.

Regions use dense local computation. Long-range messages use sparse routed tokens.

---

## 9. Reference 96-module brain graph

The first mammalian reference template contains 96 logical modules. Logical modules may be fused into one kernel or split into several kernels.

### 9.1 Sensory and peripheral modules: 1–18

1. Left foveal retina
2. Right foveal retina
3. Left peripheral retina
4. Right peripheral retina
5. Visual motion and depth
6. Visual form and surface structure
7. Left cochlear stream
8. Right cochlear stream
9. Auditory scene analysis
10. Skin pressure and shear
11. Skin vibration and texture
12. Temperature and nociception
13. Proprioceptive receptor fusion
14. Vestibular receptor fusion
15. Olfactory processing
16. Gustatory processing
17. Interoceptive processing
18. Multisensory alignment

### 9.2 Routing and broadcast modules: 19–26

19. Primary sensory relay
20. Visual routing
21. Auditory routing
22. Somatic routing
23. Higher-order association routing
24. Salience gate
25. Workspace broadcast
26. Emergency interrupt bus

### 9.3 Body and spatial-self modules: 27–36

27. Body-graph state
28. Joint-state estimator
29. Muscle-state estimator
30. Self-generated versus external contact
31. Balance and support model
32. Peripersonal-space model
33. Reachability and affordance model
34. Pain and vulnerability map
35. Agency and corollary-discharge model
36. Spatial coordinate transforms

### 9.4 World and association modules: 37–52

37. Fast sensory dynamics
38. Sensorimotor dynamics
39. Object-slot state
40. Other-agent slot state
41. Local scene model
42. Persistent spatial map
43. Physical and causal interaction model
44. Social prediction
45. Temporal context
46. Event segmentation
47. Abstract state
48. Goal context
49. Counterfactual dynamics
50. Uncertainty decomposition
51. Communication and language association
52. Self-history and identity state

### 9.5 Memory modules: 53–62

53. Working-memory maintenance
54. Episodic encoder
55. Episodic index
56. Episodic retrieval
57. Episodic reconsolidation
58. Semantic concept store
59. Semantic relation store
60. Procedural skill library
61. Prospective intention memory
62. Replay and consolidation

### 9.6 Motivation and neuromodulation modules: 63–70

63. Homeostatic controller
64. Pain and threat controller
65. Curiosity and information drive
66. Social drive
67. Value-prediction system
68. Arousal and gain controller
69. Sleep and rest controller
70. Neuromodulator dispatch

### 9.7 Decision modules: 71–78

71. Affordance proposer
72. Skill candidate generator
73. Direct selection channel
74. Indirect suppression channel
75. Hyperdirect stop channel
76. Option sequencer
77. Latent planner
78. Arbitration, persistence and vigor

### 9.8 Motor, cerebellar, brainstem and spinal modules: 79–96

79. Motor-goal transform
80. Reference movement generator
81. Muscle-synergy generator
82. Force, stiffness and impedance control
83. Cerebellar context selector
84. Cerebellar forward prediction
85. Cerebellar inverse correction
86. Cerebellar error and adaptation
87. Orienting brainstem controller
88. Posture and balance brainstem controller
89. Autonomic brainstem controller
90. Locomotor CPG
91. Vital and respiratory CPG
92. Upper-limb spinal controller
93. Lower-limb spinal controller
94. Axial and neck spinal controller
95. Reflex interneuron network
96. Motor-neuron output

The first production runtime activates 12–24 modules per environment per cortical tick. Timing-critical spinal and receptor modules remain active at their own faster clocks.

---

## 10. Sensory transduction

NumiBrain does not consume raw authoritative physics variables as observations.

For modality (m),

\[
o_t^m
\sim
T_m
\left(
S_{t-\ell_m},
a_{t-\ell_m}^{\mathrm{sense}},
\eta_t^m
\right),
\]

where:

* (T_m): receptor transduction model.
* (\ell_m): sensing and conduction latency.
* (a^{\mathrm{sense}}): active sensing command.
* (\eta_t^m): receptor noise and adaptation state.

The complete sensory observation is

\[
O_t=
\left(
o_t^{\mathrm{vision}},
o_t^{\mathrm{audio}},
o_t^{\mathrm{touch}},
o_t^{\mathrm{proprio}},
o_t^{\mathrm{vestibular}},
o_t^{\mathrm{olfaction}},
o_t^{\mathrm{taste}},
o_t^{\mathrm{intero}}
\right).
\]

### 10.1 Vision

The visual path includes:

* Eye position and accommodation.
* Foveal and peripheral resolution.
* Photoreceptor adaptation.
* Binocular disparity.
* Motion and optic-flow channels.
* Occlusion.
* Field-of-view limits.
* Saccadic suppression.
* Sensor noise and latency.

Eye and head orientation are physical motor actions. Attention changes routing and processing allocation but does not rotate the visual sensor without a corresponding physical action.

### 10.2 Audition

The auditory path includes:

* Cochlear frequency decomposition.
* Left and right channels.
* Interaural timing.
* Interaural level.
* Adaptation.
* Reverberation.
* Self-generated sound prediction.
* Head-motion-dependent localization.

### 10.3 Touch

The skin is represented as a body-surface graph.

Each receptor site can provide:

\[
\left(
p,
s_1,
s_2,
v,
T,
n,
\ell
\right),
\]

where:

* (p): pressure.
* (s_1,s_2): tangential shear.
* (v): vibration.
* (T): temperature.
* (n): nociceptive intensity.
* (\ell): local tissue-risk signal.

Different body regions use different receptor density, pain threshold and vulnerability.

### 10.4 Proprioception

Proprioceptive sensors include:

* Muscle length.
* Muscle length velocity.
* Tendon force.
* Joint angle.
* Joint velocity.
* Joint-limit activation.
* Muscle fatigue.
* Local motor-neuron efference copy.

### 10.5 Vestibular sensing

Vestibular channels include:

* Angular velocity.
* Angular acceleration.
* Linear acceleration.
* Gravity direction.
* Head orientation.
* Sensor adaptation and drift.

### 10.6 Interoception

Interoceptive signals include:

* Energy availability.
* Hydration.
* Oxygen and carbon-dioxide state.
* Temperature.
* Fatigue.
* tissue damage.
* inflammation.
* visceral stretch.
* sleep pressure.
* autonomic state.

### 10.7 Chemical senses

Olfaction and taste use spatially and temporally structured chemical fields generated by the environment and body.

### 10.8 Event tokens

Raw NumanX events are first transformed by receptor models. Trainable NumiBrain modules receive receptor-derived event tokens.

The event set includes:

\[
\begin{aligned}
E_t={&
\text{touch-on},
\text{touch-off},
\text{impact},
\text{slip},
\text{loss-of-support},
\
&
\text{joint-limit},
\text{muscle-overload},
\text{pain},
\text{injury-risk},
\
&
\text{sound-onset},
\text{visual-transient},
\text{physiological-critical},
\text{rescue}
}.
\end{aligned}
\]

A packed GPU event token contains:

* Environment identifier.
* Event timestamp.
* Event type.
* Body, receptor or entity identifier.
* Magnitude.
* Auxiliary value.
* Flags.

Critical events reach the emergency interrupt bus without waiting for the next cortical frame.

A separate non-learnable runtime safety channel may stop physically destructive execution. It is not visible as an ordinary neural observation.

---

## 11. Active sensing

The complete action is

\[
\boxed{
a_t=
\left(
a_t^{\mathrm{somatic}},
a_t^{\mathrm{autonomic}},
a_t^{\mathrm{sense}},
a_t^{\mathrm{internal}}
\right).
}
\]

### 11.1 Somatic action

Controls skeletal muscles or robotic actuators.

### 11.2 Autonomic action

Controls reduced or detailed physiological systems such as:

* Ventilation.
* Heart-rate target.
* Vascular tone.
* Digestive allocation.
* Pupil state.
* Thermoregulatory response.

### 11.3 Sensing action

Controls:

* Eyes.
* Head.
* Ears or pinnae.
* Whiskers.
* Sniffing.
* Palpation.
* Sensor gain.
* Attentional sampling.

### 11.4 Internal action

Controls:

* Memory retrieval.
* Workspace writes.
* Workspace clearing.
* Route allocation.
* Planning initiation.
* Planning termination.
* Deliberate inhibition.
* Replay allocation.

The observation distribution depends on sensing action:

\[
p
\left(
O_{t+1}
\mid
S_{t+1},
a_t^{\mathrm{sense}}
\right).
\]

The agent learns when and where additional sensing is worth its time, energy and exposure to risk.

---

## 12. Unified embodied belief state

The internal latent state is

\[
X_t=
\left(
X_t^{\mathrm{self}},
O_t^{\mathrm{entity}},
A_t^{\mathrm{agent}},
R_t^{\mathrm{relation}},
M_t^{\mathrm{space}},
P_t^{\mathrm{physiology}},
C_t^{\mathrm{context}}
\right).
\]

### 12.1 Self factor

Contains:

* Estimated body configuration.
* Body velocity.
* Muscle activation.
* Contact state.
* Force state.
* Support geometry.
* Pain state.
* Body ownership.
* Reachability.
* Peripersonal space.

### 12.2 Entity factor

Contains a variable set of object slots.

Each object slot contains:

\[
x_{i,t}^{\mathrm{object}}

\left(
e_i,
\iota_i,
q_i,
v_i,
s_i,
m_i,
a_i,
\chi_i,
u_i
\right),
\]

where:

* (e_i): existence probability.
* (\iota_i): identity belief.
* (q_i): pose.
* (v_i): motion.
* (s_i): shape.
* (m_i): material.
* (a_i): affordances.
* (\chi_i): visibility and occlusion state.
* (u_i): uncertainty.

### 12.3 Other-agent factor

Contains:

* Other-agent identity.
* Body pose.
* Gaze and attention estimate.
* Predicted action.
* Estimated goal.
* Social relation.
* Confidence.

### 12.4 Relation factor

Contains typed relations such as:

* Contacting.
* Supporting.
* Inside.
* Attached.
* Owned by.
* Reachable.
* Occluding.
* Following.
* Threatening.
* Communicating with.

### 12.5 Spatial factor

Maintains:

* Sensor-centered coordinates.
* Head-centered coordinates.
* Body-centered coordinates.
* Local world coordinates.
* Persistent map coordinates.
* Transform uncertainty.

### 12.6 Physiology factor

Contains the brain’s estimate of internal physical state. It is not the same as the authoritative NumanX physiology state.

### 12.7 Context factor

Contains:

* Current event.
* Current task.
* Current social context.
* Active goal.
* Location.
* Time context.
* Current behavioral mode.

---

## 13. Posterior inference

The learned prior is

\[
p_\theta
\left(
X_t
\mid
X_{t-1},
a_{t-1}
\right).
\]

The observation-conditioned posterior is

\[
q_\phi
\left(
X_t
\mid
X_{t-1},
a_{t-1},
O_t,
E_t,
\rho_t^E
\right),
\]

where (\rho_t^E) is retrieved episodic information.

The posterior state stores:

* Continuous means.
* Continuous log variances.
* Discrete latent codes.
* Entity-existence probabilities.
* Identity probabilities.
* Relation probabilities.
* Epistemic confidence.
* Observation-noise estimates.

The belief objective is

\[
\begin{aligned}
\mathcal L_{\mathrm{belief}}
={}&
-\sum_m
\mathbb E
\left[
\log p_\theta
\left(
o_t^m\mid X_t
\right)
\right]
\
&-
\mathbb E
\left[
\log p_\theta
\left(
E_t\mid X_t
\right)
\right]
\
&+
\beta
D_{\mathrm{KL}}
\left[
q_\phi(X_t\mid\cdot)
|
p_\theta(X_t\mid\cdot)
\right]
\
&+
\mathcal L_{\mathrm{consistency}}
+
\mathcal L_{\mathrm{multistep}}.
\end{aligned}
\]

Entity identity is maintained through soft assignment between new observations and existing object or agent slots.

Occluded entities remain active through predicted dynamics until uncertainty becomes too high or evidence indicates removal.

---

## 14. Learned body schema

The body schema is represented on a graph

\[
\mathcal G_t^{\mathrm{body}}

\left(
V_t^{\mathrm{body}},
E_t^{\mathrm{joint}},
E_t^{\mathrm{muscle}},
E_t^{\mathrm{skin}},
E_t^{\mathrm{support}}
\right).
\]

Each body node contains:

* Estimated pose.
* Estimated velocity.
* Mass and inertia belief.
* Contact state.
* Local force.
* Skin state.
* Pain.
* Vulnerability.
* Reachability.
* Ownership confidence.

Each muscle edge contains:

* Estimated activation.
* Estimated length.
* Estimated velocity.
* Estimated force.
* Fatigue.
* Learned effect on body motion.

The body update is

\[
X_{t+1}^{\mathrm{self}}

F_b
\left(
X_t^{\mathrm{self}},
O_t^{\mathrm{proprio}},
O_t^{\mathrm{touch}},
O_t^{\mathrm{vision}},
O_t^{\mathrm{vestibular}},
a_t^{\mathrm{somatic}}
\right).
\]

The body model predicts expected sensory consequences:

\[
\widehat O_{t+1}^{\mathrm{self}}

P_b
\left(
X_t^{\mathrm{self}},
a_t^{\mathrm{somatic}}
\right).
\]

The resulting mismatch is used to:

* Calibrate joint and muscle effects.
* Detect external disturbances.
* Distinguish self-generated from external contact.
* Adapt to changed mass.
* Adapt to changed limb geometry.
* Adapt to actuator weakness.
* Detect injury.
* Incorporate tools.
* Update reachable space.

The agency estimate compares efference-copy predictions with observed timing, direction and location.

The body schema never receives the exact NumanX body state during normal operation.

---

## 15. Hierarchical predictive world model

NumiBrain uses five predictive levels.

Level 0: receptor dynamics

Timescale:

\[
5\text{–}20\text{ ms}.
\]

Predicts:

* Immediate visual motion.
* Auditory transients.
* Tactile changes.
* Proprioceptive changes.
* Reflex-relevant events.

Level 1: sensorimotor dynamics

Timescale:

\[
20\text{–}100\text{ ms}.
\]

Predicts:

* Body response to action.
* Contact formation.
* Support changes.
* Local object motion.
* Immediate affordances.

Level 2: entity and scene dynamics

Timescale:

\[
100\text{ ms}–2\text{ s}.
\]

Predicts:

* Object persistence.
* Agent motion.
* Spatial relations.
* Collision outcomes.
* Reach and grasp consequences.

Level 3: event and option dynamics

Timescale:

\[
1\text{–}30\text{ s}.
\]

Predicts:

* Option outcomes.
* Event transitions.
* Goal progress.
* Threat evolution.
* Energy and fatigue consequences.

Level 4: abstract and social dynamics

Timescale:

\[
\text{seconds to minutes}.
\]

Predicts:

* Plans.
* Social responses.
* Communication consequences.
* Long-term goal state.
* Semantic and causal relationships.

For level (\ell),

\[
p_\theta
\left(
X_{t+\Delta_\ell}^{(\ell)}
\mid
X_t^{(\ell)},
X_t^{(\ell+1)},
a_{t:t+\Delta_\ell}
\right).
\]

Lower levels send prediction errors upward. Higher levels send contextual predictions downward.

The world model predicts:

\[
\boxed{
\left(
O_{t+1},
X_{t+1},
E_{t+1},
D_{t+1},
r_{t+1},
C_{t+1}^{\mathrm{risk}},
U_{t+1}
\right).
}
\]

This includes:

* Future sensory state.
* Future body state.
* Entity state.
* Contact events.
* Pain.
* Tissue risk.
* Fatigue.
* Physiological state.
* Task outcome.
* Information gain.
* Other-agent behavior.
* Epistemic uncertainty.
* Irreducible observation uncertainty.

A shared world-model trunk uses five lightweight dynamics heads. Head disagreement represents epistemic uncertainty. Predicted observation variance represents aleatoric uncertainty.

Unpredictable noise does not create curiosity reward.

---

## 16. Thalamic-style routing

Each sending module creates message tokens

\[
M_{j,t}

P_j^{\mathrm{out}}H_{j,t}.
\]

For route (j\rightarrow r),

\[
\ell_{jr,t}^{\mathrm{route}}

\frac{
q_{r,t}^{\mathsf T}
k_{j,t}
}{
\sqrt d
}
+
b_{jr}
+
s_{jr,t}^{\mathrm{salience}}
+
h_{jr,t}^{\mathrm{persistence}}
+
c_{jr,t}^{\mathrm{context}}.
\]

The active routes are

\[
\mathcal A_{r,t}

\operatorname{TopK}
\left(
\ell_{1r,t}^{\mathrm{route}},
\ldots,
\ell_{Rr,t}^{\mathrm{route}}
\right).
\]

Route strengths are normalized over the active set.

Each receiving region has:

* Maximum route count.
* Maximum token count.
* Minimum route-persistence time.
* Route-switching penalty.
* Emergency route mask.
* Capacity-balancing term.

Emergency pain, loss-of-support and damaging-contact paths are permanent and do not compete with normal top-(k) capacity.

Training uses differentiable sparse routing. Deployment uses deterministic top-(k) routing.

---

## 17. Global workspace

The workspace is tokenized:

\[
\boxed{
W_t
\in
\mathbb R^{B\times N_W\times d_W}.
}
\]

The first production configuration uses

\[
N_W=16,
\qquad
d_W=256.
\]

Each token contains:

* Content vector.
* Token type.
* Entity or body identifier.
* Source module.
* Confidence.
* Timestamp.
* Age.
* Persistence priority.
* Goal binding.
* Memory provenance.

Token types include:

\[
{
\text{self},
\text{goal},
\text{object},
\text{agent},
\text{memory},
\text{plan},
\text{error},
\text{drive},
\text{action},
\text{language}
}.
\]

Candidate workspace writes receive scores from:

* Current salience.
* Goal relevance.
* Prediction error.
* Memory relevance.
* Threat.
* Uncertainty.
* Required cross-module coordination.

The workspace update is

\[
W_{t+1}

\operatorname{SelectAndMerge}
\left(
W_t,
\mathcal C_t^{\mathrm{workspace}}
\right).
\]

Workspace tokens may be:

* Written.
* Refreshed.
* Bound to another token.
* Held.
* Replaced.
* Cleared.

The basal-ganglia system controls write, hold and clear operations.

---

## 18. Memory architecture

NumiBrain contains four distinct memory systems.

---

### 18.1 Working memory

Working memory is maintained through recurrent cortical state and workspace tokens.

For a working-memory slot,

\[
w_{t+1}

g_t^{\mathrm{write}}
\odot
\widetilde w_{t+1}
+
g_t^{\mathrm{hold}}
\odot
w_t,
\]

subject to

\[
g_t^{\mathrm{write}}
+
g_t^{\mathrm{hold}}
+
g_t^{\mathrm{clear}}

\]

Working memory stores current information, not lifetime knowledge.

---

### 18.2 Episodic memory

Episodic memory stores event segments rather than isolated transitions.

Event boundaries

The boundary score is

\[
\begin{aligned}
b_t
={}&
\alpha_s S_t^{\mathrm{surprise}}
+
\alpha_c
\left|
C_t-C_{t-1}
\right|
\
&+
\alpha_g
\mathbf 1[\text{goal transition}]
+
\alpha_o
\mathbf 1[\text{option termination}]
\
&+
\alpha_e E_t^{\mathrm{salience}}
+
\alpha_l
\mathbf 1[\text{location transition}].
\end{aligned}
\]

An episode boundary is emitted when (b_t) exceeds its adaptive threshold.

Episodic record

A record is

\[
M_i^E

\left(
k_i,
v_i,
t_i^0,
t_i^1,
c_i,
g_i,
a_i,
y_i,
u_i,
\sigma_i,
p_i
\right),
\]

where:

* (k_i): retrieval key.
* (v_i): compressed latent trajectory.
* (t_i^0,t_i^1): start and end time.
* (c_i): context.
* (g_i): active goal.
* (a_i): action and option sequence.
* (y_i): outcome.
* (u_i): uncertainty.
* (\sigma_i): salience.
* (p_i): provenance.

Memory write

The write score is

\[
s_i^{\mathrm{write}}

w_NN_i
+
w_\delta|\delta_i|
+
w_PP_i
+
w_GG_i
+
w_UU_i
+
w_SS_i

w_RR_i,
\]

where the terms represent novelty, value error, pain, goal relevance, uncertainty, social relevance and redundancy.

High-salience events are stored after one exposure.

Retrieval

The query is generated from:

\[
q_t

Q
\left(
\Xi_t,
W_t,
D_t,
\Pi_t
\right).
\]

The retrieval score is

\[
\begin{aligned}
s_i^{\mathrm{retrieve}}
={}&
\frac{
q_t^{\mathsf T}k_i
}{
\sqrt d
}
+
\beta_g
\operatorname{GoalMatch}(g_t,g_i)
\
&+
\beta_c
\operatorname{ContextMatch}(c_t,c_i)
+
\beta_\sigma\sigma_i
\
&-
\beta_u u_i

\beta_r
\operatorname{Redundancy}(i).
\end{aligned}
\]

The top records are reconstructed and supplied to the belief model, workspace and planner.

Reconsolidation

Retrieved memories can be:

* Confirmed.
* Corrected.
* Recontextualized.
* Merged.
* Split.
* Marked uncertain.
* Rewritten with retained provenance.

Storage tiers

Tier 0: active event buffer

Contains the current unfinished episode.

Tier 1: active episodic store

Contains recent and frequently retrieved full-resolution records.

Tier 2: compressed archive

Contains older quantized records indexed through coarse clusters and exact reranking.

---

### 18.3 Semantic memory

Semantic memory has two forms.

Distributed semantic memory

Stable structure is consolidated into slow model weights.

Explicit semantic memory

\[
\mathcal M^S

\left(
V^{\mathrm{concept}},
E^{\mathrm{relation}},
C^{\mathrm{confidence}},
T^{\mathrm{time}},
P^{\mathrm{provenance}}
\right).
\]

Each concept node contains:

* Concept embedding.
* Type.
* Confidence.
* Usage count.
* Temporal validity.
* Source episodes.
* Associated actions and affordances.

Each relation edge contains:

* Source concept.
* Relation type.
* Destination concept.
* Confidence.
* Supporting evidence.
* Contradicting evidence.

Explicit semantic memory permits factual correction without globally rewriting all cortical weights.

---

### 18.4 Procedural memory

A procedural skill is

\[
\omega_k=
\left(
\mathcal I_k,
g_k,
\pi_k,
\beta_k,
\widehat T_k,
Q_k,
C_k,
\kappa_k,
\psi_k
\right),
\]

where:

* (\mathcal I_k): initiation condition.
* (g_k): continuous goal-parameter space.
* (\pi_k): skill policy.
* (\beta_k): termination condition.
* (\widehat T_k): predicted outcome.
* (Q_k): expected value.
* (C_k): expected cost and risk.
* (\kappa_k): competence.
* (\psi_k): skill-specific adaptation state.

Procedural memory supports:

* Skill creation.
* Skill composition.
* Skill parameterization.
* Skill merging.
* Skill splitting.
* Skill freezing.
* Skill retirement.
* Skill replay.

Procedural replay is maintained separately from episodic replay.

---

### 18.5 Prospective memory

Prospective memory stores intended future actions:

\[
m_i^{\mathrm{prospective}}

\left(
\text{goal},
\text{trigger},
\text{deadline},
\text{priority},
\text{context},
\text{status}
\right).
\]

A prospective intention re-enters the workspace when its trigger condition is detected.

---

## 19. Replay and consolidation

Replay occurs during:

* Sleep.
* Rest.
* Low-demand behavior.
* Explicit memory rehearsal.
* Post-event stabilization.
* Background learner updates across training cohorts.

Replay queues are separated into:

* Episodic replay.
* Procedural replay.
* Threat and failure replay.
* Social replay.
* Semantic consolidation.
* Rare-event replay.

Replay selection balances:

* Recency.
* Salience.
* Novelty.
* Failure.
* Skill coverage.
* Age.
* Goal relevance.
* Underrepresented contexts.

Consolidation performs:

* World-model training.
* Semantic extraction.
* Skill distillation.
* Value correction.
* Memory compression.
* Memory merging.
* Synaptic stabilization.
* Removal of redundant records.

During sleep:

* External cortical routing is reduced.
* Motor output is inhibited except for vital and protective circuits.
* Replay allocation increases.
* Semantic and procedural consolidation increases.
* The physical body continues through NumanX.

---

## 20. Homeostasis and motivation

The brain does not optimize one externally assigned reward scalar.

The physical physiology state is owned by NumanX. NumiBrain estimates it and derives drives.

The drive vector is

\[
D_t=
\begin{bmatrix}
d_t^{\mathrm{energy}}\
d_t^{\mathrm{hydration}}\
d_t^{\mathrm{oxygen}}\
d_t^{\mathrm{temperature}}\
d_t^{\mathrm{fatigue}}\
d_t^{\mathrm{pain}}\
d_t^{\mathrm{injury}}\
d_t^{\mathrm{sleep}}\
d_t^{\mathrm{curiosity}}\
d_t^{\mathrm{social}}\
d_t^{\mathrm{task}}\
d_t^{\mathrm{safety}}
\end{bmatrix}.
\]

Each physiological drive has a viable interval (\mathcal I_i).

Define

\[
\Phi_D(D_t)

\sum_i
q_i
\operatorname{dist}
\left(
d_{i,t},
\mathcal I_i
\right)^2.
\]

The homeostatic reinforcement signal is

\[
r_t^{\mathrm{homeo}}

\Phi_D(D_{t+1})

\Phi_D(D_t)

c_t^{\mathrm{damage}}

c_t^{\mathrm{effort}}.
\]

The complete reinforcement vector remains factored until action evaluation:

\[
r_t=
\left(
r_t^{\mathrm{homeo}},
r_t^{\mathrm{task}},
r_t^{\mathrm{social}},
r_t^{\mathrm{information}},
r_t^{\mathrm{pain}},
r_t^{\mathrm{effort}},
r_t^{\mathrm{risk}}
\right).
\]

The planner predicts the complete future drive trajectory instead of receiving one compressed motivation scalar.

---

## 21. Information-seeking behavior

Curiosity reward is based on expected reduction in epistemic uncertainty:

\[
r_t^{\mathrm{information}}

I
\left(
\Theta;
O_{t+1}
\mid
O_{\le t},
a_t
\right).
\]

Equivalent implementation signals include:

* Reduction in dynamics-head disagreement.
* Reduction in posterior entropy.
* Improved entity identity confidence.
* Improved affordance confidence.
* Improved body-model confidence.

Aleatoric uncertainty is excluded from curiosity reward.

The agent explores when:

* It is physiologically safe.
* No higher-priority goal dominates.
* Expected information gain is high.
* Expected damage risk is low.
* The information is relevant to current or prospective goals.

---

## 22. Neuromodulatory system

The functional neuromodulatory vector is

\[
N_t=
\left(
\delta_t^{\mathrm{value}},
\epsilon_t^{\mathrm{model}},
n_t^{\mathrm{novelty}},
u_t^{\mathrm{epistemic}},
p_t^{\mathrm{pain}},
r_t^{\mathrm{threat}},
a_t^{\mathrm{arousal}},
s_t^{\mathrm{satiety}},
q_t^{\mathrm{social}},
f_t^{\mathrm{fatigue}},
z_t^{\mathrm{sleep}},
c_t^{\mathrm{control}}
\right).
\]

Each region has a receptor matrix

\[
R_r
\]

that maps the global modulatory vector into local effects on:

* Learning rate.
* Update gain.
* Route threshold.
* Intrinsic timescale.
* Memory write strength.
* Action vigor.
* Exploration temperature.
* Plasticity decay.
* Inhibition.

The same global event can therefore produce different effects in different regions.

Pain is not only a negative reward. It directly affects:

* Emergency withdrawal.
* Attention.
* Memory write.
* Risk prediction.
* Body-schema vulnerability.
* Exploration suppression.
* Arousal.
* Future planning.

Affective state is a derived configuration of drives, predicted prospects and neuromodulation. It is broadcast through workspace tokens and influences behavior without becoming a separate authoritative reward function.

---

## 23. Goal generation

Goals originate from:

* Physiological drives.
* External tasks.
* Prospective memory.
* Social requests.
* Curiosity.
* Threat avoidance.
* Active plans.
* Communication.
* Learned long-term preferences.

A goal is

\[
g_t=
\left(
\text{target state},
\text{priority},
\text{deadline},
\text{success condition},
\text{failure condition},
\text{risk budget},
\text{persistence}
\right).
\]

Competing goals are maintained simultaneously. The workspace contains the active goal and the most relevant suppressed goals.

Goal switching includes:

* Urgency.
* Expected value.
* Interruption cost.
* Current progress.
* Threat.
* Physiological condition.
* Social priority.
* Prospective deadline.

---

## 24. Dynamic skill proposal

The action repertoire is not a fixed list of 256 behaviors.

The procedural library is expandable. At each decision time, the candidate generator proposes at most

\[
K_{\mathrm{candidate}}=32
\]

active options.

Candidate generation uses:

\[
\mathcal O_t

\operatorname{Propose}
\left(
W_t,
\Xi_t,
D_t,
\operatorname{Affordances}(\Xi_t),
\operatorname{Retrieve}(\mathcal M_t),
\mathcal M_t^P
\right).
\]

Candidates can include:

* Continue active behavior.
* Stop.
* Withdraw.
* Orient.
* Look.
* Listen.
* Reach.
* Grasp.
* Release.
* Step.
* Walk.
* Run.
* Climb.
* Rest.
* Eat.
* Explore.
* Communicate.
* Retrieve memory.
* Start planning.
* Execute a learned multi-step skill.

Skill parameters specify target object, direction, speed, force, duration, posture and other continuous goals.

---

## 25. Basal-ganglia-style action selection

For option (\omega_k), compute

\[
\begin{aligned}
S_k
={}&
Q_k^{\mathrm{task}}
+
Q_k^{\mathrm{homeo}}
+
Q_k^{\mathrm{social}}
+
\beta_I I_k
\
&-
\lambda_R
\operatorname{CVaR}_\alpha
\left(
C_k^{\mathrm{damage}}
\right)

C_k^{\mathrm{effort}}
\
&-
C_k^{\mathrm{switch}}
+
B_k^{\mathrm{persistence}}
+
B_k^{\mathrm{competence}}.
\end{aligned}
\]

The direct channel promotes selected options.

The indirect channel suppresses competing options.

The hyperdirect channel stops all current options when:

* Critical pain arrives.
* Tissue damage becomes imminent.
* Support is lost.
* A collision risk crosses the emergency boundary.
* A physiological variable becomes critical.
* A runtime safety condition is triggered.

The selected option is

\[
\omega_t^\star

\operatorname{Select}
\left(
S_1,\ldots,S_K;
T_t
\right),
\]

where exploration temperature (T_t) depends on uncertainty, arousal, competence and developmental stage.

Option persistence prevents oscillation. A new option must exceed the current option by the configured switching margin unless an interrupt occurs.

---

## 26. Habit, reflex and planning arbitration

NumiBrain has three control modes.

Reflex mode

Activated by immediate events.

Latency class:

\[
1\text{–}5\text{ ms}.
\]

Procedural mode

Executes a known skill with high competence.

Latency class:

\[
20\text{–}40\text{ ms}.
\]

Planning mode

Uses the world model when:

* The situation is novel.
* The active skill has low competence.
* Goals conflict.
* Risk is high.
* A required outcome is delayed.
* The environment changed.
* A previous attempt failed.
* The agent is explicitly asked to plan.

The arbitration score is

\[
A_{\mathrm{mode}}

f
\left(
\text{urgency},
\text{competence},
\text{uncertainty},
\text{risk},
\text{planning cost},
\text{available time}
\right).
\]

Fast reflexes always retain interrupt authority.

---

## 27. Latent planning

Planning operates over parameterized options, not raw muscle activations.

A plan is

\[
\pi_{t:t+H}^{\mathrm{plan}}

\left(
\omega_t,g_t^\omega,
\omega_{t+1},g_{t+1}^\omega,
\ldots
\right).
\]

Candidate plans are proposed from:

* Current policy prior.
* Retrieved episodes.
* Semantic rules.
* Current affordances.
* Previously successful plans.
* Novel combinations of skills.

The world model simulates each candidate:

\[
\widehat X_{t:t+H},
\widehat D_{t:t+H},
\widehat C_{t:t+H}^{\mathrm{risk}}
\sim
p_\theta
\left(
\cdot
\mid
X_t,
\pi_{t:t+H}^{\mathrm{plan}}
\right).
\]

The plan objective is

\[
\begin{aligned}
J(\pi)
={}&
\mathbb E
\left[
\sum_{k=0}^{H}
\gamma^k
\left(
r_{t+k}^{\mathrm{homeo}}
+
r_{t+k}^{\mathrm{task}}
+
r_{t+k}^{\mathrm{social}}
+
r_{t+k}^{\mathrm{information}}

r_{t+k}^{\mathrm{effort}}
\right)
\right]
\
&-
\lambda_R
\operatorname{CVaR}{\alpha}
\left(
C{t:t+H}^{\mathrm{damage}}
\right)
\
&-
\lambda_U
U_{t:t+H}^{\mathrm{unsupported}}

\lambda_S
C_{t:t+H}^{\mathrm{switch}}.
\end{aligned}
\]

The selected plan executes only its first option before replanning.

Successful repeated plans are distilled into procedural skills.

---

## 28. Skill formation

A new skill is created when a repeated action sequence has:

* A stable initiation context.
* A repeatable outcome.
* Predictable termination.
* Better execution cost than deliberate replanning.
* Sufficient demonstration or self-generated examples.

Skill formation performs:

1. Segment successful behavior.
2. Infer a reusable goal parameterization.
3. Train an option policy.
4. Train initiation and termination models.
5. Train an option-level outcome model.
6. Estimate competence and risk.
7. Add the option to procedural memory.
8. Replay it across relevant body and environment variations.
9. Distil or merge it with overlapping skills.

Skills retain a world-model fallback when execution deviates from their competence region.

---

## 29. Motor hierarchy

The complete somatic hierarchy is

\[
\boxed{
\text{goal}
\rightarrow
\text{option}
\rightarrow
\text{task-space target}
\rightarrow
\text{reference movement}
\rightarrow
\text{muscle synergy}
\rightarrow
\text{cerebellar residual}
\rightarrow
\text{spinal and reflex control}
\rightarrow
\text{muscle excitation}.
}
\]

---

## 30. Motor cortex

The motor-goal transform produces

\[
g_t^{\mathrm{motor}}

\left(
x_t^\star,
v_t^\star,
F_t^\star,
K_t^\star,
D_t^\star,
T_t^\star,
c_t^{\mathrm{synergy}}
\right),
\]

where:

* (x_t^\star): desired task-space state.
* (v_t^\star): desired velocity.
* (F_t^\star): force target.
* (K_t^\star): stiffness target.
* (D_t^\star): damping target.
* (T_t^\star): movement timing.
* (c_t^{\mathrm{synergy}}): descending synergy coefficients.

Motor cortex uses the current belief state, not authoritative physics:

\[
g_t^{\mathrm{motor}}

\pi_{\mathrm{motor}}
\left(
\Xi_t,
W_t,
\omega_t^\star
\right).
\]

Co-contraction is controlled explicitly through stiffness and synergy commands.

---

## 31. Cerebellar system

The cerebellum uses a mixture of predictive experts.

The first configuration has

\[
K_C=128
\]

experts with

\[
K_C^{\mathrm{active}}=4
\]

active experts per context.

The context selector computes

\[
\alpha_{k,t}^{C}

\operatorname{TopKSoftmax}
\left(
g_k^C
\left(
X_t^{\mathrm{self}},
g_t^{\mathrm{motor}},
\omega_t^\star
\right)
\right).
\]

Each active forward expert predicts delayed sensory and motor consequences:

\[
\widehat y_{t+\Delta}^{(k)}

C_k^{\mathrm{forward}}
\left(
X_t^{\mathrm{self}},
g_t^{\mathrm{motor}},
u_t
\right).
\]

The combined prediction is

\[
\widehat y_{t+\Delta}

\sum_k
\alpha_{k,t}^C
\widehat y_{t+\Delta}^{(k)}.
\]

When delayed feedback arrives,

\[
\epsilon_{t+\Delta}^{C}

y_{t+\Delta}

\widehat y_{t+\Delta}.
\]

The inverse experts produce corrections:

\[
\Delta u_t^C

\sum_k
\alpha_{k,t}^C
C_k^{\mathrm{inverse}}
\left(
X_t^{\mathrm{self}},
g_t^{\mathrm{motor}},
\epsilon_t^C
\right).
\]

Cerebellar learning is fast, local and strongly driven by delayed prediction error.

The cerebellum handles:

* Timing correction.
* Force correction.
* Balance correction.
* Adaptation to body changes.
* Sensorimotor calibration.
* Predictive cancellation of self-generated sensory events.
* Rapid refinement of learned skills.

---

## 32. Brainstem

Brainstem systems control:

* Orientation toward salient stimuli.
* Posture.
* Righting.
* Startle.
* Gaze stabilization.
* Protective withdrawal.
* Breathing.
* Autonomic regulation.
* Sleep and wake transitions.
* Basic ingestive behavior.

Brainstem controllers operate even when cortical processing is reduced or invalid.

---

## 33. Spinal system

The spinal controller receives:

* Descending synergy commands.
* Muscle spindle signals.
* Tendon-force signals.
* Joint receptor signals.
* Skin contact.
* Nociception.
* Vestibular correction.
* CPG phase.
* Cerebellar residual.

The final muscle excitation is

\[
\boxed{
u_t^{\mathrm{muscle}}

\operatorname{clip}
\left(
D_{\mathrm{synergy}}c_t^{\mathrm{synergy}}
+
u_t^{\mathrm{CPG}}
+
u_t^{\mathrm{reflex}}
+
\Delta u_t^{C}
+
u_t^{\mathrm{brainstem}},
0,1
\right).
}
\]

Spinal reflexes include:

* Stretch reflex.
* Tendon unloading.
* Withdrawal.
* Crossed extension.
* Load compensation.
* Contact stabilization.
* Joint-limit protection.
* Vestibulospinal correction.
* Pain-dependent inhibition.
* Muscle-overload inhibition.

CPGs control rhythmic behavior only. They do not replace general voluntary movement.

Species templates define CPG oscillator topology, phase relations and sensory reset rules.

---

## 34. Muscle and actuator interface

NumiBrain outputs excitation:

\[
u_i^{\mathrm{muscle}}
\in[0,1].
\]

NumanX owns muscle activation dynamics:

\[
\dot a_i

\frac{
u_i^{\mathrm{muscle}}-a_i
}{
\tau_i
\left(
u_i^{\mathrm{muscle}}
\right)
}.
\]

NumanX also owns:

* Force–length behavior.
* Force–velocity behavior.
* Tendon elasticity.
* Passive tissue force.
* Fatigue.
* Metabolic cost.
* Tissue damage.
* Joint and contact dynamics.

For robotic bodies, a species adapter maps neural output to:

* Motor current.
* Torque.
* Velocity.
* Position.
* Impedance.
* Pressure.
* Other actuator-specific control.

The robot adapter preserves the same motor hierarchy and sensory feedback contract.

---

## 35. Autonomic control

The autonomic output is

\[
u_t^{\mathrm{autonomic}}

\pi_{\mathrm{autonomic}}
\left(
\Xi_t^{\mathrm{physiology}},
D_t,
N_t,
W_t
\right).
\]

It may control:

* Ventilation amplitude and frequency.
* Heart-rate target.
* Blood-flow allocation.
* Thermoregulatory actions.
* Pupil response.
* Digestive allocation.
* Stress-response intensity.
* Rest and sleep state.

NumanX advances the corresponding reduced or detailed physiological model.

The resulting interoceptive consequences return through sensor transduction.

---

## 36. Fast plasticity

A full independent per-agent copy of every synaptic weight is prohibited.

Fast adaptation uses a low-dimensional shared basis.

For region (r),

\[
\Theta_{r,t}^{\mathrm{effective}}

\Theta_r
+
\sum_{\ell=1}^{L_r}
f_{r\ell,t}B_{r\ell}.
\]

Eligibility traces are

\[
e_{r\ell,t}

\lambda_{r\ell}e_{r\ell,t-1}
+
\phi_{r\ell}
\left(
H_{r,t}^{\mathrm{pre}},
H_{r,t}^{\mathrm{post}}
\right).
\]

Fast coefficients update through

\[
f_{r\ell,t+1}

\operatorname{clip}
\left[
\rho_{r\ell}f_{r\ell,t}
+
\eta_{r\ell}
\left(
R_rN_t
\right)\ell
e{r\ell,t},
-f_{\max},
f_{\max}
\right].
\]

The first complete configuration uses

\[
2{,}048\text{–}8{,}192
\]

fast-plastic coefficients per agent.

Fast plasticity supports:

* Immediate sensor calibration.
* Short-term motor adaptation.
* Temporary associations.
* Context adaptation.
* Rapid recovery after body change.
* Within-episode learning.

Stable repeated fast adaptations are consolidated into slow weights or explicit memory.

---

## 37. Slow learning objective

The complete slow-learning objective is

\[
\begin{aligned}
\mathcal L_{\mathrm{brain}}
={}&
\lambda_{\mathrm{obs}}
\mathcal L_{\mathrm{observation}}
+
\lambda_{\mathrm{belief}}
\mathcal L_{\mathrm{belief}}
+
\lambda_{\mathrm{world}}
\mathcal L_{\mathrm{world}}
\
&+
\lambda_{\mathrm{body}}
\mathcal L_{\mathrm{body}}
+
\lambda_{\mathrm{agency}}
\mathcal L_{\mathrm{agency}}
+
\lambda_{\mathrm{event}}
\mathcal L_{\mathrm{event}}
\
&+
\lambda_{\mathrm{drive}}
\mathcal L_{\mathrm{drive}}
+
\lambda_{\mathrm{value}}
\mathcal L_{\mathrm{value}}
+
\lambda_{\mathrm{risk}}
\mathcal L_{\mathrm{risk}}
\
&+
\lambda_{\mathrm{policy}}
\mathcal L_{\mathrm{policy}}
+
\lambda_{\mathrm{option}}
\mathcal L_{\mathrm{option}}
+
\lambda_{\mathrm{cerebellar}}
\mathcal L_{\mathrm{cerebellar}}
\
&+
\lambda_{\mathrm{episodic}}
\mathcal L_{\mathrm{episodic}}
+
\lambda_{\mathrm{semantic}}
\mathcal L_{\mathrm{semantic}}
+
\lambda_{\mathrm{procedural}}
\mathcal L_{\mathrm{procedural}}
\
&+
\lambda_{\mathrm{imitation}}
\mathcal L_{\mathrm{imitation}}
+
\lambda_{\mathrm{route}}
\mathcal L_{\mathrm{route}}
+
\lambda_{\mathrm{sparse}}
\mathcal L_{\mathrm{sparsity}}
\
&+
\lambda_{\mathrm{stability}}
\mathcal L_{\mathrm{stability}}
+
\lambda_{\mathrm{plasticity}}
\mathcal L_{\mathrm{plasticity}}.
\end{aligned}
\]

Observation loss

Reconstructs and predicts receptor observations.

Belief loss

Matches posterior and prior while preserving useful latent information.

World loss

Predicts future latent states across multiple horizons.

Body loss

Predicts proprioception, touch, force, support and self-motion.

Agency loss

Distinguishes self-generated and externally generated events.

Event loss

Predicts event type, time-to-event and severity.

Drive loss

Predicts physiological and motivational consequences.

Value loss

Learns factored expected returns.

Risk loss

Learns a distribution over damage and failure outcomes.

Policy loss

Optimizes risk-constrained expected return.

Option loss

Trains initiation, termination, outcome and competence models.

Cerebellar loss

Predicts delayed sensory consequences and corrective residuals.

Episodic loss

Trains boundary detection, retrieval, reconstruction and relevance.

Semantic loss

Trains concept and relation extraction.

Procedural loss

Trains reusable skill execution and composition.

Imitation loss

Learns from observed behavior and demonstrations.

Route loss

Enforces route budget, persistence and capacity balance.

Sparsity loss

Limits active modules, routes and experts.

Stability loss

Protects consolidated knowledge.

Plasticity loss

Meta-learns useful fast-plasticity bases and update rules.

---

## 38. Long-term stability

NumiBrain prevents catastrophic forgetting through:

* Balanced replay across old and new skills.
* Semantic consolidation.
* Procedural skill freezing after mastery.
* Synaptic-importance tracking.
* Region-specific plastic adapters.
* Versioned target networks.
* Separate fast and slow plasticity.
* Skill competence monitoring.
* Rehearsal after major updates.
* Explicit memory rather than weight-only storage.

For protected parameter (\theta_i^\star), use

\[
\mathcal L_{\mathrm{stability}}

\sum_i
\Omega_i
\left(
\theta_i-\theta_i^\star
\right)^2,
\]

where (\Omega_i) measures importance to consolidated skills and knowledge.

A skill whose performance degrades is automatically returned to procedural replay.

---

## 39. Learning data policy

Only committed physical transitions enter learning data.

A committed transition contains:

\[
\left(
B_t,
O_t,
E_t,
a_t,
S_{t+1}^{\mathrm{teacher}},
O_{t+1},
E_{t+1},
B_{t+1},
r_t,
\text{metadata}
\right).
\]

The teacher state is optional and isolated from the agent input graph.

Training data are partitioned into:

* Recent real transitions.
* Long-term balanced replay.
* Rare-event replay.
* High-salience replay.
* Procedural replay.
* Demonstration data.
* Social-interaction data.
* Imagined trajectories.

Imagined trajectories are marked separately and never inserted into episodic memory as lived experiences.

---

## 40. Training update cycle

Each learner update performs:

1. Sample committed sequence segments.
2. Reconstruct recurrent burn-in state.
3. Update sensory encoders and belief posterior.
4. Train multi-horizon world dynamics.
5. Train contact, pain, drive and event predictions.
6. Start imagined trajectories from posterior states.
7. Train value and risk distributions.
8. Train the actor and option selector.
9. Train skill initiation, termination and outcome models.
10. Train cerebellar forward and inverse experts.
11. Train episodic boundary, retrieval and reconstruction.
12. Consolidate semantic and procedural knowledge.
13. Apply stability and sparsity terms.
14. Publish a new immutable parameter version.

Rollout environments switch to the new parameter version only at an allowed synchronization boundary.

---

## 41. Developmental architecture

Development changes both the environment and the learner.

The maturation program is

\[
\mu
\left(
A_t^{\mathrm{dev}}
\right)

\left(
\eta_r,
\tau_r,
G_r,
\ell_r,
\sigma_r,
s_r,
\zeta_r,
c_r
\right),
\]

controlling:

* Regional learning rates.
* Intrinsic timescales.
* Available routes.
* Conduction delays.
* Sensor precision.
* Muscle strength.
* Replay allocation.
* Regional capacity.

Development includes:

* Critical periods.
* Gradual route opening.
* Sensory refinement.
* Motor-strength growth.
* Reduced initial movement precision.
* High early plasticity.
* Later synaptic stabilization.
* Experience-dependent pruning.
* Increasing planning horizon.
* Increasing working-memory capacity.
* Increasing semantic consolidation.

---

## 42. Complete development sequence

Stage 0: innate scaffold

Active systems:

* Vital autonomic control.
* Withdrawal.
* Joint protection.
* Startle.
* Basic righting.
* Vestibular stabilization.
* Pain routing.
* Rest and sleep control.

The scaffold is functional before learned cortical control.

Stage 1: spontaneous movement

The body produces low-amplitude structured spontaneous activity through:

* CPG fragments.
* Muscle twitches.
* Reflex coupling.
* Randomized synergy activation.
* Gaze and head movements.

The brain learns correlations between motor command, proprioception, touch and vision.

Stage 2: body-schema formation

The agent learns:

* Limb ownership.
* Joint effects.
* Muscle effects.
* Reachable space.
* Support geometry.
* Self-generated sensation.
* External disturbance.
* Body-centered coordinates.

Stage 3: cerebellar calibration

The agent learns:

* Motor timing.
* Force correction.
* Balance correction.
* Sensor delay.
* Efference-copy prediction.
* Rapid adaptation.

Stage 4: posture and locomotion

The agent develops:

* Stable posture.
* Recovery from perturbation.
* Standing.
* Stepping.
* Walking.
* Turning.
* Running or species-equivalent locomotion.
* Falling safely.
* Standing up.

Stage 5: manipulation and active sensing

The agent develops:

* Reaching.
* Grasping.
* Releasing.
* Palpation.
* Tool interaction.
* Gaze control.
* Object inspection.
* Coordinated eye, head and hand behavior.

Stage 6: object and scene understanding

The agent learns:

* Object permanence.
* Occlusion.
* Support.
* Containment.
* Collision.
* Material behavior.
* Affordances.
* Spatial maps.
* Causal interactions.

Stage 7: episodic and procedural memory

The agent develops:

* Event segmentation.
* One-shot storage.
* Contextual retrieval.
* Skill replay.
* Prospective intentions.
* Semantic consolidation.

Stage 8: planning and autonomous behavior

The agent develops:

* Multi-step goals.
* Detour planning.
* Exploration.
* Risk-sensitive action.
* Rest and recovery.
* Long-horizon option sequencing.
* Reuse of past experience.

Stage 9: social development

The agent develops:

* Attention to other agents.
* Gaze following.
* Joint attention.
* Imitation.
* Turn-taking.
* Social value learning.
* Goal inference.
* Cooperative and competitive behavior.

Stage 10: communication and language

Human-like templates add:

* Speech perception.
* Vocal or gestural control.
* Word and concept binding.
* Instruction following.
* Question answering.
* Narrative memory.
* Compositional communication.
* Abstract planning through language.

Stage 11: open-ended life

The agent continues:

* Online adaptation.
* Skill formation.
* Memory consolidation.
* Social learning.
* Tool use.
* Environment exploration.
* Preference development.
* Recovery from physical change.
* Protection of consolidated abilities.

Stage progression is capability-gated. It is not based only on elapsed training steps.

---

## 43. Social and imitation system

Other agents are represented as persistent agent slots.

The social model predicts:

\[
p
\left(
a_{j,t+1},
g_{j,t+1},
r_{j,t+1}^{\mathrm{social}}
\mid
X_t,
\text{history}_j
\right).
\]

Imitation proceeds through:

1. Observe another body.
2. Infer its body-relative movement.
3. Infer the likely goal.
4. Map the movement to the learner’s morphology.
5. Predict expected sensory and task consequences.
6. Execute through the learner’s motor hierarchy.
7. Correct through cerebellar error.
8. Store successful execution as procedural memory.

The learner copies goals and movement structure, not raw joint coordinates.

Joint attention binds:

* Another agent.
* Its gaze or orientation.
* A referenced object.
* The learner’s own workspace.

---

## 44. Communication and language

Communication is implemented as sensory, motor, memory and social behavior.

Inputs can include:

* Speech audio.
* Facial movement.
* Gesture.
* Text or symbols in the environment.
* Touch.
* Species-specific signals.

Outputs can include:

* Vocal-tract control.
* Gesture.
* Facial movement.
* Sign.
* Written symbols.
* Robotic communication channels.

The communication module binds symbols to:

* Objects.
* Actions.
* Goals.
* Relations.
* Memories.
* Social states.
* Internal drives.

A privileged token stream may be used as a training target. The deployed embodied agent receives communication through its configured sensory channels unless the species template explicitly includes a direct symbolic interface.

---

## 45. Transactional coupling to NumanX

NumiBrain and NumanX share one causal transaction.

At the start of control interval (t):

\[
T_t^{\mathrm{root}}

\operatorname{BeginJointTransaction}
\left(
S_t,
B_t,
\Theta^{(v)}
\right).
\]

### 45.1 Neural decision shadow step

NumiBrain transduces committed observations and creates a shadow decision state:

\[
\left(
\widetilde B_t^{\mathrm{decision}},
a_t
\right)

\operatorname{InferAndDecide}
\left(
B_t,
O_t,
E_t;
\xi_t
\right).
\]

The random stream (\xi_t) is counter-based and deterministic.

The selected high-level decision is cached.

### 45.2 Nested physical substep

For physical substep (k):

\[
T_{t,k}^{\mathrm{sub}}

\operatorname{BeginSubstep}
\left(
\widetilde S_{t,k},
\widetilde B_{t,k}
\right).
\]

Fast neural systems advance with the candidate physical substep:

\[
\widetilde B_{t,k+1}^{\mathrm{fast}}

\operatorname{AdvanceFastBrain}
\left(
\widetilde B_{t,k},
\widetilde E_{t,k},
\delta_k
\right).
\]

NumanX advances using the resulting muscle and autonomic commands:

\[
\widetilde S_{t,k+1}

\operatorname{NumanXShadowStep}
\left(
\widetilde S_{t,k},
u_{t,k}^{\mathrm{muscle}},
u_{t,k}^{\mathrm{autonomic}},
\delta_k
\right).
\]

### 45.3 Substep rejection

If NumanX rejects the candidate:

\[
\widetilde S_{t,k+1}
\leftarrow
\varnothing,
\]

\[
\widetilde B_{t,k+1}^{\mathrm{fast}}
\leftarrow
\varnothing.
\]

NumiBrain restores the previous accepted shadow checkpoint.

The following remain unchanged:

* High-level action.
* Active option.
* Plan.
* Random samples.
* Random counters.
* Episodic write intent.
* Decision-state computation.

NumanX retries with a corrected physical substep.

### 45.4 Substep acceptance

An accepted substep advances the root shadow state but does not yet publish it globally.

### 45.5 Root commit

After the full control interval is accepted:

\[
\boxed{
(S_{t+1},B_{t+1})

\operatorname{AtomicJointCommit}
\left(
\widetilde S_{t+1},
\widetilde B_{t+1}
\right).
}
\]

The commit includes:

* Recurrent state.
* Belief posterior.
* Workspace.
* Event history.
* Delay buffers.
* CPG phases.
* Cerebellar state.
* Drives.
* Pain.
* Neuromodulation.
* Eligibility traces.
* Fast-plastic coefficients.
* Pending episodic records.
* Procedural competence updates.
* Memory allocator changes.
* Random counters.

### 45.6 Root abort

If the entire control interval fails:

\[
S_{t+1}=S_t,
\qquad
B_{t+1}=B_t.
\]

No learning transition is emitted.

### 45.7 Slow learner isolation

Slow shared parameters are updated only from committed rollout data:

\[
\Theta^{(v+1)}

\operatorname{Learn}
\left(
\Theta^{(v)},
\mathcal D_{\mathrm{committed}}^{(v)}
\right).
\]

An individual environment cannot mutate shared weights during its physical transaction.

---

## 46. Transaction implementation

The runtime uses generation-based double buffering.

Committed generation

Contains the last globally accepted state.

Shadow generation

Contains candidate updates for the current root transaction.

Fast-substep checkpoint

Contains only state modified by fast neural modules during the current physical candidate.

Large memories are not copied every step.

Instead:

* Recurrent state uses ping-pong buffers.
* Fast plasticity uses ping-pong buffers.
* Workspace uses generation tags.
* Episodic writes use an append-only pending journal.
* Semantic changes use a sparse mutation journal.
* Procedural updates use a sparse competence journal.
* Event queues use committed and shadow offsets.
* Memory indexes are updated only on commit.

Commit swaps generation pointers and applies journals.

Abort discards the shadow generation and journals.

---

## 47. Determinism

Random generation is keyed by

\[
\left(
\text{environment},
\text{episode},
\text{control step},
\text{module},
\text{sample index}
\right).
\]

Physical retries do not change the key.

Deterministic replay restores:

* Parameter version.
* Committed brain checkpoint.
* Committed physical checkpoint.
* Event sequence.
* Random counters.
* Developmental state.
* Memory generation.
* Scheduler timestamps.

---

## 48. Apple GPU execution model

NumiBrain uses three main compute forms.

Dense regional computation

Used for:

* Local recurrent updates.
* Sensor encoders.
* World-model projections.
* Workspace projections.
* Policy and value computation.
* Cerebellar experts.

Execution uses tiled dense tensor operations with BF16 or FP16 storage and FP32 accumulation.

Block-sparse communication

Used for:

* Inter-region message transfer.
* Entity relations.
* Body graph operations.
* Semantic graph operations.
* Active option evaluation.
* Sparse expert selection.

Execution uses compacted block-sparse gather, matrix operation and scatter kernels.

Event processing

Used for:

* Contact events.
* Pain events.
* Sensor transients.
* Reflex activation.
* Module scheduling.
* Episodic boundaries.
* Transaction journals.

Execution uses compact GPU queues, prefix sums and indirect dispatch.

---

## 49. GPU pipeline

The control-tick pipeline is

\[
\boxed{
\begin{aligned}
&\text{NumanX sensor extraction}
\
\rightarrow{}&
\text{receptor transduction}
\
\rightarrow{}&
\text{event compaction}
\
\rightarrow{}&
\text{due-module selection}
\
\rightarrow{}&
\text{belief posterior update}
\
\rightarrow{}&
\text{route and token selection}
\
\rightarrow{}&
\text{regional dense computation}
\
\rightarrow{}&
\text{workspace update}
\
\rightarrow{}&
\text{memory retrieval}
\
\rightarrow{}&
\text{goal and option arbitration}
\
\rightarrow{}&
\text{motor and autonomic output}
\
\rightarrow{}&
\text{NumanX shadow integration}
\
\rightarrow{}&
\text{fast reflex and cerebellar loop}
\
\rightarrow{}&
\text{joint commit or rollback}.
\end{aligned}
}
\]

---

## 50. GPU data layout

Active state is stored region-major:

\[
H_r
\in
\mathbb R^{B_r\times n_r\times d_r}.
\]

This batches the same module across environments.

Execution grouping is

\[
\boxed{
\text{module type}
\rightarrow
\text{clock class}
\rightarrow
\text{shape}
\rightarrow
\text{precision}
\rightarrow
\text{active environment cohort}.
}
\]

Primary buffers include:

* Regional state buffers.
* Regional delay-ring buffers.
* Observation buffers.
* Event-token buffers.
* Route-index buffers.
* Workspace buffers.
* Belief-state buffers.
* Entity-slot buffers.
* Body-graph buffers.
* Fast-plasticity buffers.
* Episodic active-store buffers.
* Semantic graph buffers.
* Procedural library buffers.
* Motor-command buffers.
* Transaction-generation buffers.
* Committed rollout buffers.

Use:

* BF16 or FP16 for normal activations.
* FP32 accumulation.
* FP32 normalization.
* FP32 value, risk and uncertainty calculations.
* FP32 workspace scores.
* FP32 neuromodulatory values.
* INT8 or compact codes for inactive episodic archives.
* Integer event tokens.
* Counter-based random generation.

The hot path performs no CPU readback.

---

## 51. Active-module compaction

Not every logical module executes for every environment at every tick.

For each clock class:

1. Mark due environments.
2. Mark event-interrupted environments.
3. Compact active environment identifiers.
4. Group by module shape.
5. Dispatch dense regional kernels.
6. Scatter state back to region-major buffers.

Event-dominated modules may execute only for environments with relevant events.

This prevents inactive cognitive regions from consuming full-cohort compute.

---

## 52. Sparse route execution

Routing is executed in four stages:

1. Generate candidate route scores.
2. Select top-(k) senders per receiving module.
3. Compact selected route blocks.
4. Perform gathered projection and accumulation.

Route persistence reduces selection churn.

Emergency routes are preallocated.

The semantic graph and body graph use similar compacted edge kernels.

---

## 53. Memory execution on Apple unified memory

The active memory set remains GPU resident.

Persistent memory uses three tiers:

Hot exact set

Contains 4,096–16,384 full-resolution records.

Warm compressed set

Contains quantized records in unified memory.

Archive

Contains up to approximately 1,048,576 compressed records for a persistent agent.

Retrieval uses:

1. Query projection.
2. Coarse cluster scoring.
3. Selection of a small number of clusters.
4. Approximate scoring inside selected clusters.
5. Exact reranking of top candidates.
6. Full record reconstruction.

Archive paging is asynchronous with respect to the active control loop. A memory not available before the retrieval deadline is deferred rather than blocking motor control.

---

## 54. Production execution profiles

NumiBrain uses one architecture with three production profiles.

### 54.1 Large motor-development profile

Purpose:

* Body-schema learning.
* Balance.
* Locomotion.
* Manipulation.
* Cerebellar calibration.
* Large-scale robustness training.

Configuration:

\[
B=8{,}192\text{–}12{,}288
\]

environments.

Per environment:

* 4,096–8,192 recurrent state values.
* 8 workspace tokens.
* 16–32 short episodic segments.
* Reduced entity and planner capacity.
* Full spinal, cerebellar and body systems.
* Shared 128-million-parameter model.

### 54.2 Full cognitive-development profile

Purpose:

* Object permanence.
* Memory.
* Planning.
* Social behavior.
* Communication.
* Long event sequences.

Configuration:

\[
B=512\text{–}2{,}048
\]

environments.

Per environment:

* 16,384–32,768 recurrent state values.
* 16 workspace tokens of dimension 256.
* 32 active object slots.
* 8 active other-agent slots.
* 64–128 episodic event segments.
* Full option planning.
* Full semantic and procedural systems.

### 54.3 Persistent-agent profile

Purpose:

* Long-lived embodied agents.
* Open-ended development.
* Long-term memory.
* Individual adaptation.

Configuration:

\[
B=1\text{–}32.
\]

Per agent:

* Up to 65,536 active recurrent state values.
* 16–32 workspace tokens.
* Thousands of active episodic records.
* Large compressed archive.
* Full semantic graph.
* Expandable procedural library.
* Persistent individual fast-plastic and developmental state.

---

## 55. First complete production configuration

The first complete cognitive configuration is

\[
\boxed{
\begin{aligned}
R_{\mathrm{logical}} &= 96,\
R_{\mathrm{active/tick}} &= 12\text{–}24,\
|\Theta| &= 128\text{ million shared parameters},\
N_W &= 16,\
d_W &= 256,\
N_{\mathrm{object}} &= 32,\
N_{\mathrm{agent}} &= 8,\
K_{\mathrm{candidate}} &= 32,\
K_C &= 128,\
K_C^{\mathrm{active}} &= 4,\
L_F &= 4{,}096,\
M_E^{\mathrm{training}} &= 64,\
K_{\mathrm{world\ heads}} &= 5.
\end{aligned}
}
\]

The procedural library is expandable and is not limited to the active candidate count.

The 96 modules are functional roles, not 96 dense networks executing continuously.

---

## 56. Runtime input contract

A NumiBrain input packet contains:

Timing

* Committed simulation timestamp.
* Control-step identifier.
* Physical-substep identifier.
* Parameter version.
* Transaction generation.

Sensor views

* Vision buffers.
* Audio buffers.
* Skin receptor buffers.
* Proprioceptor buffers.
* Vestibular buffers.
* Olfactory buffers.
* Gustatory buffers.
* Interoceptive buffers.

Event views

* Event-token offset.
* Event-token count.
* Event timestamps.
* Event validity flags.

Optional teacher data

* Privileged body state.
* Privileged entity state.
* Contact labels.
* Force labels.
* Damage labels.
* Task labels.

Teacher data are marked non-observable and cannot enter the actor or normal belief input path.

---

## 57. Runtime output contract

A NumiBrain output packet contains:

Somatic control

* Muscle excitations.
* Synergy coefficients.
* Impedance targets.
* Movement timing.
* Emergency stop mask.

Autonomic control

* Ventilation command.
* Cardiovascular command.
* Thermoregulatory command.
* Rest-state command.
* Species-specific autonomic outputs.

Active sensing

* Eye targets.
* Head target.
* Ear or pinna target.
* Sniffing command.
* Palpation target.
* Attention-allocation mask.

Internal control

* Active option identifier.
* Option parameters.
* Workspace action.
* Memory retrieval request.
* Planning state.
* Confidence.
* Predicted risk envelope.

Transaction metadata

* Brain transaction token.
* Shadow-generation identifier.
* Random-counter generation.
* Pending-memory journal offset.

---

## 58. Runtime API

The standalone runtime exposes the following logical interface:

NumiBrainHandle CreateBrain(
    BrainConfig,
    SpeciesTemplate,
    ParameterVersion
)
BrainTransaction BeginControl(
    NumiBrainHandle,
    CommittedTimestamp,
    ObservationPacket,
    EventPacket
)
BrainDecision InferAndDecide(
    BrainTransaction
)
FastBrainResult AdvanceFastSystems(
    BrainTransaction,
    PhysicsSubstepEvents,
    CandidateSubstepDuration
)
void AcceptPhysicsSubstep(
    BrainTransaction,
    AcceptedPhysicsStateToken
)
void RejectPhysicsSubstep(
    BrainTransaction
)
CommittedBrainState CommitControl(
    BrainTransaction,
    AcceptedPhysicsStateToken
)
void AbortControl(
    BrainTransaction
)
Checkpoint SaveCheckpoint(
    NumiBrainHandle
)
void LoadCheckpoint(
    NumiBrainHandle,
    Checkpoint
)
ParameterVersion PublishParameters(
    LearnerUpdate
)

NumanX integration uses the transaction token rather than directly mutating NumiBrain buffers.

---

## 59. Repository architecture

The standalone implementation is organized as:

NumiBrain/
├── Core/
│   ├── State
│   ├── Types
│   ├── Config
│   ├── ParameterVersioning
│   └── Determinism
├── Runtime/
│   ├── Scheduler
│   ├── EventQueue
│   ├── Routing
│   ├── Transactions
│   ├── Dispatch
│   └── Checkpointing
├── Sensors/
│   ├── Vision
│   ├── Audition
│   ├── Touch
│   ├── Proprioception
│   ├── Vestibular
│   ├── Olfaction
│   ├── Gustation
│   └── Interoception
├── Belief/
│   ├── BodySchema
│   ├── EntityState
│   ├── AgentState
│   ├── SpatialState
│   ├── Agency
│   └── Uncertainty
├── WorldModel/
│   ├── FastDynamics
│   ├── Sensorimotor
│   ├── Scene
│   ├── Event
│   ├── Abstract
│   └── Counterfactual
├── Workspace/
│   ├── Tokens
│   ├── Broadcast
│   └── Gating
├── Memory/
│   ├── Working
│   ├── Episodic
│   ├── Semantic
│   ├── Procedural
│   ├── Prospective
│   └── Replay
├── Motivation/
│   ├── Homeostasis
│   ├── Pain
│   ├── Curiosity
│   ├── Social
│   ├── Sleep
│   └── Neuromodulation
├── Decision/
│   ├── Goals
│   ├── Affordances
│   ├── Options
│   ├── BasalGanglia
│   ├── Planner
│   └── Arbitration
├── Motor/
│   ├── MotorCortex
│   ├── Cerebellum
│   ├── Brainstem
│   ├── Spinal
│   ├── CPG
│   └── Autonomic
├── Learning/
│   ├── WorldLearning
│   ├── ActorCritic
│   ├── Risk
│   ├── Imitation
│   ├── Plasticity
│   ├── Consolidation
│   └── Stability
├── Species/
│   ├── Human
│   ├── Quadruped
│   ├── Bird
│   ├── GenericRobot
│   └── TemplateCompiler
├── Metal/
│   ├── DenseKernels
│   ├── SparseKernels
│   ├── EventKernels
│   ├── MemoryKernels
│   ├── TransactionKernels
│   └── TensorLayouts
└── Interop/
    ├── NumanX
    ├── NumiLab
    ├── Dataset
    └── Inspection

---

## 60. Species configurations

### 60.1 Human template

Emphasizes:

* Foveal vision.
* Hands.
* Bipedal balance.
* Fine tactile resolution.
* Tool use.
* Vocal control.
* Social cognition.
* Language.
* Long association timescales.
* Large semantic memory.

### 60.2 Quadruped template

Emphasizes:

* Quadruped CPG topology.
* Distributed load sensing.
* Olfaction.
* Fast posture control.
* Terrain adaptation.
* Species-specific gait transitions.
* Head and jaw control.
* Social and territorial behavior.

### 60.3 Bird template

Emphasizes:

* High-resolution vision.
* Wide visual field.
* Fast vestibular processing.
* Wing and tail body graph.
* Flight-stability controller.
* Flapping CPG.
* Perching reflexes.
* Head stabilization.
* Airflow and feather sensing.
* Species-specific vocalization.

### 60.4 Generic robot template

Uses:

* Camera and microphone adapters.
* Joint and force sensors.
* Current and temperature sensing.
* Actuator-specific motor adapter.
* Artificial energy and thermal drives.
* Robot morphology graph.
* Learned or designed safety reflexes.

It retains the same belief, memory, planning and developmental interfaces.

---

## 61. Training environment requirements

A complete developmental environment supplies:

* Stable physical consequences.
* Objects with persistent identity.
* Surfaces and obstacles.
* Manipulable materials.
* Food or energy sources where applicable.
* Rest and recovery opportunities.
* Hazards.
* Novel objects.
* Other agents.
* Caregiver or teacher agents.
* Demonstrations.
* Communication.
* Long-term locations.
* Delayed consequences.
* Morphological and environmental variation.

The environment does not reduce all learning to task score.

The agent must be able to:

* Explore without an active external task.
* Fail safely.
* Repeat actions.
* Observe others.
* Receive contingent social response.
* Rest.
* Sleep.
* Revisit places.
* Encounter changed conditions.
* Develop individual history.

---

## 62. Production build sequence

This sequence builds final architecture components. No phase is a throwaway implementation.

Phase 1: runtime foundation

Implement:

* Brain state ABI.
* Multi-rate scheduler.
* Event queue.
* Regional module primitive.
* Parameter versioning.
* Deterministic random generation.
* Root and nested transactions.
* NumanX buffer interop.

Completion result:

A minimal neural state can advance, roll back and commit with NumanX without CPU copies.

Phase 2: receptor and peripheral system

Implement:

* Proprioception.
* Touch.
* Nociception.
* Vestibular sensing.
* Vision.
* Audition.
* Interoception.
* Event transduction.
* Sensor latency and noise.

Completion result:

The brain receives only causal receptor outputs.

Phase 3: body schema and self-model

Implement:

* Body graph.
* Joint and muscle estimation.
* Support model.
* Self-generated event prediction.
* Pain and vulnerability map.
* Reachability.
* Spatial transforms.

Completion result:

The agent infers its body without privileged state.

Phase 4: spinal, brainstem and cerebellar control

Implement:

* Reflexes.
* CPGs.
* Posture control.
* Muscle synergies.
* Cerebellar forward and inverse experts.
* Autonomic controller.

Completion result:

The agent stabilizes, adapts and controls muscles through the final motor hierarchy.

Phase 5: predictive world model

Implement:

* Posterior inference.
* Multi-timescale latent dynamics.
* Entity slots.
* Scene state.
* Event hazards.
* Drive prediction.
* Risk and uncertainty.

Completion result:

The agent predicts body and environmental consequences.

Phase 6: routing and workspace

Implement:

* Dynamic top-(k) routes.
* Route persistence.
* Emergency bus.
* Workspace tokens.
* Write, hold and clear gates.
* Active-module compaction.

Completion result:

Relevant state is broadcast without activating the entire brain.

Phase 7: homeostasis and autonomous behavior

Implement:

* Physiological drives.
* Curiosity.
* Threat.
* Pain.
* Social drive.
* Sleep pressure.
* Neuromodulator dispatch.
* Factored value system.

Completion result:

The agent initiates behavior from internal state.

Phase 8: procedural options and planning

Implement:

* Affordance proposal.
* Expandable skill library.
* Basal-ganglia arbitration.
* Risk-sensitive critic.
* Latent option planner.
* Habit–planner arbitration.
* Skill distillation.

Completion result:

The agent sequences reusable skills and plans through novel situations.

Phase 9: full memory system

Implement:

* Event segmentation.
* Episodic write and retrieval.
* Reconsolidation.
* Semantic graph.
* Procedural replay.
* Prospective memory.
* Persistent archive.

Completion result:

The agent remembers significant events, generalizes repeated structure and retains skills.

Phase 10: development and social learning

Implement:

* Maturation schedules.
* Critical periods.
* Spontaneous movement.
* Imitation.
* Joint attention.
* Other-agent models.
* Social reinforcement.

Completion result:

Behavior emerges through staged development and interaction.

Phase 11: communication and language

Implement for human-like templates:

* Speech perception.
* Vocal or symbolic output.
* Concept binding.
* Instruction following.
* Language-conditioned planning.
* Narrative memory.

Completion result:

Language becomes integrated with perception, action and memory.

Phase 12: persistent life mode

Implement:

* Long-lived checkpointing.
* Million-record archive.
* Continuous consolidation.
* Skill protection.
* Individual semantic knowledge.
* Online adaptation.
* Developmental history.
* Multi-session persistence.

Completion result:

One embodied agent can retain identity, memory and skills across long deployments.

---

## 63. Functional release gates

NumiBrain is complete when the architecture supports all of the following through one integrated runtime.

Perception

* Fuses multiple delayed and noisy senses.
* Uses active gaze and sensing.
* Maintains objects through occlusion.
* Resolves sensor disagreement.
* Separates epistemic and aleatoric uncertainty.

Body understanding

* Infers body state without exact simulator input.
* Learns muscle and joint effects.
* Distinguishes self-generated and external contact.
* Recalibrates after morphology or mass changes.
* Extends reachable-space estimates to tools.

Motor behavior

* Maintains posture.
* Recovers from perturbation.
* Develops locomotion.
* Develops manipulation.
* Controls force and stiffness.
* Adapts rapidly through cerebellar correction.
* Uses reflexes without cortical delay.

Motivation

* Explores when safe.
* Rests when fatigued.
* Protects injured or vulnerable body regions.
* Seeks physiological stability.
* Preserves active goals when interruption is costly.
* Changes behavior when risk increases.

Memory

* Stores a significant event after one exposure.
* Retrieves it from partial context.
* Distinguishes similar episodes.
* Updates a recalled memory without erasing provenance.
* Consolidates repeated episodes into semantic knowledge.
* Replays procedural skills independently.
* Executes prospective intentions when triggered.

Planning

* Selects between reflex, habit and planning.
* Plans through a changed environment.
* Uses memory to condition counterfactual prediction.
* Rejects high-risk plans.
* Converts successful plans into reusable skills.

Development

* Learns body structure through spontaneous movement.
* Acquires skills in increasing complexity.
* Retains earlier abilities.
* Develops new behavior through exploration.
* Learns from demonstration.
* Learns from social interaction.
* Continues adapting after deployment.

Transaction integrity

* Physical rejection produces no neural history.
* Rollback restores all fast state.
* Shared weights remain immutable during rollout.
* Replayed runs reproduce the same committed trajectory.
* No rejected event enters memory or learning data.

Runtime integrity

* Active brain execution remains GPU resident.
* Module work is compacted by activity.
* Large cohorts share weights.
* Persistent agents retain independent memory.
* Critical events bypass slow processing.
* High-level failure falls back to protective control.

---

## 64. Canonical execution algorithm

for each committed control interval t:
    begin root NumiBrain–NumanX transaction
    transduce receptor observations from committed physical state
    compact receptor-derived events
    advance all due sensory modules
    update posterior belief over body, world, agents and physiology
    update body schema and uncertainty
    retrieve context-relevant episodic and semantic memory
    update routed regional states
    update workspace tokens
    update drives and neuromodulatory state
    generate active goals
    propose candidate skills and internal actions
    choose reflex, procedural or planning mode
    if planning is selected:
        generate option-sequence candidates
        simulate them through the latent world model
        reject unsafe candidates
        select the highest-valued admissible plan
    select active option
    generate task-space and synergy commands
    select cerebellar experts
    generate initial muscle and autonomic commands
    cache decision, option, plan and random counters
    while the 20 ms control interval is incomplete:
        begin nested physical substep
        process fast receptor events
        advance spinal reflexes and CPGs
        advance cerebellar prediction and correction
        update muscle and autonomic command
        run NumanX candidate physical substep
        if NumanX rejects:
            discard fast neural candidate state
            restore prior accepted shadow checkpoint
            preserve decision and random counters
            retry physical substep
        else:
            retain accepted physical and fast-neural shadow state
    compute accepted sensory prediction errors
    update neuromodulatory signals
    update fast plasticity
    finalize pending episodic boundary and write operations
    update procedural competence
    update prospective intentions
    atomically commit NumanX and NumiBrain state
    emit one committed learning transition

Counterfactual world-model rollouts do not advance physical time and do not become lived memories.

---

## 65. Final architecture

The complete system is

\[
\boxed{
\begin{aligned}
\text{NumiBrain}
={}&
\text{biological sensor transduction}
\
&+
\text{probabilistic embodied belief inference}
\
&+
\text{learned body schema}
\
&+
\text{entity-structured predictive world model}
\
&+
\text{sparse thalamic-style routing}
\
&+
\text{tokenized global workspace}
\
&+
\text{working, episodic, semantic and procedural memory}
\
&+
\text{homeostatic and social motivation}
\
&+
\text{neuromodulated fast and slow plasticity}
\
&+
\text{dynamic skill generation}
\
&+
\text{basal-ganglia-style action selection}
\
&+
\text{risk-sensitive latent planning}
\
&+
\text{motor-cortical, cerebellar, brainstem and spinal control}
\
&+
\text{somatic and autonomic output}
\
&+
\text{species-specific development}
\
&+
\text{transactional GPU-resident coupling to NumanX}.
\end{aligned}
}
\]

The first authoritative vertical path is

\[
\boxed{
\text{receptors}
\rightarrow
\text{belief and body schema}
\rightarrow
\text{world model}
\rightarrow
\text{workspace and memory}
\rightarrow
\text{goal and option selection}
\rightarrow
\text{cerebellar and spinal control}
\rightarrow
\text{muscles}
\rightarrow
\text{NumanX}
\rightarrow
\text{accepted sensory consequences}
\rightarrow
\text{joint commit and learning}.
}
\]

This is the standalone NumiBrain architecture for embodied perception, learning, memory, muscle control and developmental behavior inside NumiLab.
