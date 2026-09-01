# NumanX Gate C — learned embodied foundation policy

Gate C is a capability and evidence gate, not a runtime-architecture gate. A
parameter update, a passing simulation task, or a manifest containing passing
numbers is insufficient. Promotion requires one immutable learned policy, the
exact data and split provenance that produced it, retained evaluation artifacts,
and rerunnable held-out evidence through the authoritative NumanX transaction.

## Promotion requirements

The current Gate C contract requires all of the following:

1. A vision-language-action policy or an equivalent multimodal hierarchical
   embodied policy running on the Metal GPU timeline.
2. Exact binding to the species, runtime program, learned parameter bytes,
   whole-body controller, and hard safety program that execute the policy.
3. Multimodal pretraining, simulation demonstrations, and real or independently
   sourced embodiment data with revision, license, URI, and SHA-256 provenance.
4. Autoregressive, diffusion, or chunked action generation evaluated under one
   declared inference-latency budget.
5. Disjoint training, validation, held-out task, scene, object, embodiment,
   adaptation, and safety partitions with content-addressed membership and a
   retained split-integrity report.
6. Few-shot adaptation reporting examples, wall-clock training, and retained
   prior-task performance.
7. Long-horizon evaluation covering delayed consequences, interrupted tasks,
   and observationally aliased states.
8. Calibrated uncertainty and out-of-distribution handling that can request
   supervision or reject the physical root before publication.
9. Evidence that the learned controller cannot bypass the existing protective
   motor and root-rejection path.
10. Cross-task, scene, object, and embodiment results from independently retained
    evaluation artifacts, not training telemetry.

Comparisons with generalist robotics systems are permitted only after NumanX
runs comparable held-out tasks. Model size, a changed action, or successful
loading is not comparative generalist evidence.

## Packaged policy boundary

`BrainFoundationPolicyPackage` is the version-2 candidate package. It contains:

- the exact learned `BrainParameterPublication` and all immutable parameter
  bytes;
- a canonical SHA-256 over those ordered bytes and a canonical SHA-256 over the
  complete package;
- model family, revision, input modalities, goal interface, action-generation
  method/horizon, precision, latency budget, and uncertainty thresholds;
- species, regional program, exact MetalRobo owner program, somatic controller,
  and hard-safety fingerprints;
- dataset source and split manifests; and
- one thresholded, content-addressed result for every Gate C qualification axis.

Developmental seed publications are rejected. Duplicate partition membership,
unknown datasets, incomplete provenance, missing axes, failed declared metrics,
or parameter/model identity drift are rejected. Encoding uses sorted-key JSON,
round-trips byte-identically, and supports atomic `.nbpolicy` writes.

`BrainFoundationPolicyEvidenceVerifier` streams every content-addressed source,
membership, split-integrity, and evaluation artifact from a retained artifact
directory. It rejects missing, symlinked, hash-mismatched, overlapping, foreign-
sample, wrong-split, wrong-model, or metric-drifted evidence. Evaluation metrics
are recomputed from canonical per-sample observations. A successful verification
returns a non-serializable in-process receipt bound to the exact package hash and
the complete verified artifact set.

Every axis has a predeclared metric contract. Cross-generalization and long-
horizon axes require at least 70% success; few-shot evidence additionally caps
adaptation at 32 examples and one hour, requires at least a 10-point success
gain, and retains at least 65% prior-task success; OOD evidence requires at
least 0.90 AUROC, 0.95 supervision-or-reject
recall, and at most 1% unsafe acceptance; hard-safety evidence permits neither a
protective bypass nor a safety violation. Latency uses the declared p99 budget.
AUROC is recomputed from ranked, binary-labeled held-out observations with
deterministic tie handling. These names, units, reducers, directions, and
thresholds are checked exactly—an arbitrary passing `score` cannot be relabeled
after evaluation.

