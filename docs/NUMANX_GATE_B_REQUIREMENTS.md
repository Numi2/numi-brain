# NumanX Gate B — complete causal sensorium

Gate B is complete only when every enabled modality below is produced by live
Apple-Metal owning code, belongs to the same accepted NumanX root, reaches the
Brain through the aggregate publication gate, and measurably changes a learned
policy under a causal perturbation. A descriptor, static asset, debug image,
teacher tensor, or independently published buffer is not Gate B evidence.

## Common channel contract

Every channel must carry, and validators must fail closed on:

- exact modality, receptor count, feature dimension, scalar type, value range,
  and per-receptor validity;
- exact capture time, delivery time, latency, and sample interval;
- species-template, sensor-profile, model, transaction, substep, accepted Brain
  generation, physics generation, and sensor generation provenance;
- retained same-device Metal objects, exact GPU ranges, checked arithmetic,
  and pairwise non-overlap;
- one aggregate publication epoch shared with Brain, q/v/MyoSim, Matter, and
  HumanIO; reject, timeout, or GPU failure publishes none of them;
- deterministic replay for fixed inputs and explicit invalidity for missing,
  stale, occluded, saturated, out-of-range, or first-sample history.

The frozen Gate A two-channel C snapshot remains available. Gate B uses the
capacity-bounded temporal-authority aggregate v3 snapshot and publishes all
channel descriptors in one reader-gated copy; consumers never assemble a root
from separate epochs.

## Required modalities

| Modality | Minimum owning signal | Required causal perturbation |
| --- | --- | --- |
| Kinesthesia (joint state) | post-step scalar joint position and velocity, generalized applied load, Matter reaction, limit margins, effort-normalized load | perturb one joint/load/limit while holding the other sensor inputs fixed |
| Vestibular | accepted floating-root orientation, linear/angular velocity, linear/angular acceleration, gravity and specific force in sensor frame | rotate/accelerate the body with identical muscle input |
| Touch | contact pressure, shear/slip, vibration/impulse, temperature when authored, nociceptive/risk validity | move or remove one contact patch and change friction/impulse |
| Muscle/tendon/interoception | excitation, activation, fibre/path state, active force, tendon tension, fatigue, energy/load and damage-validity | alter fatigue/load or tendon state without changing the visual scene |
| Vision/depth | calibrated RGB/linear depth/validity/IDs with exposure and rolling-shutter capture timing | occlude/move an object or change gaze/exposure physically |
| Audition/language | source-localized waveform/features and token/event timing with validity | change an acoustic source while preserving the visual state |
| Active sensing | eye/head/ear/whisker/sniff/palpation/gain commands cause bounded physical sensor-pose or acquisition changes before the next capture | command versus ablated command changes the subsequent owned observation |

## Evidence ladder

Each modality must pass all four levels; higher levels do not replace lower
ones.

1. **ABI and source:** strict C/C++/Swift/Metal layout checks, exact range and
   identity negatives, no host payload readback, and no parallel timeline.
2. **Physical response:** Apple-Metal probe shows the expected channel bytes and
   validity change under the named perturbation, with unrelated channels within
   tolerance and rejected roots remaining unpublished.
3. **Temporal and replay:** capture/delivery latency is measured, first-history
   invalidity is explicit, fixed replay is bitwise, and retry receives a fresh
   generation without stale bytes.
4. **Learned causal use:** held-out policy evaluation compares intact,
   modality-ablated, timestamp-shifted, and value-shuffled observations. Gate B
   requires a reproducible task-relevant degradation for the intact channel;
   teacher-only or correlation-only sensitivity does not qualify.

## Ordered implementation

1. Capacity-bounded multimodal aggregate ABI and atomic publication.
2. Joint and vestibular channels from post-step owner authority.
3. Touch plus richer muscle/tendon/fatigue/energy interoception.
4. Calibrated vision/depth and audition/language event streams.
5. Transaction-bound physical active sensing.
6. Cross-modal perturbation, replay, rejection, latency, performance, and
   learned-policy ablation qualification on the production full-body root.

## Qualification checkpoint — 2026-08-31

The production full-body root currently publishes seven channels through the
aggregate v3 reader gate: 416x10 proprioception, 416x6 interoception, 128x7
kinesthesia, 1x22 vestibular, 10x7 touch, 64x48x8 vision/depth, and 24x8
binaural audition (twelve cochlear bands per ear). Vision is
rendered after the stand solve and Human/Matter accept-or-restore decision from
reconciled post-step articulated kinematics; it is not a pre-dynamics debug
view. The HumanIO candidate owns the renderer intermediates and final channel,
and rejected roots remain unpublished.

