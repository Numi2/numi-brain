# NumiBrain affective state

NumiBrain carries a small, per-agent affect state derived from accepted bodily
evidence. It represents transient pain, pleasure, and relief signals for
attention, planning, memory salience, and learning emphasis. It is a modulation
signal, not a separate reward function or a claim about subjective experience.

## Evidence and comparability

Only valid receptor observations in the accepted physical transaction are
eligible. The Metal update requires the frame to be delivered at the target
transaction timestamp, its receptor timestamp to be no later than that target,
and its age to be at most 100 ms. Interoception and touch values are read only
when their respective accepted frame metadata and scalar-validity entries agree.
Touch nociception also requires an enabled body-receptor binding for the
nociception signal. Pain events of kinds 8 and 9 can contribute pain when their
timestamps are within the same 100 ms bound.

The five-slot homeostatic vector names energy, respiration, temperature,
fatigue, and tissue damage, but the Metal path does not infer those meanings
from untyped interoception feature positions. At present it accepts only
fatigue observations with an explicit `.fatigue` muscle-receptor binding in the
compiled sensory profile, and direct nociception observations with an explicit
body-receptor binding. Unmapped interoception values cannot create pain or
pleasure. Other homeostatic channels remain available to the CPU oracle when a
caller supplies their named, normalized values; a production Metal mapping for
them requires calibrated profile entries.

Source mask bits 0–4 identify observed homeostatic channels; bit 5 identifies
fresh pain evidence from either direct nociception or pain/injury-risk event
kinds 8 and 9. The separate prior-validity mask tracks whether direct
nociception is comparable for relief; an event-only pain bit cannot establish
that baseline.

Pleasure from recovery requires a fresh observation for a channel and a prior
valid observation for that same channel. A missing source breaks that channel's
comparison; when it returns, the first sample establishes a new baseline.
Repeated, stale, future-dated, or invalid observations cannot produce recovery
or relief. The CPU `AffectiveState.advanced` implementation is the reference
oracle for these rules.

## State update

The reference source weights for energy, respiration, temperature, fatigue,
and tissue damage are `0.24, 0.24, 0.16, 0.18, 0.18`. Recovery is the weighted
sum of positive reductions in comparable deficits, capped with the resulting
pleasure state at 1. Direct relief is a positive decrease between two fresh,
comparable nociception samples. It increases both relief and pleasure. Pain is
the maximum of retained pain, fresh nociception, and fresh pain/injury-risk
event evidence. A missing pain source clears the comparison baseline while
retaining the last-consumed timestamp, so a later sample cannot manufacture
relief or reuse an old frame.

Each state decays against physical elapsed time using exponential retention
`exp(-dt / tau)`: pain has a 2 s time constant, pleasure 1 s, and relief 0.5 s.
New pain, recovery, and relief are then added according to the update above and
clamped to `[0, 1]`. Passive decay does not create pleasure or relief. The
reference gains are 1, and configuration gains, weights, and time bounds are
validated and fingerprinted. The GPU currently contributes calibrated fatigue
recovery and nociception/event pain; it does not promote unspecified physiology
features into energy, respiratory, temperature, or tissue-damage evidence.

## Transaction and consumers

The 64-byte affect record lives in each agent's hot state. The Metal update runs
only after accepted sensorimotor reconciliation and only when the physical
acceptance gate is set. It writes into the transaction shadow, so a rejected
physical future does not publish the affect update. Core agent state and its
checkpoint fingerprint also include affect and its configuration identity.

The current consumers are deliberately bounded:

- **Attention:** fresh affect with a nonzero source mask and age at most 100 ms
  competes with the strongest drive for workspace slot 0. Its score is the
  maximum of pain, pleasure, and relief.
- **Memory:** affect can become the embodied salient event (event kind 12) when
  its timestamp matches the accepted target timestamp. Its values, source mask,
  and timestamp are also copied into the committed transition.
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