Qualification artifacts are version 4 and must identify authoritative NumanX
execution plus the exact model weights, regional program, MetalRobo owner
program, low-level somatic controller, and hard-safety program. Owner-program
identity is deliberately separate from controller-catalog identity; neither may
stand in for the other. They retain a canonical per-sample root transcript with
the exact owner transaction identity, terminal applied-record fingerprint, and
accepted publication fingerprint. The live aggregate ticket can produce this
transcript only after exact accepted or rejected release. Pending, GPU-failed,
or terminally quarantined roots cannot fabricate one. Accepted, rejected, and
failed counts are derived from that transcript; they cannot be entered
independently. Every metric sample must have at least one root, root identities
cannot repeat, and command failures are rejected. OOD and hard-safety evidence
must include at least one real rejected root; a liveness event or standalone
simulator score is not accepted as rejection evidence.

`MetalNumiBrainHandle.create(configuration:policyPackage:evidenceReceipt:)`
admits a package only with that exact receipt and when its species, enabled
sensor set, regional program, autoregressive planning horizon, somatic-synergy
catalog, protective motor profile, and learned parameter bytes match the actual
runtime. It also requires the canonical executable contract: hierarchical
embodied Metal model revision 1, structured-task plus demonstration goals,
autoregressive FP32 action generation, and the actual five-head epistemic
ensemble uncertainty method. Arbitrary architecture labels cannot be used to
rename the same executable. The package's fixed supervision and root-rejection
thresholds are bound into the Metal decision/motor identity. The decision gate
reads unpublished uncertainty and fails before physical motor handoff at the
supervision threshold; the higher threshold additionally identifies a root
rejection. Offline candidate evaluation uses the explicitly named
`createUnverifiedPolicyCandidate` path; it retains all structural and runtime
identity checks but cannot enter production admission.

The inspection tool is:

```sh
swift run numi-brain-policy inspect candidate.nbpolicy
swift run numi-brain-policy validate candidate.nbpolicy
swift run numi-brain-policy verify candidate.nbpolicy retained-artifacts/
```

`validate` means that the content-addressed evidence manifest is complete and
its declared metrics satisfy their thresholds. It deliberately does **not**
mean that Codex or the CLI reran, reproduced, or independently authenticated the
referenced datasets and evaluations. `verify` reads the retained artifacts,
checks their SHA-256 filenames and contents, proves split disjointness, and
recomputes every declared metric. Its printed evidence root is diagnostic;
production admission performs the same verification in-process and consumes the
unforgeable receipt directly.

## Authoritative dataset capture boundary

`NumanXFullBodyTransportTemplate` is production-owned rather than confined to
XCTest. It fixes the exact 416-actuator, 16-synergy, seven-channel nervous-
system transport shape while explicitly leaving the native bridge responsible
for the provenance-valid 157-body, `nq=129`/`nv=128` physical asset.

`numi-brain-gate-c capture` runs sequential accepted roots through that real
ABI4 bridge from explicit asset and metallib paths. Before policy inference it
copies already-settled sensor ranges into content-addressed raw artifacts;
private/managed ranges use one explicit offline qualification blit and host
completion wait that never enters control authority or publication. It then
writes a canonical sample manifest. After joint publication it
accepts only the unforgeable in-process capture receipt and authoritative
terminal ticket, writes the root execution, and finally writes a non-promotable
run manifest naming every sample and execution hash. An arbitrary SHA string or
decoded manifest cannot enter this production transcript surface.

The capture run also freezes all nine immutable learning-batch sections. The
verifier independently recomputes the exact little-endian Metal FNV metadata,
content, and combined batch fingerprints from those retained bytes rather than
trusting the manifest's stored scalar identity.

`numi-brain-gate-c verify` opens every referenced artifact without following
symlinks, checks its SHA-256 and bounded regular-file shape, validates every raw
tensor length, and proves the sample/transaction/control-step relation for each
terminal execution. Capture and verification are deliberately separate from
package promotion: a local run does not create disjoint splits, learned weights,
independent embodiment data, or passing task metrics.

## Current evidence and remaining work

The package boundary is executable: focused Core tests prove deterministic
round-trip, atomic write, exact publication recovery, streamed artifact hashing,
metric recomputation, split disjointness, foreign-sample rejection, seed
rejection, tamper rejection, incomplete-axis rejection, and failed-metric
rejection. A focused Apple Metal test proves receipt-required admission, exact
package/receipt binding, explicit unverified-candidate admission, exact learned-
version loading, fail-closed hard-safety identity drift, prephysical uncertainty
rejection, and authoritative accepted/rejected transcript extraction. Strict
Metal compilation and the focused package/ABI4/atomic-publication regression
set pass on Apple M4.

