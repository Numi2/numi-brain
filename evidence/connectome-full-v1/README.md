# Full male CNS v1.0 import evidence

Exact importer revision: `5cd5b5e9d406c624a1e5ae7e18fd3f2c15cefcba`.
GitHub Actions run: `34167014862`, completed successfully.
Artifact: `10034492806` (`male-cns-full-native-5cd5b5e9d406c624a1e5ae7e18fd3f2c15cefcba`).

The attached logs/report describe the actual complete retained graph, not the
three-neuron test fixture. Source file SHA-256 locks are in Contracts. The
216,220,498-byte compiled graph is intentionally not committed to Git. Rerun the
pinned importer or use the retained data artifact; do not put its bytes into
source-control history.

The pack was independently checked again with the repository's C++ validator in
the Linux development workspace. Full-file SHA-256 matched
`db2a30c4d4989ff036733d72764b06c08988cd97016774e68d91421b6bf6a647`.
This establishes data acquisition/compilation/structural validation, not neural
GPU execution, electrophysiological accuracy or robot behavior.

Source dataset: HHMI Janelia / FlyEM and collaborators, Male CNS v1.0,
https://male-cns.janelia.org/download/ and
https://github.com/flyconnectome/2025malecns . Dataset license: CC BY 4.0.
The derived pack applies the selection and surrogate-weight transformations
explicitly recorded in import-report.json. Neural membrane constants, unknown
transmitter effects and robot-specific sensor/motor mappings are not measured
by this anatomical dataset.
