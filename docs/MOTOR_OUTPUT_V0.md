# Protective motor-output boundary v0.1

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

where `h` is motor inhibition. This composition is not connected to a live
NumanX body. The current runtime owns only `p_i`, `h`, and autonomic arousal.

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

The six-channel runtime-foundation profile is a deterministic synthetic fixture.
Its identifiers and gains are not anatomy, calibration, a named species, or a
NumanX muscle catalog. The global command also lacks receptor/body-side
localization, so it cannot yet express a localized withdrawal reflex.

## Evidence boundary

Tests establish compiled ABI identity, validation and golden fingerprints,
exact CPU/Metal excitation output, accepted next-candidate mapping, rejected
event silence, abort restoration, and commit publication. They do not establish
a live NumanX consumer, physical muscle activation, localized reflexes, species
calibration, voluntary movement, motor learning, autonomic physiology,
biological behavior, or performance qualification.
