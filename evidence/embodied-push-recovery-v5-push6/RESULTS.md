# Source-bound positive push recovery

This P6 controller uses the joint-path standing baseline, an accepted-root
vestibular x-velocity event, and physical spindle feedback to alter the 416
muscle commands. The event requires three consecutive delivered samples above
0.01 m/s. The committed event direction survives a velocity reversal; the
opposite direction leaves the standing motor command unchanged.

The frozen program is `program.v5.json` (SHA-256
`82e44f4ddf49e5a98f7111dd810e24c88a8a230eb315efa839d329563ffc7b23`).
The native Human binary is
`b976b85539f7329c55ef03afdcfd6efd84c8d333b3310e2f3b127c15b4cbd8e9`;
the Brain library is
`aaa10ee1c794d74cc15129fedae6497aea40d73170432c9ec87e6c75636ec02a`.
Runs used 1 ms steps, all 64 ordered contact sweeps, and zero root assistance.
The complete native logs, manifests, and rendered packs are under
`/Users/n/NumiHumanBrainRuns/embodied-push-recovery-v5-push6-20260925` on
the Mac mini. `protocol.json` was written before the P6 heldouts.

| Native comparison | Off score | On score | Improvement | Audit |
| --- | ---: | ---: | ---: | --- |
| +50 N, step 100, seed 1314213193 | 1.668 mm | 0.774 mm | 53.6% | `force50-audit.json` |
| +60 N, step 100, seed 1314213194 | 1.656 mm | 1.226 mm | 25.9% | `force60-audit.json` |
| +50 N, step 200, seed 1314213195 | 1.597 mm | 0.860 mm | 46.2% | `shifted200-audit.json` |

All three pairs passed the frozen score, support-contact, penetration,
terminal x-velocity, accepted-step, sensor, and clean-exit gates. The first
physical receptor event, muscle-command difference, and root-motion
difference were steps 103/104/105 for the first two pairs and 203/204/205 for
the shifted pair. The negative 50 N event at seed 1314213196 qualified at
step 104; its 500-step physical and sensor traces matched the off arm exactly
(`opposite50-safety-audit.json`). Negative-direction recovery is not qualified.

An independent repeat of the +50 N on arm reproduced every accepted physical
row and sensor packet (`force50-replay-audit.json`). Both rendered MRV packs
also have the same SHA-256 (`replay-pack-sha256.txt`). The paired 10,000-step
no-push standing check is still running and has no verdict here.
