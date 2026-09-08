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

The default native revision is `5db0c5aa169bfe1270ef7448e01dd7fbcd99d123`.
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
identity. This operation compiles structural metadata; the real adapter still
must compare the physical owner's model to the retained native asset when it
instantiates the world. The CLI exposes the same cold operation:

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
component and terms when constructing the eventual physical adapter.

Absolute-position channels are **not** the normalized action array consumed by
NumiLab's current PolicyProgram. Their conversion and command application must
remain in the owning physical interface. Likewise this metadata exporter does
not supply mounted sensor transduction, device validity buffers, cross-runtime
command ordering, a joint commit callback, or robot training. Those execution
interfaces must be completed before an imported body is a running connectome
robot. Empty asset-license strings are retained as missing provenance, never
filled with an assumed license.

The maintained checked-out Apple CI builds these real native exports, compiles
the complete NumiBrain package, and feeds the three exports to
`NumiLabRobotInterfaceTests`. Ordinary tests also cover missing identities,
wrong trees/targets, explicit emergency values and rejection of rotor-to-joint
casts. A passing import remains distinct from Metal 4 brain/body execution.
