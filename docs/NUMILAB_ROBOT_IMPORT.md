# Native robot topology import

`tools/export_numilab_robot.py` compiles the existing NumiLab `RobotPack`
builders and analytic articulation kinematics against a clean, pinned native
checkout. It does not duplicate robot constants, introduce a CPU physics loop,
or replace the production Metal solver.

```sh
python3 tools/export_numilab_robot.py \
  --numilab /path/to/numi-lab \
  --output-dir /existing/parent/robot-interfaces
```

The default native revision is `4a369ca846fde93016f3708f3fd9386c992b52a4`.
The revision must match the native checkout exactly, and modified/untracked
files under `include` or `src/core` are rejected. `--revision` explicitly
selects another reviewed commit. The output directory must not already exist.
The output manifest records actual file SHA-256 values, source revision,
exporter SHA-256 and compiler identity. Compare the hashes before importing.

At this native revision, the selected actual asset builders produce:

| Native RobotPack | Bodies | Joints | Actuator lanes |
|---|---:|---:|---:|
| `franka_panda` | 11 | 10 | 9 |
| `unitree_g1` | 30 | 29 | 29 |
| `px4_x500` | 1 | 0 | 4 |

The Franka lanes retain seven joint-position and two finger-position commands.
X500 retains four **rotor-mixer** commands (collective, roll, pitch, yaw), not
four joints, motor-current commands or independently specified rotor thrusts.
The native catalog's dVRK pack has no authored actuator lanes in this revision,
and no quadruped is registered. These omissions are not repaired by invented
robot anatomy or silently selecting a different robot.

## Coordinate transfer

NumiLab expresses joint axes in joint frames and joint positions as absolute
coordinates. NumiBrain's existing joint belief topology expresses axes in the
parent body frame and displacement relative to the authored rest position.
The native adapter rotates axes into the parent frame. For revolute joints,
it incorporates the rest angle into the rest-relative quaternion; for prismatic
joints, it adds the rest displacement to the parent anchor. It preserves child
COM-frame anchors and fixed joints. This avoids an incorrect zero-rest or
identity-frame approximation for real robot assets.

Before exporting, the adapter compares the **FP32-transferred** transforms with
the existing native FP64 analytic kinematics at the default configuration and
two bounded simultaneous joint perturbations. This is a cold kinematic
conformance check, not physical simulation or a learned control result.
Continuous, multi-coordinate and unbounded joints currently fail with an
explicit error instead of fabricating finite limits. A future extension must
implement their actual coordinate convention.

## NumiBrain import

`NumiLabRobotInterface` verifies expected content and source revision, validates
the actual tree and actuator targets, and exposes the existing
`NumanXJointTopologyCatalog` construction:

```swift
let imported = try NumiLabRobotInterface(
  data: nativeJSON,
  expectedSHA256: recordedSHA256,
  expectedNativeRevision: nativeCommit
)
let topology = try imported.jointTopologyCatalog(
  numanXModelFingerprint: physicalOwner.modelFingerprint
)
```

The model fingerprint **must come from the physical owner**. The export hash,
robot name and body counts are not substitutes for that authoritative model
identity. This operation compiles structural metadata; the live adapter still
compares the physical owner's compiled task/run identities with the imported
robot contract when it instantiates the execution boundary. The CLI exposes the
same cold structural operation:

```sh
swift run numi-brain-connectome import-numilab-topology \
  ROBOT.json EXPECTED_SHA256 NATIVE_COMMIT PHYSICAL_OWNER_MODEL_HEX
```

For a supported entirely position-controlled interface, `positionChannels`
compiles NumiBrain's existing physical channel records from exact native joint
bounds. Every actuator must have explicitly supplied neutral and emergency
commands. No emergency behavior is inferred. Rotor, effort, velocity, tendon
and other non-position interfaces are rejected by that method, not cast into
incompatible units. Preserve the native actuator scale, filter response,
component and terms when constructing the physical adapter.

## Live physical-owner bridge

The pinned NumiLab owner ABI now exposes the exact action-binding table retained
by the live `CompiledTaskProgram` and a canonical resident-state fingerprint.
NumiBrain therefore does not infer task action order from the cold JSON export.
Immediately before execution it rechecks the live run, world, task, action and
robot fingerprints, validates q/v ownership and actuator semantics, converts an
admitted absolute-position candidate to NumiLab's normalized task coordinates,
and advances the caller-owned `MRTaskRolloutHandle` exactly once.

After an accepted step, NumiBrain asks NumiLab itself for the resident-state
fingerprint and rechecks the rollout boundary before constructing an
`AcceptedPhysicsStateToken`. The hardened owner revision hashes the validated
**logical byte range** of every persistent continuation buffer plus resident
metadata. Metal allocation capacity/slack is explicitly excluded from physical
state identity. The owner refuses the digest for invalid, pending, stale or
in-flight resident state.

`NumiLabReplayCheckpoint` records normalized accepted actions, policy revisions,
rollout counters and the owner's physical-state fingerprint at each boundary.
Restore requires a fresh rollout with the identical immutable origin, replays
each accepted step, and requires owner fingerprint equality after every step.
Partial q/v reconstruction is not accepted as an exact restore.

The current compatibility action transport reads an authenticated lease-owned
`MTLBuffer` only when that allocation is CPU-visible (`shared` or `managed`). A
private-only motor buffer fails closed; there is no implicit unsynchronized
staging copy. A future NumiLab device-action ABI can replace this compatibility
transport without changing task ownership or joint-root semantics.

The live bridge deliberately stops before committing Brain. Existing joint-root
transaction code remains the sole authority for accept/commit/abort ordering.
The bridge also does not create mounted sensor models, infer emergency behavior,
train a robot, qualify a task policy, or establish hardware safety. Those are
separate embodiment and validation layers, not metadata-import responsibilities.

The maintained checked-out Apple CI builds the real native robot exports,
compiles the complete NumiBrain package, and feeds the exports to
`NumiLabRobotInterfaceTests`. Ordinary tests cover missing identities, wrong
trees/targets, explicit emergency values, action-contract validation and
rejection of rotor-to-joint casts. NumiLab's own macOS owner-ABI workflow builds
the full hardened native library at the pinned revision; the cold import job
only compiles the native asset/kinematic sources it actually consumes.