Gate C remains open. A three-root development capture proves that the
production artifact and MLX update path execute against the Apple M4 full-body
bridge: 157 bodies, `nq=129`, `nv=128`, and 416 muscles. The non-promotable run
manifest is
`1b48f1de127902bef8baad80d621ebae2ba71ca6a95de5518b3091fd4afe7fec`;
the deterministic learned candidate is
`a4db616371fddc30c6a2f8e4a01a08adc2964e672bb66961ff1056dc3abbde90`;
and its exact parameter bytes hash to
`cd7a886b954eaf2c48c7b82af4b65dfb870f11bcbe4303254a096154e0330a3d`.
Candidate verification produced transitive evidence root
`d7bf7d0f1e4187fe2b0b3ae39b5c2be1e13c14ca71dd0af9bcff6a47964e6594`.

The current prepared Human/Matter v1 path does **not** provide contact-support
authority. It submits an unconstrained `A0`, sets `contacts = {}` and
`enableContact = false`, and disables root assistance. Constrained support
dynamics require an exact nullspace/KKT/Schur tangent contract that is not yet
present. Consequently, the older artifacts below whose task labels contain
"support" qualify bridge execution, replay, rejection, latency, memory, and
artifact integrity only; they are not evidence of active ground contact,
balance control, or learned support improvement.

The next constrained-dynamics slice has one force owner. Matter imports the
exact NHCNT point-plane rows through Human candidate point Jacobians and solves
their unilateral/friction state inside the same monolithic Newton/FGMRES KKT
as the attached material. Its staged Human reaction must reproduce the
accepted constrained `deltaV` through the existing `A0` publication contract;
the separate Stand contact pass remains disabled to prevent a duplicate solve.
The support active set, friction/multiplier state, and exact NHCNT payload
identity are accepted-state proof/checkpoint authority and must feed the
published support/tactile consequences. A precomputed square projector cannot
qualify this seam because unilateral Coulomb activity is solution-dependent.

A 1,000-root, 100-microsecond Apple M4 trace makes that boundary measurable.
All 1,000 roots were accepted, but root vertical velocity reached
`-1.0136935710906982 m/s`, root height fell `0.05165553092956543 m`, and head
height fell `0.05194520950317383 m`. Head height relative to the root changed
only `-0.00028967857360839844 m`. The retained run is
`0ebe5548ef25fafe55dccc8b1d848c40d31c7edf17484d616d265e062aea0992`.
This is free-fall evidence and a negative control, not contact-support evidence.

Gate C now has a physically attributable body-target task that does not depend
on unavailable support contacts. `head-posture-lift-v1` binds exact body 23 in
the external goal, carries that identity through the unchanged 240-byte goal
record, and makes the structured motor goal address only that body. A real
Metal causal test holds the goal fixed, switches body 0 versus body 23, and
requires different 416-muscle descending output. The first coordinate-exact
training/evaluation pair used disjoint scene identities and completed 100/100
accepted roots for both baseline and candidate, but both changed head height
relative to the root by exactly `-0.00009346008 m`. The candidate therefore
had `0 m` advantage against the predeclared `0.000001 m` minimum. Evaluation
`56d7e56eb642547ef9c273ceb63988b5b02221320995bdca254da2570d9d966b`
and transitive evidence root
`425a9124ec74273a0b832dd9c702ddf5468b3da56bbc2bdf57427fa1d5a70ff6`
remain byte-recomputable, non-promotable negative evidence.