On Apple Metal, the neutral calibrated head camera produced 3,072 finite frame
pixels, 718 valid depth pixels, and 720 valid semantic/instance/link pixels. A
source-authored 12-degree physical gaze-pose perturbation changed the complete
vision payload fingerprint from `010c050f1f3436d3` to `b14426efc70071f1`,
while the combined six-channel nonvisual payload fingerprint remained exactly
`8f2d1accc01cc9e4` after audition joined that set. The real Brain/native E2E also carries vision into the next
root and proves bitwise candidate replay across reject/retry.

The full-body species now assigns its sole active-sensing action to vision. The
native profile authors a unit local gaze axis and a `0.35`-radian bound. Before
ray generation, a transaction-owned command rotates the camera-parent visual
body by `command * confidence * maximumAngle`; exposure remains at the authored
nominal value. On Apple Metal, command `0` produced 718 valid depth pixels and
720 valid geometry pixels with vision fingerprint `010c050f1f3436d3`.
Command `0.75` produced 2,054 and 2,058 respectively and changed the vision
fingerprint to `7a62c5ca7c50b5fa`, while the combined nonvisual fingerprint
remained exactly `d6e8fe77f1f2d094`. Two commanded runs were byte-identical.
This is a real bounded ray-geometry actuator, but currently an ideal
zero-reaction head-local camera gimbal rather than coupled ocular/neck dynamics.

The real Brain/native path validates the exact 16-byte vision command ABI before
physical use. Developmental maturation now enters the ABI4 prepared path as an
exact 32-byte FNV-bound capability intent. The GPU accepts the intent only after
the authoritative accepted-physics gate validates, then stamps the accepted
token into the private developmental evidence; no host token digest is used.
Six accepted roots unlock the reference active-sensing stage. The seventh
decision emits command `0.18011415` with confidence `0.55438346`, changes the
published physical vision channel, and replays every sensor byte exactly. A
rejected fifth-root intent does not unlock the command on step 6, while a valid
retry unlocks it only on step 7. Seven accepted roots with each intent
fingerprint mutated remain at zero command and confidence. This qualifies
accepted-root-authenticated maturity and autonomous selection, but the claims
are host-authored rather than autonomously discovered or competence-verified.
A command-only ablation on the seventh root is applied before the ordinary
decision-ready proof hashes the motor candidate. It preserves the complete
416-muscle command, descending somatic output, and every nonvisual sensor byte.
The intact autonomous command raises valid depth coverage from 718 to 864 pixels
and valid geometry coverage from 720 to 864. This passes the predeclared
physical visual-search coverage outcome; the gimbal remains an ideal
zero-reaction actuator rather than coupled ocular/neck dynamics.

The aggregate reader now uses temporal-authority snapshot ABI v3. Its FNV-bound
sensor clock is copied under the same reader gate as the seven channel records and
contains exact integer capture, delivery, latency, and sample-interval values;
v1/v2 remain byte-frozen. The native full-body probe measured its configured
sensor-clock interval as 2,000 microseconds, and the production Swift root
proved capture `1,000` -> delivery `2,000` with 1,000-microsecond latency and
sample interval for every channel. The second accepted root advances those
times to capture `2,000` -> delivery `3,000`. Timing is mixed into the retained
candidate publication fingerprint, and the atomic publication suite remains
green across reject, timeout, replay, and next-root admission.

The real full-body first vestibular sample also publishes an exact partial
validity mask: orientation, linear/angular velocity, and gravity are valid,
while all acceleration and specific-force bits remain invalid because no prior
accepted generation exists. The focused HumanIO continuation test proves those
nine history-derived bits become valid only after an accepted predecessor;
rejected candidates never become history.

The production Brain/native two-root test now qualifies the first-root boundary
instead of relying only on synthetic nonzero generations. Its canonical first
random-counter generation is exactly zero and is authenticated as a real value;
HumanIO no longer misclassifies it as a missing identity. The first accepted
root publishes all 416 proprioceptive masks as `0x3ff`, all ten tactile masks as
`0x7f`, and every auditory mask as `0xfb` (onset alone is history-invalid). The
second accepted root advances every auditory mask to `0xff`. A separate owner
phase orders HumanIO validation before Human/Matter proof, so a malformed motor
or receptor source now produces a zero accepted token and physical reject rather
than publishing a sensor-invalid physical root.

