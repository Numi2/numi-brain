# Native affect diagnostic replay

The original enabled and disabled capture prefixes were rerun from the same
prepared initial state using isolated diagnostic products and
`MRNX_PHYSICAL_DIAGNOSTICS=1`. Both replays stopped at the original control-step
104 rejection after 103 accepted roots. The instrumentation only retained the
rejected support row and impulse; solve arithmetic and controller behavior were
unchanged.

Both runs report Matter `NM_STATUS_CONTACT_FAILURE`, zero-based expanded
support row 12, normal impulse `-0.000127762556`, support residual norm
`0.00201139692`, and rigid residual norm `0.000509521575`. Row 12 maps to
authored NHCNT2 primitive 6, capsule endpoint A, source geometry 406
(`foot_col3_l`) on engine body 152 (`calcn_l`). The support and rigid source
identities agree; this mapping alone does not establish that the contact is
physically calibrated or identify a safe correction. Earlier-root support
impulses were not retained in the run artifacts.

The support-primitive manifest SHA-256 is
`26c61e6a3b9f846fbfbb38c457e1c3e7c95d48e08dc97041144bfe8ff9082354`; the
MyoSim reference manifest SHA-256 is
`2cea81e64a3c8da63731ae67c40ddc39aa61d9c4d0436000e806d25005e5b6d8`. The
prepared contact and rigid input hashes are recorded in
[`reports/paired-replay-report.json`](reports/paired-replay-report.json).

The enabled replay matches its original accepted sample hashes at all 103
roots. The disabled replay differs from its original only at control step 30:
all seven channel descriptor/value/validity hashes match, but the
`sensorPacketFingerprint` and aggregate sample hash differ. The two diagnostic
arms therefore do not establish exact matched provenance. Their rejected
step-104 sample hashes do match.

The per-arm configs, logs, reports, and failure artifacts are retained below.
The complete one-second horizon was not reached, so this diagnostic pair does
not establish a behavioral result or benefit.