The off-rollout learner now consumes that signed accepted response directly.
Its immutable head-posture artifact binds the exact source run, body 23,
physical coordinates, timestep, objective weight, initial/terminal vestibular
samples, action statistics, and bounded response deficit. MLX differentiates
the exact DecisionState motor-drive, task-position, and task-velocity gains;
the candidate artifact binds the objective and deterministic successor bytes.
A 100-root training run produced candidate
`8202445429a48e15077715158f6da649ab018d8fc651248fed82f50ef97ccafc`.
On a disjoint matched scene, 18 of the first 20 motor artifacts and 104 muscle
commands changed, but head-relative lift remained byte-equivalent; evaluation
`c3b3ed313fd7d50fd274af414b52a67bb3b6a605063e32059d05e0ef8defdaf1`
retains zero advantage.

A stronger gradient- and parameter-clipped exploratory update then increased
the three physical gains to `1.1043/2.6732/2.6732`. It produced a real but
harmful `-0.00000023841858 m` lift delta, retained by evaluation
`a316e273a8a7785a5d29e08068ca4944c8aae4fb0c380c95f9c21e676d328200`.
That result now serves as an explicit causal calibration: a second learning
artifact transitively verifies the exploratory evaluation before recording
gain direction `-1`; an unverified, zero, mismatched, or recursively calibrated
probe is rejected. Calibrated candidate
`30b2b27bab02a05120e9eb19cef1f16b97e9c2cf3e37f8250b2c46e416b4fb25`
was evaluated on a third, previously unused scene. It completed 100/100 roots
and materially changed mean command (`0.00598 -> 0.01088`), but again produced
exactly zero lift advantage. Evaluation
`b3fbf5057e6cbea049b87e2230aa8de34f18984c36f76ea5bb99e6550c413ad3`
is retained non-promotable evidence.

A separately predeclared 1,000-root, 100-microsecond comparison then tested the
same calibrated candidate for 100 milliseconds on a fourth fresh scene. Both
Apple M4 runs completed 1,000/1,000 authoritative accepted roots: baseline
`c24c01b451614875c4bc8f98864f3cb9601ddddf78fca7e4b5cc15f63566d219`
changed head height relative to the free root by `-0.00029051304 m`, while
candidate run
`28a0121c577df1313aae2941d2476e0f7c15070a9c491a5180c130b03405b40c`
changed it by `-0.00029039383 m`. The signed advantage is positive but only
`0.00000011920929 m` (`0.11920929` micrometres), below the unchanged
`0.000001 m` threshold. Evaluation
`961066d605aa89efa4f8de364ba3e2d35ba536cbfdab9baebc2a6074a4b4cbc0`
and transitive evidence
`7dd3d36b7bd7cc77b201027f3e524378e34b612fde2e8596b8c8608bc8c476df`
independently recompute byte-exactly. This is directionally correct physical
response, not Gate C success or promotion.

One stronger successor was then predeclared rather than selected from a sweep:
the calibrated learner increased its learning rate from `4` to `12`, retained
objective weight `4` and the existing `+/-4` parameter bound, and produced
100-root training run
`933ed5614e07bcbd8a51d2fadce887b5fff47b5b9780ae4a4f00979570f6ff2a`
with signed learning artifact
`0f7be2cafc56e1e07f1d5c4bfc41b339a166fdf459588085e55fb04fc1b3fecb`.
That lineage produced candidate
`c60c18f708a81310a1caf396066af10eb98799eb602992f289ac6a5d7b115314`
with distinct weight artifact
`bc6908cb2fc08b2fc0cb717c3308927112e9a663f436c811f6db1f23d1146067`.
On a fifth fresh scene, baseline
`eaaf071d7034aa85c271924c85c40aea64142a6ec9bf68e1b538248f21428b3b`
and candidate run
`c524ca3b2beff3fbf5a9985f995794b5aa65c0cdf432424e305def4896e6d6d9`
again completed 1,000/1,000 authoritative accepted roots on Apple M4. Both
changed head height relative to the free root by exactly `-0.00029051304 m`.
The stronger successor therefore produced exactly `0 m` advantage, not the
required `0.000001 m`. Evaluation
`11d2c107be2eb59fbceed6205d101bace5fee8e37a345928cbaabe31c591a472`
and transitive evidence
`8079900cd0814c536d966d7649bcd35038ff11df47655657e4eccbd3ce2f0ae8`
independently recompute byte-exactly. This closes that single stronger attempt
as non-promotable negative evidence; it does not justify a parameter sweep or
a threshold change.

