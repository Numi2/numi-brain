# Source-bound Human muscle control

`numi-brain-gate-c capture --muscle-locomotor-program program.json` selects an
explicit research controller for admitted Human anatomy. `describe-body` accepts
the same native asset/world arguments and emits the model and sensory profile
fingerprints plus the SHA-256 of the NHMYO2 payload. The Human authoring command
`numi human locomotor-program` consumes that description and the same payload.

Every actuator has its own source reference path length, tonic recruitment,
length and velocity gains, excitation bound, and optional sine/cosine coefficients.
A zero period selects tonic spindle feedback. A nonzero period is an experimental
periodic recruitment candidate; it does not establish a walking policy. The
author and Brain interface validate the admitted anatomical actuator coverage
(up to the existing 4096-channel descriptor budget) rather than interpreting an index as a muscle
role. Gait phase mapping must be supplied explicitly.

The Metal 4 controller reads delivered physical path-length and path-velocity
receptors in metres and metres/second. Both feature validity bits must be set.
Unavailable, nonfinite or overflowing feedback produces zero descending command.
Bootstrap observations are unavailable. Phase derives from committed physical
time modulo the declared period, so retry or chunk boundaries cannot advance an
independent oscillator. No pose, generalized force or hidden state is a controller
input. Feedback stays on the owning command buffer before the common protective
motor adapter. Native source routes remain the force authority.

The authored program has its own motor authority. Generic option selection,
untrained effector command-model residuals, cerebellar corrections and a separate
CPG cannot add a competing command. Body/joint risk, physiology, deliberate
inhibition and the private emergency-stop adapter still apply. Native anatomy
also no longer inherits tonic excitation and reflex routing from a six-channel
transport fixture. Existing compiled species reflexes are the only such source.

The program fingerprint binds the anatomy, sensory profile, all channel values,
clock and calibration-artifact identity. Cognitive checkpoint format 5 includes
that identity; restore rejects a different program. Formats 3/4 remain readable
under their prior controller constraints. The program cannot be combined with a
connectome, external task goal or qualified uncertainty policy. Research capture
retains motor/root artifacts and a non-promotable summary; it cannot issue a legacy
Gate C qualification manifest or train an unrelated policy.

`calibrationArtifactSHA256` identifies the source NHMYO2 reference-length
artifact for uniform tonic authoring, or the exact NHINIT1 artifact for prepared
recruitment. Gains and phase coefficients are authored research parameters. Neither
that name nor successful source admission proves an experimental gain calibration.
The public tendon-tension receptor uses newtons after the native correction;
NHMYO2's legacy applied-active-force field contains the applied compliant tendon
force, including passive equilibrium contributions, not isolated contractile force.

The offline costal capture has a 60-second physical-callback budget, matching the
v5 integration test; other captures retain 30 seconds. This is a completion bound,
not a performance claim. The native source activation fix and cross-repository
receipts are documented in Human's `Docs/ACTIVE_MUSCLE_CONTROL_20260908.md`.
Sustained standing, recovery, walking and the frozen 420-trial gate remain open.

## Prepared recruitment

For a v7 prepared world, `describe-body` also exports the admitted NHINIT1 hash,
fingerprint, dimensions and world identity. Pass that description and the same
state to Human's `locomotor-program --prepared-state prepared.nhinit`, with
`--length-gain 0 --velocity-gain-seconds 0 --maximum-excitation 1`. This preserves
each prepared excitation and binds the program to the complete native model and
sensory profile. The state must be stationary, with matching excitation and
activation; source, world, clock, byte extent and finite-state checks reject drift.

Prepared tonic authoring has zero feedback gains and zero period. Its reference
length fields retain source NHMYO2 values; they do not claim reference lengths at
the new pose. Feedback or gait requires separately authored pose-specific evidence.
The inclusive excitation endpoint 1 is represented by finite logit 10, whose tanh
rounds to 1 in FP32. Values below 1 keep their existing atanh conversion. The
ordinary motor inhibition path remains in force, so the delivered command can be
less than the authored tonic value. Missing observations, including bootstrap,
produce zero command even when tonic recruitment is nonzero.

`testPreparedRecruitmentAcceptedRoots` compares four accepted roots each for the
prepared candidate, replay, zero proposal and spindle dropout. It checks exact
replay, changed native activation and applied force, bounds and dropout, while
retaining full q/v and command bytes. These are short controller transport checks;
loaded equilibrium, anatomical tissue, calibrated control and sustained behavior
remain separate requirements.
