# NumanX MyoSim borrowed-excitation evidence v0.1

Date: 2026-08-27

## Revisions

- NumiBrain: `31bccf5a642140832907fe71b20097d8f3328e91`
- NumanX/Numi Lab isolated branch: `b42b283f585fa1641b40fd98e592a89072a7f992`
- NumanX base: `b913350fbf46dd88e8eca2a893c08ea4c442b2b0`
- NumanX branch: `codex/numibrain-myosim-interop`

The user-owned checkout at
`/Users/home/Documents/emergentnumilife/MetalRobo` was not modified. The
receiver work was built from a clean sparse worktree on both machines.

## Device and toolchain

- Device: Apple M4 Pro
- macOS: 26.6, build 25G72
- Swift: 6.3.3
- Build: Release, AppleClang 21, Ninja, scoped
  `metalrobo_numilab_human_myosim_reference_probe` target

## NumiBrain producer qualification

`swift test` passed all 78 tests at the exact NumiBrain revision. The Metal
transaction test verifies that a still-live candidate can lend the exact
private header and excitation `MTLBuffer` objects, that their GPU addresses
match the compiled 96-byte NumanX candidate packet, and that borrowing the
same candidate after physical acceptance is rejected.

## NumanX receiver qualification

The receiver adds a transaction-local opaque `MTLBuffer` slice to the reusable
articulated operator. A dedicated Metal kernel copies one FP32 excitation per
environment-major MyoSim state into the operator-owned state sidecar before
force evaluation in the same NumanX command buffer. The submission retains the
borrowed allocation through completion. Wrong slice sizes fail before dispatch.

The full-body probe used 157 Core bodies, 128 velocity DoFs, 416 muscles, 1,815
route sites, and 143 wraps. Probe setup copied a known excitation array into a
private Metal buffer; the operator received only the private buffer object and
byte slice, not a host excitation span.

Command:

```text
/Users/n/MetalRobo-numibrain-interop/build-numibrain-interop/bin/metalrobo_numilab_human_myosim_reference_probe \
  /Users/n/numilab-human-bones-818e587.4NwFfo/input/myosim-fullbody-core-reference.nhrigid \
  /Users/n/numilab-human-bones-818e587.4NwFfo/input/myosim-fullbody-muscle-reference.nhmyo \
  --metal
```

Selected result:

```text
myosim_core_reference PASS
metal_device="Apple M4 Pro"
metal_max_borrowed_excitation_error=0
metal_max_borrowed_activation_step_error=0
metal_borrowed_generalized_force_delta=50.71484375
metal_borrowed_physical_velocity_delta=0.000558473443718
metal_borrowed_physical_configuration_delta=5.58473443718e-10
metal_applied_wraps=90
```

The physical deltas compare two accepted articulated Core steps originating
from the same body state: one driven by the second-step generalized forces
after private borrowed excitation, and one driven by an idle-excitation
control. This is a causal source-to-state response, not a throughput result.

## Evidence boundary

This evidence proves the two ends of the buffer contract on the same Apple GPU:

1. NumiBrain lends its exact resident allocation without staging or readback.
2. NumanX consumes an equivalent private allocation inside its owning MyoSim
   command buffer and produces a measurable activation, force, and state
   consequence.

It does not yet prove a single executable passing the actual NumiBrain lease to
NumanX, a shared root command buffer, atomic joint pointer publication, retry of
the physical state sidecar, a real NumanX-to-NumiBrain muscle catalog, or
performance. The current NumiBrain six-channel profile remains synthetic; the
full-body receiver probe uses its own 416-channel excitation fixture.