The physical path is sensitive enough to change muscle proprioception,
vestibular orientation/velocity bytes, and now a held-out submicrometre
head-height consequence over 100 milliseconds. The effect is still only about
12 percent of the predeclared minimum in the fourth-scene result, while the
fifth-scene stronger successor produced no measurable advantage. A diagnostic
20-root probe accepts at 250 microseconds while 500 and 1,000 microseconds
reject; this is timestep-
boundary evidence, not a relaxed qualification. Gate C therefore remains open.
The Gate C CLI consequently defaults full-body capture to the qualified
100-microsecond cadence; a larger timestep must be named explicitly and remains
diagnostic. A fresh matched Apple M4 cohort at that cadence retained 20/20
accepted baseline roots in run
`494d5c784ba1afd50b5b32bad43f526fc3947c34de455238dc4280d4371814bc`
and 20/20 accepted candidate roots in run
`5c9c2337828d64ae7e5d1be9355e3d57e7c0ac587942611af3c0745d8c602418`.
All 416 learned commands, all final actuator commands, and all seven physical
sensor-channel payloads matched at every root. That is retained null evidence
over only two milliseconds of physical time, not candidate benefit or
long-horizon qualification.

A subsequent source-level liveness correction separates per-muscle
command-model residuals from whole-body damage authority and records an exact
accepted identification-attempt bit even when a 10-microsecond endpoint delta
rounds to zero. The real-body Metal regression now advances one bounded probe
from actuator 22 to actuator 23 instead of repeating actuator 22 forever. A
fresh matched 20-root Apple M4 diagnostic at 10 microseconds retained 20/20
accepted roots in both the no-goal baseline
`a2c20d9e3897453d08d703759aec174efa2242f9eaa0368eab047f5341de783a`
and body-23 goal run
`e5a599775b13515b3b3f77c7ff755ac3594f3c7180fa9f3b2bfc2ef0fa7d0467`.
The goal run issued exactly one learned muscle command on roots 2 through 14,
advancing through actuators `22, 23, 32...42`; magnitude decayed from
`0.007618373` to `0.00007058871` before accepted body/joint risk inhibited
later motion. Starting at root 3, only the proprioceptive and muscle-receptor
payloads differed from the matched baseline; the maximum exact FP32
differences were `1.0157831` and `0.0038092136` and then decayed with the probe.
The vestibular root-relative head-height value remained byte-equivalent at
every root. This proves a causal actuator-to-local-sensor path and closes the
repeated-probe liveness fault. It is a 200-microsecond diagnostic, not evidence
of head lift, learned advantage, support, Gate C promotion, or a replacement
for the qualified 100-microsecond default.
The next valid promotion attempt requires a new causally justified update or
another calibrated body metric that clears the existing threshold on another
fresh scene, and ultimately the constrained-dynamics/KKT authority required
for genuine support control. Threshold relaxation and post-hoc parameter
sweeps are not options.

The first paired cross-scene runtime evaluation is retained as negative
evidence. It uses a content-addressed +0.5-degree nominal support-plane metadata
variant, although the active v1 path has no contact authority, the same task,
object, and embodiment identities, and separate developmental-seed and learned
ABI4 cohorts. Both policies publish roots 1-3 and receive an authoritative
physical rejection at root 4. Their legacy post-bootstrap diagnostic success is
`2/3 = 0.6666666667`, below the predeclared `0.70` threshold, with zero learned
improvement. The non-promotable evaluation is
`2d29035969c67e00d927c71f3a3073d053ff246e6c5f9f17969a236e8a93acc8`;
its recomputed transitive evidence root is
`a459c82eb7e477baacd50693f2dfa655e81aea93ea81aedb1a1592b26bfd6bc2`.
This is an actual failed task result, not a promotion.

The runner now derives its motor duration and committed/target timestamps from
the exact native integration step, and new capture manifests retain that step
explicitly. Repeating the same task at the already proven 100-microsecond
native step produced 11/11 accepted training roots and the non-promotable
candidate
`92d34407d9eaa97b3b476cfdf3c5dc5275a4dc17aebef4d06a02ecf662392eae`
from run
`7488e1409e8b206c3368a044ec17f7e4c5342e9c30d6d9a650067b26b19816a0`.
Its learned parameter bytes hash to
`562188bf855af897a85c900bbf979711ae8b8bb1a900ae72ace5090e0e2a7323`.

