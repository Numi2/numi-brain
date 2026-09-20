# NumiBrain affective state

NumiBrain carries a small, per-agent affect state derived from accepted bodily
evidence. It represents transient pain, pleasure, and relief signals for
attention, planning, memory salience, and learning emphasis. It is a modulation
signal, not a separate reward function or a claim about subjective experience.

## Evidence and comparability

Only valid receptor observations in the accepted physical transaction are
eligible. The selected `AffectiveModelConfiguration` sets the maximum evidence
age (100 ms in the reference configuration). The Metal update requires the
frame to be delivered at the target transaction timestamp, its receptor
timestamp to be no later than that target, and its age to be within that bound.
Interoception and touch values are read only
when their respective accepted frame metadata and scalar-validity entries agree.
Touch nociception also requires an enabled body-receptor binding for the
nociception signal. Pain events of kinds 8 and 9 can contribute pain when their
timestamps are within the selected evidence-age bound.

### Typed NumanX interoception

`NumanXFullBodyV1` names the six normalized features carried at each of the 416
NumanX interoception receptors. Its schema fingerprint binds feature names,
order, direction, and ranges into the species-template identity (format v9).
Metal interprets the flattened vector by position only when the compiled
interoception topology carries this exact fingerprint and dimension six.
For this typed channel, sensory transduction preserves the normalized physical
values and does not apply generic perceptual bias, noise, or receptor
adaptation before affect reads them.

| Feature | Meaning and accepted range | Affect evidence |
| --- | --- | --- |
| 0 | Energy availability, `[0, 1]`, higher is better | Energy deficit `1 - availability` |
| 1 | Oxygen availability, `[0, 1]`, higher is better | Combined with CO₂ as below |
| 2 | Carbon-dioxide burden, `[0, 1]`, higher is worse | Respiratory deficit `max(1 - oxygen, CO₂ burden)` |
| 3 | Signed temperature deviation, `[-1, 1]` | Absolute deviation |
| 4 | Muscle fatigue, `[0, 1]`, higher is worse | Fatigue deficit |
| 5 | Tissue damage, `[0, 1]`, higher is worse | Damage deficit and fresh pain evidence |

Each mapped source is averaged across receptors only when every receptor has a
valid, finite, in-range value for that source. Respiratory evidence additionally
requires both oxygen and CO₂ to be valid at every receptor. A source that lacks
complete coverage is absent for that frame; changing receptor coverage cannot
be interpreted as recovery. An opaque or unknown schema is never interpreted
by feature position. Such a profile may still supply fatigue through fully
valid explicit calibrated `.fatigue` muscle-receptor bindings. Direct
nociception continues to require an explicit body-receptor binding.

Source mask bits 0–4 identify observed homeostatic channels; bit 5 identifies
fresh pain evidence from either direct nociception or pain/injury-risk event
kinds 8 and 9. The separate prior-validity mask tracks whether direct
nociception is comparable for relief; an event-only pain bit cannot establish
that baseline.

Pleasure from recovery requires a fresh observation for a channel and a prior
valid observation for that same channel. A missing source breaks that channel's
comparison; when it returns, the first sample establishes a new baseline.
Repeated, stale, future-dated, or invalid observations cannot produce recovery
or relief. A newly consumed interoception frame timestamp still advances the
baseline when every feature is invalid; this keeps an older frame from reviving
after a complete validity dropout. The CPU `AffectiveState.advanced`
implementation is the reference oracle for these rules.

## State update

The reference source weights for energy, respiration, temperature, fatigue,
and tissue damage are `0.24, 0.24, 0.16, 0.18, 0.18`. Recovery is the weighted
sum of positive reductions in comparable deficits, capped with the resulting
pleasure state at 1. Direct relief is a positive decrease between two fresh,
comparable nociception samples. It increases both relief and pleasure. Pain is
the maximum of retained pain, fresh nociception, fresh mapped tissue-damage
evidence, and fresh pain/injury-risk event evidence. A missing pain source
clears the comparison baseline while retaining the last-consumed timestamp, so
a later sample cannot manufacture relief or reuse an old frame.