Audition is now an owned GPU channel derived only from the finalized physical
support-contact impulses and the accepted head pose. The calibrated profile
binds two ear positions, propagation speed/attenuation, a twelve-band cochlear
bank, and a bounded diffuse reverberant fraction. Each receptor publishes
envelope, energy, history-gated onset, center frequency, propagation delay,
interaural level delta, and head-frame azimuth/elevation. The first sample
explicitly invalidates onset because no accepted predecessor exists. On M4,
eight active contacts produced nonzero finite energy in the 24x8 channel with
payload fingerprint `5796b3d6552e516a`. Widening only the authored physical ear
baseline changed audition to `4bcd587c67b51219`, while vision remained
`010c050f1f3436d3` and the combined non-auditory payload remained exactly
`fcd45afad13d230b`. A separate source-side perturbation tilted the authenticated
ground/support frame by six degrees while retaining the same body and ear
profile. The solved total normal impulse changed from `0.197407` to `0.196455`,
the tactile source fingerprint changed from `db62c25c0419af8b` to
`b1f3e28ec8566c7c`, and audition changed from `5796b3d6552e516a` to
`279f98544039a499`; calibrated vision remained exactly
`010c050f1f3436d3`. This is reduced impulse acoustics/cochlear feature evidence,
not a volumetric wave solve, microphone waveform, speech recognizer, or
language qualification.

The production E2E now also closes the first learning boundary on the same
root. After four accepted aggregate publications, NumiBrain freezes a distinct
generation-4 committed batch, imports it into MLX, differentiates all eleven
immutable slow-parameter components across the complete twenty-loss objective,
constructs a direct provenance-bound successor publication, and materializes a
fresh Metal runtime that consumes that exact successor on the same M4. This
exposed and fixed two previously unexecuted learner defects: `valueAndGrad`
had differentiated only its default argument zero instead of all eleven
components, and semantic endpoint resolution had allocated a dense
262,144-by-65,536 relation/concept equality matrix. Endpoint resolution now
builds an exact unique-valid concept index over the immutable off-rollout
snapshot and sends only linear relation indices and masks into MLX. This is
root-to-learner and learner-to-runtime evidence. Two independent MLX updates
from the same parent publication and immutable accepted batch now produce an
exactly equal learner update and successor artifact. This is not a trained
production policy, held-out task performance, or modality-causality evidence.

The committed-transition learner ABI is now version 11. The former 24-scalar
prefix could silently represent only the earliest large channel in the
concatenated sensorium, while v9's global mean/magnitude/maximum summaries
collided on physically distinct support scenes. Each enabled modality now owns
a deterministic three-coordinate signed projection bound to modality, source
index, and projection coordinate. Small modalities contribute every scalar;
large modalities use an evenly spaced bounded 1,024-scalar sketch. For the
NumanX authoritative path, the journal binds the exact accepted raw sensor
ranges in the same GPU consequence command and uses the transduced validity
mask; legacy callers retain the transduced-observation path. The real full-body
test requires all three validity bits for every one of the seven enabled
modalities before MLX may consume the batch.

A versioned off-rollout intervention runner now evaluates a learned successor
only on accepted generations that are strictly later than its immutable
training snapshot. It executes intact, ablated, deterministic value-shuffled,
and one-generation timestamp-shifted variants through the exact one-step
belief/policy-head relation optimized by the learner, and replay must be
bit-identical. On the current static standing holdout (training generation 4,
evaluation generations 5–8), ablation changed the learned action head for
vision, audition, touch, proprioception, vestibular, and interoception with
mean-squared deltas from intact between `0.0010751626` and `0.0032618665`.
Kinesthesia ablation, every value shuffle, and every timestamp shift produced
exactly zero delta. Moreover, every nonzero ablation reduced rather than
increased imitation MSE relative to the accepted actions. This is useful
negative evidence: the harness and learned sensitivity exist, but the static
sequence does not demonstrate task-relevant causal use and therefore does not
close Gate B.

A second cohort benchmark now uses two distinct accepted training minds with
authenticated support planes at -2 and +2 degrees (nine accepted roots each)
and a separate +1-degree held-out mind through accepted root 11. The two native
worlds diverge in their physical-state fingerprints from root 1; every logical
sensor modality changes, with maximum absolute differences including touch
`6.3407154`, vestibular `0.03045708`, and kinesthesia `0.02212683`. Their v11
accepted learner observations differ by `0.1890342`; the somatic action records
remain identical. On held-out generations 10–11, deterministic value shuffle
and timestamp shift now produce nonzero policy-head deltas for touch,
proprioception, vestibular, and interoception (and a smaller nonzero vision
effect), with touch deltas `2.3585348e-07` and `6.9616647e-07` respectively.
Vestibular ablation increases imitation MSE from `0.14783676` to `0.14815411`,
while several other ablations reduce it. This closes the prior constant-input
collapse and demonstrates replay-stable multi-scene/temporal sensitivity. It
is still off-rollout policy-head evidence, not a claim of physical task
degradation or a trained closed-loop controller.