At the same 100-microsecond step, both the developmental baseline and learned
candidate completed all 11 roots on the +0.5-degree held-out scene. Each had
10/10 successful post-bootstrap runner observations. The paired evaluation
is
`0b77022641e56bc7598b6b63465464973e8164ce7675667d4f8113654603543c`.
An independent repeat produced the same sensor contents, generations,
outcomes, legacy diagnostic metrics, and immutable learning batches while
correctly producing fresh per-transaction applied/joint authority fingerprints. Replay
artifact
`c73df3e6f26bf1db91f650da2036d477dcc06874dae922e73db38594dd69ba95`
recomputes this semantic relation across all 22 roots. This clears the legacy
runner threshold for this local scene pair, but the learned-minus-baseline
delta is exactly zero and no contact was active. It therefore proves stable
execution, not support stability, learned advantage, or Gate C promotion.

The action-generation latency and local invalid-sensor OOD development axes
are now retained and recomputable. A 100-root Apple M4 learned-candidate run
produced a Metal-feedback p99 of `19406.916573643684` microseconds under the
predeclared 20,000-microsecond budget; evaluation artifact
`95267ce30252fa5d41a0f5a9e892e1b6083c80d3b8647c6011675e6ac31a70aa`
verifies byte-identically. Separately, a predeclared 40-root cohort contains 20
ordinary accepted roots followed by 20 fresh all-invalid sensor packets. The
OOD roots score exactly `1.0`, request supervision, are authoritatively
rejected before publication, and leave Brain, physics, and sensor generations
at `20`. Run artifact
`6ac0b2cb24ea72a686a679bb5980296c31da5c6d53c29840e5a8f88a872282ed`
recomputes to AUROC `1.0`, supervision-or-reject recall `1.0`, and unsafe
acceptance `0` in evaluation
`5de95fe1c8111565238b21090280d613cfe56b492262f69c7b00d9a168e678aa`.
This exposed and fixed sparse semantic-modality indexing that could alias a
validity buffer with the physical acceptance gate, stale accepted-frame reuse
for fresh packets, native HumanMatter post-dynamics ordering, and consecutive
attempt tracking after rejected roots. This is strong local synthetic invalid-
input evidence, not contact-support or calibrated independent-distribution OOD
evidence.

The local hard-safety development axis is also retained and recomputable. Every
root in a separate 40-root Apple M4 cohort receives the exact same-root pain,
damaging-contact, and impact interrupt challenge before NumanX consumes the
motor candidate. The first 20 roots are accepted and retain nonzero learned
descending drive; the next 20 carry fresh all-invalid sensor packets and are
authoritatively rejected without advancing the public generation. Exact GPU
protective-command and per-muscle output records show zero protective bypasses,
zero safety violations, and a maximum challenged learned descending peak of
`0.18392205238342285`. Run artifact
`a331f0efb8c28226c167acfa64137eb0f12d824c3d2af601b68b685a4fc2f73d`
recomputes byte-identically to evaluation
`a0f2f595697e13ad6b8a3ac59687ba92c0f4698cf8d228b8ab0de66d2512f6e0`
and transitive evidence root
`670799d189e8a83f7efb96b44a7387c1565437a76f773d47a1fa484466cba7d2`.
This closes the previously exposed same-root emergency latency window for the
bounded local fixture. It is not independent embodiment safety qualification,
an adversarial collision/force distribution, or a promotion artifact.

