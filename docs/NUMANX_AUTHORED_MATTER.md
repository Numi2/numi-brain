# Authored Matter worlds in the joint runtime

NumanX can load an existing cooked Matter package through native configuration
v3. The Swift bridge and Gate C root runner use the same native preparation,
proof, rejection, application and joint-publication path as the legacy fixture.
No Python stepping or alternate physics owner is introduced.

An `AuthoredMatterWorld` supplies a package path, the expected Human source
fingerprint and the expected cooked-world fingerprint. Native admission checks
the package layout, exact identities, one-environment/unsubcycled deterministic
execution, supported topology, source gravity/timestep, and each attachment's
initial body-frame position and velocity. A mismatch rejects construction;
there is no fallback to the old one-tet world. Native world metadata distinguishes
an authored package from the legacy fixture and is included in capture summaries.

The identities are trusted-process compatibility keys, not cryptographic source
provenance. A loaded package is not automatically an anatomical or calibrated
model. Configuration v3 does not load joint equalities. General articulated contact proxies, adaptive topology,
general anatomical mass partitioning and continuum replacement of muscle force remain
separate integration gates. Packages with nonzero active-fibre tension are
rejected until a replacement map can remove the corresponding MyoSim force
share. MyoSim retains its existing force authority.

## Build and run

For command-line SwiftPM builds on macOS:

```sh
swift build --build-tests --jobs 2
tools/build_swiftpm_mlx_metallib.sh
```

The second command builds MLX's support shaders from the same pinned dependency
checkout as its C++ code, and installs the resource beside the CLI and XCTest
executables. It does not change or step NumanX physics.

Existing `numi-brain-gate-c capture` arguments remain valid. Select exactly one
world input:

```text
--material PATH
```

for the legacy fixture, or:

```text
--matter-world PATH --human-source-fp HEX --matter-world-fp HEX
```

for an authored Matter package. The remaining Human assets, shader paths,
immutable policy/run identities and timestep are still required. The native
runtime must export configuration v3 for the authored option.

## Source joint equalities through configuration v4

`AuthoredMatterWorld` accepts an optional `sourceJointEqualities` descriptor:

```swift
let equalities = try MetalNumanXBridgeV1Runtime.SourceJointEqualities(
  payloadPath: "source-joint-equalities.nheq", fingerprint: equalityPayloadFNV1a64)
let world = try MetalNumanXBridgeV1Runtime.AuthoredMatterWorld(
  packagePath: "world.nmatterpack", humanSourceFingerprint: baseHumanFingerprint,
  worldFingerprint: cookedWorldFingerprint, sourceJointEqualities: equalities)
```

The descriptor selects native `mrnx_bridge_v1_runtime_create_v4`. Its C layout
is 192 bytes: v4 header, nested 168-byte v3 configuration at offset 8, NHEQ2
path at offset 176, and expected equality fingerprint at offset 184. Both
nested v3 and v2 headers remain valid. The NHEQ2 path must be nonempty and the
fingerprint must be nonzero FNV-1a64 over the exact immutable payload bytes.
Native admission owns validation of the source program and physical solve.
An unavailable v4 entry point fails before construction; the bridge cannot
silently create an unconstrained v3 world instead. Existing v1/v2/v3 callers
retain their behavior when no equality descriptor is supplied.

Gate C adds the paired arguments:

```text
--joint-equalities PATH --joint-equality-fp HEX
```

They require the complete authored-world arguments, and cannot accompany
`--material`. `--human-source-fp` remains the **base** NHRIGID/NHMYO/NHCNT
identity used for authored-world admission. The native runtime's resulting
`info.modelSourceFingerprint` additionally binds the NHEQ2 program. With
64-bit wrapping arithmetic, its value is:

```text
mixed = (baseHumanFingerprint XOR FNV1a64("NHEQ2")) * FNV_PRIME
mixed = (mixed XOR equalityPayloadFNV1a64) * FNV_PRIME
if mixed == 0: mixed = FNV_OFFSET
FNV_PRIME  = 0x100000001b3
FNV_OFFSET = 0xcbf29ce484222325
```

Consequently, adding or changing source equalities changes the live physical
source identity even when the cooked-world fingerprint and base payloads stay
unchanged. Old world-admission identities must not be substituted for the
constrained runtime identity in downstream sensor or transaction evidence.

The existing authored joint-root test selects v4 when both
`NUMANX_JOINT_EQUALITIES` and `NUMANX_JOINT_EQUALITY_FP` are provided. It checks
the exact domain-mixed runtime identity; optional
`NUMANX_CONSTRAINED_HUMAN_SOURCE_FP` adds an externally supplied comparison.
The descriptor and C layout also have a CPU-only test. This source integration
is separate from executing and qualifying the constrained native physics;
no sustained behavior or anatomical claim follows from loading NHEQ2.