Each state decays against physical elapsed time using exponential retention
`exp(-dt / tau)`: the reference configuration uses a 2 s pain time constant,
1 s for pleasure, and 0.5 s for relief.
New pain, recovery, and relief are then added according to the update above and
clamped to `[0, 1]`. Passive decay does not create pleasure or relief. The
Metal uses the selected physical-time constants for both state updates and
planner decay. When candidate options are scored, the planner decays stored
affect values from their timestamp to the physical target time; zero or future
timestamps contribute no candidate modulation. The reference recovery and
relief gains are 1. Gains are bounded to `[0, 4]`; the five source weights must
be finite values in `[0, 1]` that sum to 1. The selected evidence-age bound,
decays, gains, and weights are fingerprinted into the arena layout, so a
checkpoint cannot be restored under a different affect configuration.

`AffectiveModelConfiguration.disabled` is the matched control mode. It commits
zero pain, pleasure, relief, and affect source evidence on accepted roots, so
attention, planning, memory salience, and learning receive no affect signal.
It does not disable raw sensation, existing pain/injury-cost factors, reflexes,
or emergency-stop paths. The enabled bit participates in the configuration
fingerprint and the affective layout version; checkpoints cannot cross the
enabled/disabled boundary. Historical serialized configurations without the
bit decode as enabled.

## Transaction and consumers

The 64-byte affect record lives in each agent's hot state. The Metal update runs
only after accepted sensorimotor reconciliation and only when the physical
acceptance gate is set. It writes into the transaction shadow, so a rejected
physical future does not publish the affect update. Core agent state and its
checkpoint fingerprint also include affect and its configuration identity.

The current consumers are deliberately bounded:

- **Attention:** fresh affect with a nonzero source mask and age within the
  selected evidence-age bound competes with the strongest drive for workspace
  slot 0. Its score is the maximum of pain, pleasure, and relief.
- **Memory:** affect can become the embodied salient event (event kind 12) when
  its timestamp matches the accepted target timestamp and its source mask is
  nonzero. Passive decay alone does not create a new event. Its values, source
  mask, and timestamp are copied into the committed transition and into the
  open episodic accumulator. A journaled episode retains the eight-value
  affect/source snapshot and its validity mask and physical timestamp through
  active, warm, and archived records. Retrieval publishes all eight values to
  workspace content and the mask and timestamp to workspace metadata.
- **Decision:** the planner adds a small candidate value for pleasure or relief
  on homeostatic options and a small pain caution term based on candidate damage
  and effort. The existing risk estimate, admissibility test, risk budget, and
  stop path remain separate from this score.
- **Learning:** the v12 committed-transition affect salience can add up to 0.5
  relative emphasis to general and body-transition losses when source evidence
  is present. Episodic replay also exposes validated affect values, source mask,
  and timestamp to MLX. Neither path alters the separate risk-transition
  weighting.

Committed transition ABI v12 is 1,152 bytes. Its affect payload contains eight
floats—pain, pleasure, relief, and five source-evidence values—followed by a
source-validity mask, a reserved zero field, and the accepted timestamp. The
existing eight factored-reinforcement values remain distinct: factor 0 records
the signed change in total homeostatic potential, and factor 4 remains the
separate pain reinforcement field. Core `EpisodicRecord` format 2 and Metal
episodic-record format 3 store the same affect payload with a source mask and
timestamp. The Metal memory-record layout, workspace metadata, active-episode
accumulator, archive-page payload, and MLX replay batch are independently
versioned; older episode and archive layouts fail closed.

## Limits

These channels encode the current simulator's normalized receptor model. The
mapping, gains, time constants, and downstream modulation are engineering
choices, not clinically calibrated measures. Passing CPU or Metal consistency
checks establishes software behavior only; it does not establish biological
validity, subjective experience, or safety in a physical organism. Any such
claims require separate evidence from an appropriately validated system.

