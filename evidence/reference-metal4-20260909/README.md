# Reference Apple Metal 4 qualification

**Both requested exit criteria passed.** Qualification ran directly over SSH on
an actual M4 Pro Mac mini, not a hosted virtual GPU. All 109 exact production
pipelines construct, and the unchanged `numilab-owner-replay` physics workload
passes for Franka, G1 and X500 after two native-owner source fixes.

## Hardware and source identity

| Property | Recorded value |
|---|---|
| Machine | Mac mini Mac16,11; Apple M4 Pro; 12 CPU cores; 16 GPU cores; 24 GiB RAM |
| OS | macOS 26.6, build 25G72 |
| GPU families | Apple1 through Apple9; Metal3; Metal4; Mac2 |
| Metal capabilities | Unified memory; 32,768-byte threadgroup memory; max threadgroup dimensions 1024×1024×1024 |
| Buffer capacity | 14,302,248,960-byte max buffer; 19,069,665,280-byte recommended working set |
| Toolchain | Xcode 26.6; Metal 32023.883 (metalfe-32023.883); CMake 4.4.1 |
| Original hosted Brain | `c15a4ed49e6f11341e6f54c1b05577e94171f8f6` |
| Baseline M4 Brain | `a1c0bda634c19a4c2f2063f3830e5216ff3d4b95` |
| Baseline NumiLab | `4a369ca846fde93016f3708f3fd9386c992b52a4` |
| Qualified Brain | `1709c57a7cfe89c8cc2f6e43a78fdb95847b63d1` |
| Qualified NumiLab | `973676ebee749a77b950d72e30d7bcde9873e06c` |

The replay executable source, C bridge/header, and pipeline probe are unchanged
from the original failed hosted revision. The final Brain revision adds only
hardware qualification tooling/routing/documentation; later evidence-only
commits do not change the qualified workload. No neural architecture, decoder
learning or sparse kernels were changed.

Full capability, source, command, exit and hash records are in
[reference-final/result.json](reference-final/result.json),
[source-identity.json](reference-final/source-identity.json), and
[workload-hashes.json](reference-final/workload-hashes.json).
The hardware probe deliberately excludes serial numbers and hardware UUIDs.

## Production pipelines

| Run | Present | Constructed | Failed |
|---|---:|---:|---:|
| Original hosted Apple Paravirtual, no Metal4 | 109 | 80 | 29 |
| M4 Pro, original pinned owner source | 109 | 109 | 0 |
| M4 Pro, fixed owner, fresh build/process | 109 | 109 | 0 |

All 29 former failures pass **without shader changes**. This establishes no
reproduced source compilation defect on the supported target; differences in
hosted GPU/toolchain cannot be attributed exclusively to Metal4 from this test.
The inventory remains byte-identical across all runs. Every requested kernel is
listed in [pipeline-comparison.csv](pipeline-comparison.csv), with full error
records retained in [hosted/pipelines.txt](hosted/pipelines.txt).

| Kernel | Hosted | M4 original | M4 fixed |
|---|---|---|---|
| `mr_rod_tool_narrowphase` | Failed | Passed | Passed |
| `mr_world_resolve_ccd` | Failed | Passed | Passed |
| `mr_world_resolve_rod_ccd` | Failed | Passed | Passed |
| `mr_world_restore_inactive_event_candidate` | Failed | Passed | Passed |
| `mr_world_restore_inactive_rod_event_candidate` | Failed | Passed | Passed |
| `mr_world_scan_add_block_offsets` | Failed | Passed | Passed |
| `mr_world_scan_blocks` | Failed | Passed | Passed |
| `mr_world_scan_manifold_ir` | Failed | Passed | Passed |
| `mr_world_scan_rod_contact_ir` | Failed | Passed | Passed |
| `mr_world_scatter_distributed_island_queue` | Failed | Passed | Passed |
| `mr_world_scatter_distributed_tile_queue` | Failed | Passed | Passed |
| `mr_world_scatter_island_queue` | Failed | Passed | Passed |
| `mr_world_scatter_manifold_ir` | Failed | Passed | Passed |
| `mr_world_scatter_manifold_records` | Failed | Passed | Passed |
| `mr_world_scatter_pair_queue` | Failed | Passed | Passed |
| `mr_world_scatter_rod_contact_ir` | Failed | Passed | Passed |
| `mr_world_seed_authored_constraint_ir` | Failed | Passed | Passed |
| `mr_world_select_ccd_event_state` | Failed | Passed | Passed |
| `mr_world_select_observation_state` | Failed | Passed | Passed |
| `mr_world_select_solver_cohort` | Failed | Passed | Passed |
| `mr_world_solve_contact_islands` | Failed | Passed | Passed |
| `mr_world_solve_generalized_constraints` | Failed | Passed | Passed |
| `mr_world_solve_rod_contact_constraints` | Failed | Passed | Passed |
| `mr_world_tag_rod_ccd_witnesses` | Failed | Passed | Passed |
| `mr_world_unpack_rod_state` | Failed | Passed | Passed |
| `mr_world_wave32_distributed_delta` | Failed | Passed | Passed |
| `mr_world_wave32_distributed_prepare` | Failed | Passed | Passed |
| `mr_world_wave32_distributed_reduce` | Failed | Passed | Passed |
| `mr_world_wave32_solve` | Failed | Passed | Passed |

