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
  mask, and timestamp are also copied into the committed transition.
- **Decision:** the planner adds a small candidate value for pleasure or relief
  on homeostatic options and a small pain caution term based on candidate damage
  and effort. The existing risk estimate, admissibility test, risk budget, and
  stop path remain separate from this score.
- **Learning:** the v12 committed-transition affect salience can add up to 0.5
  relative emphasis to general and body-transition losses when source evidence
  is present. It does not alter the separate risk-transition weighting.

Committed transition ABI v12 is 1,152 bytes. Its affect payload contains eight
floats—pain, pleasure, relief, and five source-evidence values—followed by a
source-validity mask, a reserved zero field, and the accepted timestamp. The
existing eight factored-reinforcement values remain distinct: factor 0 records
the signed change in total homeostatic potential, and factor 4 remains the
separate pain reinforcement field.

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
NumanX feed or physical intervention. No paired native NumanX comparison with
affect enabled versus a matched control has been produced, and this evidence
does not establish behavioral benefit, physiological calibration, or physical
safety.

Matched synthetic Metal regressions also verify that fresh pleasure can change
workspace selection, restorative option value, committed learner input, and
the active episode's salient memory event. The memory assertion observes the
committed accumulator before journaling by raising the test fixture's episode
boundary threshold; it is a software-path check. Selected-configuration tests
cover accepted recovery gains and evidence-age rejection, planner decay,
checkpoint continuation and cross-configuration restore rejection, and
rejected-evidence rollback. CPU affect tests pass 14/14; these remain software
checks, not native NumanX behavioral or physiological qualification.
