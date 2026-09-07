# Male CNS v1.0 data attribution

The underlying Male CNS connectome is credited to Berg et al. (2025) and the
Male CNS collaboration: FlyEM at HHMI Janelia Research Campus, the University
of Cambridge Department of Zoology, the MRC Laboratory of Molecular Biology,
and Google Research.

Source dataset and license notice: https://male-cns.janelia.org/download/
Research reference: https://doi.org/10.1101/2025.10.09.680999
Supplemental data: https://github.com/flyconnectome/2025malecns
License: Creative Commons Attribution 4.0 International (CC BY 4.0),
https://creativecommons.org/licenses/by/4.0/

NumiBrain's NUMICNS1 files are a modified data representation, not an official
Male CNS release. The transformation selects neurons by the recorded annotation
rule, aggregates directed neuron-pair counts, maps identifiers to sparse-array
indices, and adds assumed normalized signed weights and rate-model parameters.
The exact selection, source-file SHA-256 digests, parameter assumptions, compiler
identity, anatomical counts and transformed counts are retained in the pack's
manifest and companion report. The annotation CSV retains original body IDs.
The compiled derivative is distributed under CC BY 4.0 with this attribution.

No endorsement by the original data contributors is implied. Anatomical
connectivity does not establish measured electrophysiology, trained robot
behavior, biological equivalence, or authorization to control real hardware.
Zero-weight uncertain/modulatory edges remain structurally present and do not
assert those connections are biologically inactive.

Compiled graph: male-cns-v1.numicns, 216220498 bytes.
SHA-256: db2a30c4d4989ff036733d72764b06c08988cd97016774e68d91421b6bf6a647
Compiler source revision: 5cd5b5e9d406c624a1e5ae7e18fd3f2c15cefcba.
