# Native affect pair diagnostic replay

Both copied capture configs ran independently from the exact prepared initial state with the isolated diagnostic products and `MRNX_PHYSICAL_DIAGNOSTICS=1`; each stopped at the original step-104 rejection. Config deltas are limited to artifact output directory, three native product paths, and diagnostic run ID. Each output directory contains byte-identical copies of the original protocol and publication input artifacts.

- **Enabled:** Matter code 6 (`NM_STATUS_CONTACT_FAILURE`), row 12, normal impulse `-0.000127762556`, support norm `0.00201139692`, rigid norm `0.000509521575`; failure artifact `c4deae102c444fef1759704d73c63988694069e431cbc77d1f2fd03338b1389b.artifact`. See [log](../logs/enabled-physical-diagnostics.log) and [report](enabled-capture-report.json).
- **Disabled:** identical Matter status, row, impulse, and norms; failure artifact `4873c4f0c2a1c08f0cc0a4db523cba31d54d12bd60b0c1adf6fcb10ff0e84bbc.artifact`. See [log](../logs/disabled-physical-diagnostics.log) and [report](disabled-capture-report.json).
- Both have 103 accepted records and the rejected step 104. Enabled replay accepted sample hashes match its original arm at all 103 steps. Disabled replay matches 102/103; only step 30’s sample artifact hash differs, while all seven channel value/validity hashes match. The paired diagnostic replays have the same one step-30 sample-hash difference; step 104 rejected sample hashes agree.
- NHCNT2 row 12 is zero-based authored primitive 6’s endpoint A: capsule, engine body 152, source geometry 406, radius 0.02 m, friction 1.0. Retained samples/execution records do not include per-row support impulse history for earlier roots.

No safe solver or contact-input correction is established from this one failing row; a correction requires row history, trajectory, and contact-validity evidence.

This evidence is diagnostic only. It does not complete the one-second horizon or establish a pain/pleasure behavior result.
