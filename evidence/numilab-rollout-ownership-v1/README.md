# NumiLab rollout ownership: verified source and execution boundary

Date: 2026-09-08.
Runtime implementation: `cb2475e3ae29e5e619662a66a9abd4396aac5d26`.
Native owner: `4a369ca846fde93016f3708f3fd9386c992b52a4`.
Final diagnostic implementation: `c15a4ed49e6f11341e6f54c1b05577e94171f8f6`.

## Published changes

The native C bridge retains the actual compiled action table, complete immutable
layout and last accepted counters. Nonfinite/malformed commands and counter
exhaustion fail before native execution. A failed native call, external identity
or binding drift, inconsistent acceptance, or unavailable accepted-state digest
quarantines the bridge. Failed outputs are cleared; quarantine is not rollback.
The initial C fault-containment work was retained from `a620ec29...` without
rewriting concurrent muscle-control work or force-updating main.

`7534766a...` serializes whole native advance/digest and replay operations through
an exclusive recursive owner gate. Every receipt retains the policy revision
actually passed to native execution. Replay's optional policy-revision argument
is an assertion, never replacement evidence. Failed replay targets are quarantined
rather than published as restored. Counter and receipt checks are overflow-safe.

`cb2475e3...` requires a completed successful motor-submission ticket instead of a
bare buffer lease. It checks candidate/substep identity and terminal producer
feedback before reading commands. Shared storage is required; managed/private
storage is not silently treated as synchronized. Buffer arithmetic is checked.
The root's base physical generation must equal the native accepted-step count;
stale/reused roots and arbitrary generation offsets fail before physics.

The existing Brain joint transaction remains the neural publication owner.
These additions are host-action compatibility, not GPU-resident atomic
Brain/robot execution. See `docs/NUMILAB_REPLAY_OWNERSHIP.md` for the tightened
`ticket:` API and lifecycle requirements.

## Successful Apple verification

Run: https://github.com/Numi2/numi-brain/actions/runs/34277524727
Exact runtime revision: `cb2475e3ae29e5e619662a66a9abd4396aac5d26`.
Conclusion: success.

Observed:

- Complete SwiftPM release build including every package and test target.
- 65 selected Apple tests, zero failures, including new concurrency, receipt,
  physical-generation and shared-storage readiness tests.
- 23 native graph/binding/decoder tests; 12 connectivity tests; 6 Arrow/import
  tests; 7 release acquisition tests; 12 native bridge fault tests.
- Fault fixture compilation against the actual pinned NumiLab C header. The
  fixture itself is synthetic and does not establish physical simulation.
- Real Franka/G1/X500 metadata export and Swift import.

Artifact: `10076719821`, `connectome-package-cb2475e3ae29e5e619662a66a9abd4396aac5d26`.
Archive SHA-256: `499be08e9c72b4850066bc4e54bec806519183b5f4b8d7fa6c175e7ac9a20b0b`.

The earlier `7534766a...` package/selected-test job `34276561026` also passed,
with 61 selected tests. It is not substituted for the final runtime result.
Four access-gate concurrency tests additionally executed with the actual gate
source in an isolated Linux SwiftPM package; this is not a full Linux build.

The full graph shader check reports:

```text
nodes=166700 edges=25582938
referenceDestinations=130 maxError=2.9802322e-08
device=Apple Paravirtual device productionRootExecuted=false
```

The sampled error is not an exhaustive reference comparison. Shader execution
and passing source tests do not establish physical control or learned behavior.

## Real native replay: failed, not qualified

The new `numilab-owner-replay.yml` builds the actual pinned NumiLab dylib and
shaders. Its C++ harness creates separate Franka/G1/X500 worlds and requires
four-step resident-digest and final-q replay, plus changed-command divergence.
No alternative simulator, neural policy or synthetic physical receipt is used.

The first failure at `d22052ad...` was a CMake library-output path mistake.
`b980d83...` corrected the library and rpath to `build/lib/`. The real library,
shaders and harness then built successfully, but the first physical execution
stopped during native contact-pipeline initialization:

```text
task-rollout publication failed: failed to create device-resident contact pipeline: Compilation failed
```

`00b7a5db...` added per-kernel diagnostics. Its strict-compiler conditional syntax
was corrected in `c15a4ed...`; warnings were not disabled. The final diagnostic
compiled successfully and ran the exact 109 kernel names requested by the pinned
MetalWorld initializer, using its same Metal pipeline-creation overload.

Diagnostic run: https://github.com/Numi2/numi-brain/actions/runs/34279465871
Artifact: `10077199560`, `numilab-owner-replay-c15a4ed49e6f11341e6f54c1b05577e94171f8f6`.
Archive SHA-256: `2c3cf24e98f3acf8d86bee109f047875d2fdb40b53d78c0d093302f82a3e5cab`.

Observed device: Apple Paravirtual device, unified memory, 32768-byte maximum
threadgroup memory, `supportsFamily(MTLGPUFamilyMetal4) == false`.
All 109 functions were present. 80 pipelines were created; 29 failed with
`CompilerError`, code 2, `Compilation failed`. The driver did not give a more
specific cause. Failure names are retained in the artifact's `pipelines.txt`.
They include collision/CCD, scan/scatter and constraint-solving kernels, not
just an optional display path. No failed solver was removed or bypassed.

Consequently the three-body replay check did not complete, no accepted physical
replay was established, and the native workflow remains failed. The lack of
Metal 4 support is an observed device capability; it is not proof that every
kernel will succeed on a different device. Target-hardware execution still has
to demonstrate that. A successful CMake build is not pipeline-runtime validation.

## Still outstanding

The actual connectome-to-mounted-sensors closed loop, joint physical
rollback/publication, durable paired Brain/physics persistence, robot-specific
learning and held-out outcomes remain unfinished. No trained robot checkpoint
was produced. Replay from action history is O(recorded steps), not an O(1)
resident snapshot, and a physical replay entry is not a Brain root-commit receipt.
Only jointly committed transitions may enter learning and lived memory.

The earlier assessment that only CI observation remained was too narrow.
The new real native execution test establishes a concrete additional blocker;
source, interface, shader and physical-outcome claims remain separate.
