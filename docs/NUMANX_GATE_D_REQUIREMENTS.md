# Gate D — physical and biological validation

Status: validation implementation active; physical/biological qualification open.
Base runtime revision: `59892e55eca06dc00d3fb80f0979afd9ef419e26`.
Development branch: `codex/gate-d-physical-validation`.

Gate D is independent of Gate C's learned-policy qualification. This increment
implements independent numerical checks, trace comparison, reference import,
and retained-capture verification. It does not establish that NumanX passes
those checks on its native physical models. No clinical, biological-calibration,
comparative state-of-the-art, or whole-body fidelity claim is made.

## Ownership

`NumiBrainValidation` is a Foundation-only Swift library using FP64 offline
reference arithmetic. `NumiBrainCore/Validation/BrainGateDEvidence.swift` adapts
existing content-addressed NumanX captures. `numi-brain-gate-d` exposes both.

The production Metal hot loop, FP32 authoritative physical state, root
transactions, protective motor path, and MLX parameter publication are not
changed. There is no Python physics path, additional production GPU timeline,
or new per-root host readback. Reading settled artifacts is an offline boundary.
The reference library can be checked on Linux without claiming an Apple build.

## Required native evidence

| Required suite | Implemented evaluator | Native/independent evidence still required |
| --- | --- | --- |
| Effective tangent | Action/inverse round trips; central directional differences with active-set identity | Separate native action and inverse calls; residual perturbations using the owner's manifold retraction; multiple directions and epsilon levels |
| Attachment accounting | Independent point displacement, virtual work, linear/angular impulse and energy residuals | Native point Jacobians, applied generalized forces, all external/support impulses, stored/kinetic energy, actuator work and dissipation |
| Physical sweeps | Complete Cartesian coverage; three-level Richardson/GCI estimates | Fixed timestep, stiffness, mass-ratio, friction/stiction and contact-stack experiments; failures and inconclusive cells retained |
| Execution-path comparison | Scaled state/trace differences; paired outcome statistics | Matched monolithic/fast-path episodes, exact horizons and configuration, error and failure-rate curves including command failures |
| Standalone reductions | Coordinate-scaled coupled/standalone comparisons | Zero-attachment and zero-stiffness native runs with identical initial states and forcing |
| Generalized-force ownership | Source registry, exactly-once application, assembly and independent total | Stable physical-source identities across MyoSim/NHTENDON; actual applied force and independently reconstructed force |
| Held-out biology | Time-weighted RMSE, peak error and signed bias; explicit units/frames | Independent activation, tendon force, joint reaction, pose and effort data; anatomy/coordinate correspondence and held-out subjects/episodes |
| Perturbations and ablations | Wilson recovery intervals and deterministic paired bootstrap | Independent matched episodes/subjects; prespecified lesions/ablations, recovery definition, observation horizon and censored/failure loss |
| Material calibration | Analytic stress/tangent/energy checks; held-out trace comparison | Independent mechanical experiments, separated calibration/evaluation sources, constitutive stress measure and uncertainty |

The suite identifiers are available with `numi-brain-gate-d suites`. A supplied
probe is not an authenticated native measurement. The library deliberately does
not issue a production admission receipt or a complete Gate D promotion.

## Numerical contracts

All residuals require explicit physical normalization scales and tolerances.
No universal anatomical or clinical tolerances are invented. Fix them before
capture, justify them against numerical resolution and experimental uncertainty,
and preserve failed results. A failing test cannot be repaired by fitting a
new threshold to the already observed result.

Tangent checks report an active-set change as **inconclusive**; they do not
misapply a smooth central derivative at a contact transition. Non-smooth cases
need a separately declared one-sided or generalized-derivative experiment.
Inverse checks require both `A(solve(b))` and `solve(A(v))`. Point displacement
is checked independently of the virtual-work dot product.

Momentum accounting uses one fixed world frame and origin. Include static
support reactions as external impulses. Energy includes kinetic and stored
potential/strain energy. Gravity counted as potential is not counted again as
external work. Dissipation is positive removed energy; external and actuator
work are signed. The contact check uses an orthonormal contact frame, a circular
Coulomb cone, complementarity, dissipativity and sliding-force direction. It
is not a box-cone approximation. Compliant contact needs its declared
constitutive gap correction, not a relabeled geometric gap.

A MyoSim force transmitted through NHTENDON remains one physical source.
Diagnostic transfers are retained but must have `applied=false`. Duplicates
fail even when their numerical contributions cancel. The independent force
total and required source registry also detect omissions.