Typed-schema CPU/Metal parity includes a synthetic one-receptor fixture. A
separate synthetic 416-receptor Metal test checks per-source aggregation and
rejects recovery when one receptor is invalid. A synthetic regression confirms
that a fresh critical-physiology event still selects the protective reflex
stop when stored pleasure is maximal. These tests do not exercise a native
NumanX feed or physical intervention. A native enabled/disabled pair was
attempted on 2026-09-20, but both arms stopped after 103 accepted roots when
step 104 was rejected at the Human support-contact certification gate. The
frozen 10,002-root horizon was not reached, so no complete behavior comparison
or benefit result exists. Isolated diagnostic replays identify the same
`NM_STATUS_CONTACT_FAILURE` on support row 12 in both arms, with normal impulse
`-0.000127762556`; the row maps to the left calcaneus foot capsule. No earlier
per-row impulse history was retained to establish when it became invalid or
which change would safely correct it. The diagnostic disabled prefix also has
one step-30 sensor-packet fingerprint mismatch despite matching channel-value
and validity hashes, so it does not establish exact matched provenance. The
retained failure review and protocol identities are in
`evidence/affect-native-pair-20260920/README.md`. This software evidence does
not establish behavioral benefit, physiological calibration, or physical
safety.

Gate C accepts `--affect-mode enabled|disabled`. The experiment CLI accepts an
explicit `affectiveModelConfiguration` inside each `CaptureInput`; older
single-capture input without that field defaults to the reference enabled
configuration. `numi-brain-experiment study-affect` accepts one frozen protocol,
publication, native path set, and distinct run identifiers, with nested
`enabledCapture` and `disabledCapture` inputs. It requires matching settings
apart from the enabled bit, then captures and evaluates both fresh runs. The
first root uses a synthetic bootstrap sensor packet, now explicitly tagged
as such; its hash is not treated as native initial-sensor evidence. Eligible
pairs must use the same authored Matter package and bridge-validated prepared
initial-state fingerprint, match retained native world and physics identities,
and contain accepted native aggregate sensor samples in both arms. The paired
artifact retains those identities, bootstrap provenance, matching bootstrap
sensor status, first native aggregate sample hashes, affect fingerprints,
run/evaluation hashes, and behavior metrics. Eligibility also requires both
evaluations to produce a behavior result; a rejected root leaves that arm's
result absent and prevents the pair from being marked comparable. The first
native aggregate sample is retained for each arm but is not required to match:
it follows the first treated root and may contain a real behavioral effect.
The matched baseline is the authored world, prepared initial-state fingerprint,
and byte-verified bootstrap sensor sample. Format-5 capture-run artifacts
retain native world identity and prepared-state fingerprints; format 4 (affect
configuration) and historical format-2/3 artifacts remain readable.
`behaviorComparisonEligible` remains a
software evidence gate, not evidence that a native pair has run or that affect
improves behavior.

The study config contains `artifactDirectory`, `protocolSHA256`,
`enabledCapture`, and `disabledCapture`. Each capture repeats the same
`artifactDirectory`, `protocolSHA256`, `publicationSHA256`, and native assets.
For a material-backed world, `nativePaths` contains `library`, `rigid`, `muscle`,
`contacts`, `visualPack`, `visionProfile`, `metalRoboMetallib`,
`matterMetallib`, and `material`. A comparison-eligible study instead supplies
the same `authoredMatterWorld` object to both captures, including package,
Human/world fingerprints, source joint-equality and joint-limit payloads and
fingerprints, plus an NHINIT1 prepared initial-state path and fingerprint. Its
`nativePaths` map omits `material`. Use distinct `runIdentifier` values and
otherwise identical capture settings. Each explicit affect configuration
contains `isEnabled`, the three decay constants,
`maximumEvidenceAgeMicroseconds`, the two gains, and all five `sourceWeights`.
The disabled arm must differ only in `isEnabled: false`; the enabled arm sets
`isEnabled: true`. The study currently rejects watchdog and connectome capture
overlays so the causal contrast stays limited to affect mode.

Matched synthetic Metal regressions verify that fresh pleasure can change
workspace selection, restorative option value, committed learner input, and
the active episode's salient memory event. A forced accepted-root round trip
also verifies affect through journal creation, warm compression, archive
promotion, archive paging, and retrieval into workspace content and metadata.
MLX replay tests accept v3 episode affect fields and reject the previous record
and warm-layout versions. Selected-configuration tests cover accepted recovery
gains and evidence-age rejection, planner decay, checkpoint continuation and
cross-configuration restore rejection, and rejected-evidence rollback. These
remain software checks, not native NumanX behavioral or physiological
qualification.