The original and final metallib SHA-256 is identical:
`eb7fe19cd4525517e99b7c61a781433a1990c7127096d2dc544da34bf97a7a19`.
Final native dylib SHA-256:
`6bc45af9726b8b320c13db92174a4d998d7a2ddc0b3297b8a49a503da98b682f`.
“Cold” means a fresh build directory and new process constructing all pipeline
objects before replay. No explicit binary archive is supplied; the OS driver
cache was not purged. No warnings, constraints, contacts or GPU solver were
removed or weakened.

## Real source defects and physical execution

1. **G1 raw-action history:** external actions read from the unallocated
   native-policy latent stream. Only resident buffer 196 differed, with 49
   stale bytes per step in the captured run. The native encoder now binds the
   supplied action stream for runs without a PolicyPack. Native-policy latent
   behavior is preserved; the existing task/policy program check also passes.
2. **X500 identity:** all persistent GPU buffers and authored program fields
   matched, but host padding at byte 204 varied. The owner now hashes all seven
   authored multicopter members individually. The full resident-state digest
   remains mandatory. The regression poisons padding differently, requires
   equality, and tests sensitivity to all seven authored members.

The exact bridge workload performs four accepted steps in each original,
replay and changed-action run for each robot: **36 accepted physical steps**.
All three require per-step resident digest equality, bitwise final-q equality,
finite final state, clean acceptance counters, stable idle inspection and
changed-command divergence. See [replay.txt](reference-final/replay.txt).

The owner regression additionally passes for one and two environments for all
three robots (108 accepted environment-steps). Franka reaches **11 active
contacts**; G1 and X500 have zero contacts in this short fixture. Contacts and
all solver stages remain present. See
[owner-regression.txt](reference-final/owner-regression.txt).

## Failed attempts retained

The initial M4 replay failed on G1; after the first fix it failed on X500. All
failed and intermediate output remains alongside the final passing receipt in
[attempt-ledger.json](attempt-ledger.json). Read-only diagnostic captures traced
both defects and are retained in the sealed local/remote archive.

Full Metal shader instrumentation, and a subsequent selective-action attempt,
failed the owner's required kernel-geometry admission before physical stepping.
Those attempts are **not passes** and do not establish shader-validator-clean
execution. The production run uses the unchanged geometry guard and default
GPU environment. Instrumentation settings followed
[Apple's shader-validation documentation](https://developer.apple.com/documentation/xcode/validating-your-apps-metal-shader-usage/).
A transfer-layout error also caused one missing-target build attempt; its log
is retained. The existing broader task-program check emits an unrelated missing
enum-case warning; it was retained, not suppressed. New probe builds retain
`-Wall -Wextra -Wpedantic -Werror`.

## Reproduce and scope

Run from clean checkouts on the reference Mac:

```sh
python3 brain/tools/qualify_numilab_reference.py \
  --native-owner /path/to/numi-lab \
  --numilab-sha 973676ebee749a77b950d72e30d7bcde9873e06c \
  --output /new/external/qualification-directory
```

The command rejects Paravirtual/non-Metal4 devices and inventory drift, records
every command and failed pipeline, and exits nonzero on any failed gate.
GitHub workflow dispatch now targets an ARM64 self-hosted `numilab-metal4` Mac.
No such GitHub runner is registered yet; this receipt came from direct SSH
execution of that same qualification command. No hosted runner is accepted as
reference qualification.

This is native-owner compile and bounded physical replay evidence. It does not
qualify Brain-root execution, standing, reaching, flight, learning, long-horizon
physics, complete scene/CCD coverage or real robot safety.

## Retained archive

The complete archive (including builds, binaries, failed attempts, diagnostic
captures and orchestration sources) contains 6,058 files / 80,547,075 bytes.
All entries were verified against the same manifest on the local host and Mac
mini. Locations are in [archive.json](archive.json). Manifest SHA-256:
`1f79b575c37bc720753c63e856e2852add256fb8701840b70e6a806a85c6f29c`.
The repository contains the compact logs and receipts; binary entries referenced
by receipt hashes are retained in that complete archive.