Richardson analysis requires decreasing equal-ratio steps and resolved,
monotonically contracting differences. It reports order and an absolute fine-
level GCI using the three-level safety factor 1.25. Normalization uses a declared
physical scale, not a potentially zero observable. Flat/unresolved and
oscillatory results are inconclusive, divergence fails. This estimates
discretization uncertainty; three points alone do not establish an asymptotic
regime or physical accuracy. Verify a suitable refinement ratio and additional
levels/directions as part of the native study [1].

Analytic references cover constant-acceleration motion, three damping regimes
of a linear oscillator, constant-time-constant activation, and incompressible
neo-Hookean uniaxial deformation. They verify these particular equations, not
arbitrary NumanX models. For the material reference,
`W = mu/2 * (lambda^2 + 2/lambda - 3)`,
`P = dW/dlambda = mu * (lambda - lambda^-2)`, and
`dP/dlambda = mu * (1 + 2*lambda^-3)`.
`P` is first Piola stress, not Cauchy stress. Constant-tau activation is not a
claim to reproduce the complete state-dependent MyoSim activation law.

## Trace and reference-data contracts

A `PhysicalTrace` names quantity, unit, frame and exact coordinate. Comparison
never infers or fits sign, scale, phase, time offset or coordinate correspondence.
Candidate invalid values cannot be dropped. Exact alignment requires identical
relative clocks. Optional linear interpolation of the reference requires an
explicit gap bound and forbids extrapolation. Integer microsecond clocks are
subtracted before conversion to Double.

RMSE and signed bias are integrated over physical time using the declared
piecewise-linear sampled error; dense frame capture does not receive extra
weight. Peak error is the peak at the compared samples. These metrics cannot
resolve transients between captures; conduct a capture-rate study. Minimum
physical duration is explicit, so a few accepted microsteps do not silently
become a long-horizon biological experiment.

`PhysicalReferenceImport` supports validated trace JSON and a documented scalar
OpenSim `.sto` subset. The latter requires `nRows`, `nColumns`, `endheader`, a
first `time` column in seconds, and a specifically selected scalar column.
Nonuniform sampling is supported. Version 1 and old headers without a version
are supported; angular `inDegrees` declarations must match `rad`/`deg` selection.
No implicit degree/radian conversion is performed. Vec3/SpatialVec, `.mot`, C3D,
filtering, derived quantities and automatic retargeting are not implemented.
Time quantization must stay within a declared bound of at most 0.5 microseconds.
Malformed, non-finite, repeated-time and ragged tables fail [2].

A reference artifact binds the raw source and import specification by SHA-256.
Verification actually re-imports those bytes and compares the derived trace.
Changing the trace and assigning it a new hash cannot detach it from the raw
source. This establishes transformation integrity, not that the stated source
is an independent experiment or that its licensing declaration is correct.

Wilson 95% recovery intervals are retained, including for small perfect runs
[3]. Paired bootstrap resamples whole independent units, not individual physics
roots. Unique labels prevent literal duplicate units but do not prove statistical
independence; repeated measurements of one subject must be aggregated or handled
by a separately specified hierarchical analysis. Keep failed/censored episodes
with their prespecified losses. Homogeneous small samples can yield degenerate
percentile intervals; the accompanying Wilson intervals and sample counts remain
visible. Statistical output alone has no invented pass/fail threshold.

## Executable commands

These are working synthetic diagnostics, not retained native measurements:

```sh
swift run numi-brain-gate-d probe --input Examples/GateD/energy-pass.json
swift run numi-brain-gate-d probe --input Examples/GateD/energy-fail.json
swift run numi-brain-gate-d probe --input Examples/GateD/tangent-inconclusive.json
swift run numi-brain-gate-d import-reference \
  --input Examples/GateD/synthetic-force.sto \
  --specification Examples/GateD/force-import.json
```

Exit codes: 0 for diagnostic pass or descriptive output; 1 for failure; 2 for
inconclusive; 64 for invalid command options; 65 for invalid data/evidence.
Every probe report has `promotable=false`. The synthetic `.sto` fixture is not
an experimental dataset.

On an Apple host with the full Core target, first retain an independently
obtained raw source and an explicit import specification:

```sh
swift run numi-brain-gate-d retain --input reference.sto --artifact-dir artifacts
swift run numi-brain-gate-d retain --input import.json --artifact-dir artifacts
swift run numi-brain-gate-d export-reference --artifact-dir artifacts \
  --source-sha SOURCE_SHA --specification-sha IMPORT_SHA
swift run numi-brain-gate-d verify-reference --artifact-dir artifacts --trace-sha REFERENCE_SHA
```