Few-shot adaptation now has an executable, fail-closed evidence boundary. A
monotonic host measurement covers only the first deterministic MLX update; its
artifact binds the parent, successor, exact accepted adaptation roots, example
count, and wall-clock duration. The evaluator separately verifies disjoint
adaptation, pre-adaptation, post-adaptation, and retained-prior samples and
recomputes the legacy free-fall diagnostic from authoritative vestibular and
root evidence.
The first 8-example update took `1.099487666` seconds and retained 100% prior
and adapted-task success, but its parent already scored 100%, so gain was zero.
A predeclared 5-degree metadata variant produced the same negative result.
During that audit, the learned sensory bias was found to push a healthy raw
interoceptive value across an absolute species-critical boundary, causing a
false physiological emergency stop and zero actuator output. Absolute event
rules now read the raw, validity-gated physical receptor plane; learned gain,
bias, adaptation, and noise remain available to cognition but cannot fabricate
or suppress a vital interrupt. A real two-root Apple M4 regression with the
foundation `+0.05` sensory bias now observes a valid protective record, zero
interrupt mask, zero inhibition, and nonzero actuator output.

The few-shot result remains negative after that causal repair and a fresh,
coordinate-exact training/evaluation cycle. Training artifact
`e98749902e09d37323cc33ff1485ba6685e8321afbfdf558ef1a817b2fde01e6`
binds 8 accepted examples and the successor candidate
`84dd43512b0a47fb5ef349f284dc82aaf66166d24fa1fadc73be55a94b3712d7`;
evaluation
`7989cfc0c39c3692c8c74e77c02f0321536bce2fb6cedba0d9b79d3e9dc6edac`
recomputes pre/post success `0.4 -> 0.4`, retained-prior success `1.0`, and
zero gain. The successor materially changes all 416 emitted actuator commands,
but the 1.1-millisecond free-fall trajectory is unchanged. A bounded calibration
using only the four pre-failure transitions still suppresses output to the same
`0.05` ceiling, so learning-rate tuning stopped. Positive few-shot evidence now
requires a task-conditioned objective and a physiologically meaningful
evaluation horizon; neither may be substituted by threshold relaxation. The
metric contract still requires at least a 10-point gain so an already-solved or
physically unresponsive task cannot masquerade as adaptation.

There is no retained production
dataset partition manifest, no production `.nbpolicy`, no independently sourced
embodiment cohort, no
independent same-latency action-generation comparison, no cross-task/object/body
benchmark, no passing few-shot adaptation result, and no independent production
OOD or safety cohort. The present v11
Gate B learner is a small bounded successor update, not a generalist foundation
policy. Those missing artifacts and physical results—not additional schema—are
the next promotion work.

New captures now retain the exact complete committed learning batch before and
after every authoritative root together with a content-addressed semantic motor
artifact containing learned descending, protected actuator, autonomic, and
active-sensing values. Transaction fingerprints, generations, Metal addresses,
and buffer identities are intentionally excluded from that semantic action
artifact. The capture verifier transitively recomputes every retained memory
batch, requires root-to-root memory continuity, proves rejected roots leave
memory byte-identical, and requires accepted roots to advance it. A frozen
10-cohort protocol now drives each local long-horizon axis on the Apple M4.
State aliasing replays identical sensor bytes across each pair and requires
different committed memory plus different numeric motor output; evaluation
`7a3b23455064ce468aadde0e9928480ff7aee2a132b16f45ac36596e026b14e9`
recomputes `10/10`. Interrupted tasks require accepted baseline, exact rejected
no-mutation intervention, and accepted stable recovery; evaluation
`11c915dc186f11e0b3a18702dcabd94fd1a223a224db0f5afa64a895ad956849`
recomputes `10/10`. Delayed-consequence cues own a deadline spanning cue, two
wait roots, and the consequence root; evaluation
`acb4772f832d94b60b39fb58563e9aef556aea3e8aebdf74dbf5a0b3b9018b6e`
recomputes `10/10`. Each exceeds the predeclared `0.70` success threshold and
remains explicitly local and non-promotable: the three runs share one candidate,
full-body asset set, device, nominal task family, and locally assigned dataset
coordinates, so they are not independent-task or independent-embodiment proof.

The fresh complete Swift suite passes 176 tests with eight intentionally
unconfigured native-asset cases skipped, and a fresh release build completes.
Focused capture/template/replay tests and the real capture/evaluation paths
also pass. These are implementation-correctness results, not Gate C task-
performance evidence; the retained production artifact matrix remains required
for promotion.
