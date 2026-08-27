# Protective motor-output boundary v0.2

This document defines the first executable mapping from accepted fast neural
state to per-muscle control values. It is a protective foundation, not the
complete motor cortex, cerebellar, CPG, spinal, or autonomic hierarchy.

## Causal position

```text
accepted receptor interrupt
  -> scheduler and regional fast prefix
  -> species-neutral protective command
  -> immutable body/muscle profile
  -> per-muscle protective excitation residual
  -> next physical-candidate GPU buffer view
```

An accepted event can affect only the following physical candidate. Rejected
events launch neither command derivation nor motor mapping. Root abort restores
the prior committed command, output header, and excitation generation.

## Compiled ABI

`NBMotorChannelDescriptor` is a 32-byte immutable channel record containing a
stable muscle identifier; valid, withdrawal, and postural-brace flags; resting
excitation; withdrawal and brace gains; maximum excitation; and zeroed reserved
fields. The compiled validator rejects empty profiles, duplicate identifiers,
unknown flags, nonfinite or out-of-range values, gain/flag disagreement,
resting excitation above the maximum, and a zero maximum. A field-wise FNV-1a
fingerprint binds the ordered profile without hashing padding.

`NBMotorOutputHeader` is a 64-byte record paired with a contiguous FP32 muscle
excitation array. It binds format and emergency-stop flags, physical timestamp,
brain generation, motor-profile and source-command fingerprints, muscle count,
environment, descending inhibition, autonomic arousal, and a field-wise
fingerprint covering every excitation. Consumers must compare its profile
identity and muscle count with the body profile they own.

## Mapping

For channel `i`, the protective residual is:

\[
p_i = \operatorname{clip}\left(
\operatorname{fma}\left(b, g_i^b,
\operatorname{fma}(w, g_i^w, r_i)\right),0,m_i\right),
\]

where `w` is withdrawal drive, `b` is brace drive, `r_i` is resting excitation,
the two `g` values are profile gains, and `m_i` is the channel maximum. CPU and
Metal use the same explicit fused multiply-add order, giving exact FP32 output
and fingerprint parity.

The intended future NumanX composition is:

\[
u_i = \operatorname{clip}\left(
(1-h)u_i^{\mathrm{descending}} + p_i + u_i^{\mathrm{other\ protective}},0,1
\right),
\]

where `h` is motor inhibition. The bounded joint-root executable connects
`p_i` directly as the complete 416-channel NumanX excitation buffer; only its
first six fixture channels can currently become nonzero. It does not yet
implement this composition with voluntary, CPG, cerebellar, or other protective
terms. The current runtime owns only `p_i`, `h`, and autonomic arousal.

## Metal ownership

The Metal runtime owns one private immutable channel-profile buffer, two
private 64-byte output-header generations, two private FP32 excitation
generations, and one shared 32-byte identity/count uniform. A device barrier
connects `derive_protective_command` to `map_protective_motor_output`. The v0.1
kernel uses one lane to preserve canonical fingerprint order.

`FastSystemResult` exposes GPU addresses, byte counts, muscle count, timestamp,
generation, and profile fingerprint for the following physical candidate.
Normal execution does not read the result back; staging copies are explicit
inspection APIs.

## NumanX candidate packet

`NBNumanXMotorCandidate` is a compiled 96-byte, transaction-local handoff. It
binds the root and candidate-substep fingerprints to the accepted brain
timestamp and generation, motor-profile identity, header and excitation GPU
addresses, byte counts, muscle count, environment, and unchanged random-counter
generation. Validation cross-checks the complete root/substep relation and
rejects stale generations, misaligned or null addresses, size/count drift, and
fingerprint drift.

GPU virtual addresses are intentionally part of this ephemeral packet but not
of persistent checkpoints or parameter identity. The packet is valid only while
the owning `MetalTissueRuntime` and residency set remain alive, and only for its
named physical candidate. Retry produces a new substep fingerprint while
preserving the same accepted neural output until simulated time advances.

`MetalTissueRuntime.borrowNumanXMotorBuffers(for:)` converts the live,
unaccepted `FastSystemResult` into a lifetime-safe lease over the exact header
and excitation `MTLBuffer` objects. The lease exposes unretained opaque Metal
object handles while retaining both buffers itself, rejects stale or already
accepted candidates, and performs no staging copy or readback. The handles
remain process-local and transactional: retaining a lease does not authorize a
consumer to reuse content after the owning generation is recycled.

The standalone interop executable replaces fixture identifiers with the full
ordered source-muscle catalog loaded from the NumanX `.nhmyo` asset. The first
six channels retain deterministic fixture gains; the remaining channels have
zero neural output gain but retain NumanX passive force. An immutable catalog
maps each tendon to its ordered first and terminal route-site body identifiers
and local coordinates. Peak force is therefore mechanically localized, but the
global protective command still cannot express body-side withdrawal, and the
overload threshold is not calibrated.

## Evidence boundary

Tests establish compiled ABI identity, validation and golden persistent-state fingerprints,
exact CPU/Metal excitation output, accepted next-candidate mapping, rejected
event silence, abort restoration, commit publication, and transaction-bound
GPU-address packet validation, exact opaque-buffer identity, and stale-lease
rejection. They do not establish anatomical/body-side semantics, a body-side
localized reflex, species calibration, voluntary movement, motor learning,
autonomic physiology, biological behavior, or performance qualification.

The isolated NumanX receiver revision recorded in
`evidence/numanx-myosim-interop-v0.1` consumes a private borrowed excitation
buffer before MyoSim force evaluation and demonstrates an activation, force,
and articulated-state consequence on Apple M4 Pro. The later
`evidence/numanx-joint-root-v0.4` artifact executes the actual 416-channel
NumiBrain producer and that receiving path in one Apple M4 process, including
cross-language attachment identity, tendon-to-endpoint-body localization,
accepted feedback, and exact physical retry. It still uses separate command
queues, staged diagnostics, CPU articulated integration, and sequential root
publication. The full-muscle v0.3 and selected six-muscle v0.2 controls remain.