Author and retain an exact native sensor schema: model source fingerprint,
compiled species fingerprint, modality, receptor/feature dimensions, owner
schema revision and per-feature quantity/unit/frame/coordinate prefix. Do not
infer biological meanings from raw feature positions. This declaration needs
review against the actual native owner ABI.

Fill `Examples/GateD/trace-protocol.template.json` with the exact runtime,
parameter, accepted-state-proof program, sensor schema and reference identities;
declare physical scales, thresholds, duration, rejection budget and calibration
shards. The template is deliberately invalid until completed. Retain it and use
its hash as `--dataset-revision` in the **existing** `numi-brain-gate-c capture`
command. The protocol contains no future capture/trace hash, avoiding a hash
cycle. The new evaluator requires that revision binding; a post-hoc changed
protocol cannot verify against the old capture. Existing unbound captures can
be inspected, but cannot pass this protocol-bound comparison.

```sh
swift run numi-brain-gate-d export-sensor --artifact-dir artifacts \
  --run-sha RUN_SHA --schema-sha SCHEMA_SHA --receptor RECEPTOR --feature FEATURE
swift run numi-brain-gate-d verify-sensor --artifact-dir artifacts --trace-sha TRACE_SHA
swift run numi-brain-gate-d evaluate-trace --artifact-dir artifacts \
  --protocol-sha PROTOCOL_SHA --trace-sha TRACE_SHA
swift run numi-brain-gate-d verify-evaluation --artifact-dir artifacts --evaluation-sha EVALUATION_SHA
```

The adapter runs the existing full capture verifier, reads raw sensor bytes,
checks exact episode/scene/body and sensory-program identity, and checks
accepted/rejected time and generation continuity. Repeated identical receptor
acquisitions are not counted as new samples; different contents at one receptor
timestamp fail. Invalid observations remain invalid. Rejection counts remain
in the report and are evaluated against the declared budget. Command-failed
capture graphs are rejected by the existing verifier, not converted into
successful physical evidence; separate native failure-rate studies must retain
those incidents.

**Capture phase matters:** Gate C stores settled input receptors *before* the
attempted root. The trace uses receptor acquisition time, not the root's target
time. It does not invent the last root's endpoint. A native post-commit physical
snapshot exporter is still needed for direct state, force-ledger and tangent
measurements that these sensor captures do not contain.

Evaluation verification reconstructs the candidate and reference and recomputes
the metrics. Exact reference/calibration hash overlap is rejected. Hashes cannot
prove semantic/laboratory independence of differently encoded data; independent
study design and provenance review remain necessary. Every retained evaluation
stays `promotable=false`; no new admission capability is minted.

## Verification in this change set

`bash scripts/validate-gate-d-portable.sh` copies the actual reference sources,
tests and CLI into a temporary Foundation-only Swift package. It neither patches
the production package nor removes local runtime evidence. On Swift 6.2.1,
`x86_64-unknown-linux-gnu`, **55 XCTest cases passed with zero failures**. The
portable CLI compiled and demonstrated pass/fail/inconclusive behavior plus
reference import. Separate smoke checks exercised usage and invalid-data exits.

Six additional `BrainGateDEvidenceTests` are authored for Apple Core and were
not executed here. Swift frontend parsing passed for the integration sources
and tests; parsing is not target-platform type checking. No full repository
build, macOS/Core execution, Metal/MLX execution, native physical run, independent
biological dataset evaluation, performance measurement or Gate D qualification
was performed. Logs in `evidence/gate-d-validation-v0.1/` have only this scope.

On the supported Apple host, run `swift test --filter NumiBrainValidationTests`,
`swift test --filter BrainGateDEvidenceTests`, then existing Gate A/B native
checks with configured assets. Keep skips distinct from passes. Populate the
native/independent evidence matrix above and preserve all failed outcomes before
making a physical-validation claim. Gate C remains unchanged and open.

## Method sources

[1] NASA NPARC Alliance, *Examining Spatial (Grid) Convergence*, including temporal
refinement, Richardson assumptions and GCI reporting:
https://www.grc.nasa.gov/www/wind/valid/tutorial/spatconv.html

[2] OpenSim documentation, *Storage (.sto) Files*, scalar table headers, time and
angular-unit semantics:
https://opensimconfluence.atlassian.net/wiki/spaces/OpenSim/pages/53089996/Storage%2B.sto%2BFiles

[3] NIST/SEMATECH e-Handbook, *7.2.4.1 Confidence intervals*, Wilson score method:
https://www.itl.nist.gov/div898/handbook/prc/section2/prc241.htm