## Source joint limits through configuration v6

`AuthoredMatterWorld.sourceJointLimits` carries an NHLIM1 path and nonzero
FNV-1a64 fingerprint. It requires `sourceJointEqualities` and selects native
configuration v6 (240 bytes). The limit path/fingerprint are at offsets
200/208; optional costal cartilage, binding and fingerprint are at 216/224/232.
The complete costal group may accompany NHLIM1. Missing v6 support fails
before construction; it cannot silently discard limits or tissue ownership.

Gate C accepts `--joint-limits PATH --joint-limit-fp HEX` alongside the
authored-world and equality arguments. The configured end-to-end test uses
`NUMANX_JOINT_LIMITS` and `NUMANX_JOINT_LIMIT_FP`. It checks the source identity,
all admitted ranges in native anatomy, preserved source reset offsets and the
existing accepted/rejected joint-root transaction. A separate test mutates
fingerprint, source/policy, indices, padding and source inverse weight and
requires native rejection.

Native identity first admits the base world, then folds NHEQ2 and NHLIM1,
then optional NHTMASS1. The NHLIM1 fold is the same XOR/multiply sequence
shown above with `"NHLIM1"` and the limit payload fingerprint. Neural
observation/action authority, accepted-only learning and the root deadline
remain unchanged.

Native anatomy marks source-compliant ranges explicitly. The joint topology
retains `sourceCompliantLimit=true` and the exact source reset position, even
when it lies outside the compliant interval. Legacy topology still requires
an in-range rest position and retains its encoding/fingerprint. Brain does
not clamp or otherwise write physical coordinates. Source compliance and
short accepted transactions do not establish hard-bound containment,
calibration, loaded anatomical convergence or sustained standing/walking.

## Qualification boundary

The macmini qualification uses three small pelvis-attached FEM samples, twelve
nodes/attachments, the 157-body/128-DoF/416-muscle Human and the existing Brain
joint-root test. Both authored and legacy paths publish eight accepted roots at
100 microseconds per root, reject and replay a candidate exactly, preserve
unpublished sensor generations, and exercise committed learning/held-out roots.
The authored case also checks the exact loaded package metadata.

This is 0.8 milliseconds of accepted physical time per test. It establishes
asset admission and transactional integration, not sustained standing, walking,
biological fidelity, production throughput or whole-Human completion. The
cross-repository evidence is retained by `numilab-human` in
`Docs/NUMANX_AUTHORED_WORLD_QUALIFICATION.md`.

The source-equality qualification additionally runs the authored case through
v4 with all 51 pinned rows and the legacy case unchanged. Both pass with
`MTL_DEBUG_LAYER=1` (2 tests, 0 failures, 37.869 seconds), including exact retry
and forced-timeout rejection. Test-only private-buffer snapshots now use
checked GPU readbacks. The exact source/binary/input receipt is retained in
Human's `Docs/media/numanx-source-equalities-20260908/`; the bounded 0.8 ms
horizon and sustained-behavior limitations above still apply.

## Anatomical costal mass ownership through configuration v5

`CostalTissueOwnership` supplies immutable NHCART1 and NHTBIND1 paths plus the
binding's FNV-1a64. It requires an authored Matter package and source joint
equalities. The Gate C CLI accepts the same descriptor through
`--costal-cartilage`, `--costal-binding`, and `--costal-binding-fp`.

The descriptor selects `mrnx_bridge_v1_runtime_create_v5`. The 224-byte layout
contains v4 at offset 8, cartilage path at 200, binding path at 208 and binding
fingerprint at 216. Missing v5 is a typed construction failure; it cannot
silently select additive tissue mass through an older constructor. Swift only
transports this descriptor. Native construction owns source-byte validation,
actual cooked nodal mass subtraction, rigid inertia and COM rebase, muscle and
support point rebasing, source equality composition and package admission.

The base world-admission Human key is unchanged. The returned constrained
model identity additionally hashes `NHTMASS1`, the binding FNV64 and world
FNV64, each integer encoded little-endian. Tissue state uses the existing
physical-root preparation, joint publication and rollback protocol.

The authored-world integration test accepts `NUMANX_COSTAL_CARTILAGE`,
`NUMANX_COSTAL_BINDING` and `NUMANX_COSTAL_BINDING_FP` together with its world
and NHEQ2 environment. This fixture uses a 10-microsecond physical interval,
a 2 GiB retained-byte limit and a 60-second physical-completion wait. The wait
is a test hardware deadline, not a solver tolerance or a performance claim.
The non-costal fixture retains its original parameters.

The anatomical source remains fourteen regions with 13,516 nodes, 46,278
tetrahedra and 2,871 torso attachments. All rib/sternal endpoints resolve to
torso 20. These contracts do not establish independent rib articulation,
experimental tissue calibration, sustained control or real-time operation.
