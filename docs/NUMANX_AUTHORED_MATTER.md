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
model. Joint equalities, general articulated contact proxies, adaptive topology,
source mass partitioning and continuum replacement of muscle force remain
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