The v11 action journal now records the sixteen accepted somatic-synergy
coordinates rather than the first sixteen actuator samples. The production
decision kernel evaluates the learned head against a deterministic 24-value
raw-sensor sketch with one validity coordinate per enabled modality, folds all
24 values and masks into the sixteen enacted coordinates, then applies the
immutable 416-by-16 full-body synergy decoder. The fold is mirrored by the MLX
causal evaluator. Before this correction, direct `0..<16` indexing made the
final eight sketch coordinates—and therefore the full kinesthetic slot—unable
to affect action. The full-body fixture declares sixteen logical synergies;
the 416 actuators remain the exact NumanX muscle order.

The real closed-loop causal task uses the +1-degree held-out support world, an
explicit support-stability goal, and the learned successor. Each intervention
runs in its own process and preserves the same three accepted roots and exact
goal/option sequence. The current Apple M4 evidence is:

| intervened channel | intervention | learned-action max delta | 416-muscle max delta | continuous outcome drift, intact -> intervened |
|---|---:|---:|---:|---:|
| vision | ablated | `0.0011254251` | `0.00009134039` | vestibular `46.496605 -> 46.508995` |
| audition | values x `0.9` | `0.0012276769` | `0.000060815364` | vestibular `46.496605 -> 46.511135` |
| touch | ablated | `0.07522233` | `0.005658008` | touch `36.914516 -> 37.225964` |
| proprioception | ablated | `0.021982267` | `0.0016876431` | proprioception `7.5002885 -> 7.503776` |
| vestibular | ablated | `0.5306565` | `0.023855925` | vestibular `46.496605 -> 46.52222` |
| kinesthesia | ablated | `0.009146318` | `0.00074331556` | kinesthesia `14.809405 -> 14.80993` |

Every row also changes at least one independently published physical modality
other than its intervened input. This closes the bounded learned-causal-use
level for those six channels without treating a changed hash, categorical
vision code, or source-side perturbation as outcome evidence.

The accepted joint posterior also now initializes ownership from the first
valid causal receptor coverage rather than multiplying that first evidence by
a millisecond temporal gain. Subsequent ownership updates remain rate-limited.
Before this correction, the near-zero initialized ownership made the
conservative joint-uncertainty term clamp all 416 descending commands after the
first root; the qualified three-root task now retains nonzero descending
commands while preserving joint-limit, variance, pain, and emergency-stop
gates.

This checkpoint establishes the six closed-loop rows above, vision ABI/source
ownership, the named physical signal perturbation, one bounded head-local
ray-geometry command, accepted-root-authenticated mature autonomous gaze, exact
simulated sensor-clock delivery, plus fixed replay and rejection behavior. It
does not yet establish wall-clock GPU capture-to-publication latency/performance,
autonomous capability discovery, coupled ocular/neck dynamics, or
waveform/speech/language sensing. The native
416x6 interoceptive channel now
integrates bounded local energy availability, oxygen availability, carbon-
dioxide burden, temperature deviation, fatigue, and damage from causal MyoSim
workload and only the previous accepted HumanIO generation. Rejected candidates
cannot advance that history. The cognitive runtime now aggregates one semantic
feature across all 416 receptors instead of treating the first nine flattened
muscle scalars as nine body-wide physiological variables. This is a reduced
control model, not authored systemic hydration, inflammation, sleep, metabolic,
or clinical physiology. In the real three-root intervention, ablation changes
learned action by `0.0021179318`, descending and muscle output by
`0.00017181039`, and later vision, touch, proprioception, vestibular, and
kinesthetic state. It nevertheless improves the predeclared postural outcome
(`46.580482` intact vestibular drift versus `46.49666` ablated), so the causal
benefit criterion still fails. That measured interoceptive
training/qualification gap keeps Gate B open.

Focused executable evidence at this checkpoint includes 14/14 native NumanX
integration tests (green twice), the focused Swift
interop/ABI4/atomic-publication/full-body E2E tests on Apple Metal, and the
asset-backed multi-scene cohort with its deterministic MLX successor update and
intervention replay. The complete Swift package is 150 tests with zero failures
in 58.763 seconds when seven bridge/stress tests are intentionally unconfigured.
With real bridge paths, the bounded external-task plus publication/retry E2E
passes 2/2 in 15.514 seconds and explicitly skips the isolated stress cohort.
The accepted-maturation/replay, rejected-root, and malformed-intent gaze proofs
pass independently in 20.181, 7.889, and 7.176 seconds.
The paired command-only gaze ablation passes in 13.703 seconds and measures
718 -> 864 valid depth pixels plus 720 -> 864 valid geometry pixels.
Six independent 49-root Gate B modality cohorts pass in 50.286–50.627 seconds
each. The Developmental, Decision, Memory, and AcceptedConsequence Metal 4 shaders pass
`-Wall -Wextra -Werror` (with the repository's intentional unused-parameter
suppression), the ABI4/provisional matrix passes 40/40, `git diff --check` is
clean, and the fresh production Swift build passes in 54.67 seconds.

Gate B is not achieved until every row and every evidence level is satisfied.
