# Native connectome integration

This work starts from NumiBrain `b3ff9883bd42d5274114598e49d01d7e0ae0c538`.
It imports the existing NumiLab `NUMICNS1` graph format rather than inventing
another release or placing a neuron graph on a synthetic cortical sheet.

## Data boundary

`ConnectomeGraph` validates graph identity, bounded section ranges, canonical
padding, unique neuron identifiers, finite bounded parameters, destination-major
CSR connectivity, label encoding and a JSON provenance manifest. No neurons,
connections, physiology or learned memories are invented by the loader.
FNV-1a is an interchange checksum, not authentication. Retain SHA-256 checksums
of the original release files and generated pack alongside experiment evidence.

The C++ frontend is in `NumiBrainConnectomeABI`; Swift loading and exact
receptor/readout bindings are in `NumiBrainCore`. The CLI is:

```sh
swift run numi-brain-connectome inspect /path/to/male-cns.numicns
python3 tools/test_connectome_native.py
```

The earlier NumiLab compiler can supply `.numicns` files. Its `.numibody` maps
TaskProgram observations, not NumiBrain receptor arrays, and must NOT be reused
as though those interfaces were identical. Native bindings require the exact
graph, species, sensory profile and parameter-publication fingerprints.
Input bindings must name annotated sensory/ascending neurons; outputs must
name annotated descending/motor neurons. Missing annotations are an error,
not a reason to select arbitrary neurons.

## Scientific interpretation

The source is the HHMI Janelia / Google male Drosophila CNS dataset:
https://male-cns.janelia.org/download/
https://research.google/blog/a-connectomics-milestone-mapping-the-complete-male-fruit-fly-brain/

A population/type graph is a reduction, not the complete neuron graph. Neither
representation supplies missing electrophysiology. Synapse counts are not
measured functional weights; neurotransmitter labels alone do not determine
all receptor effects. The earlier compiler's signed, log-normalized weights
are a declared surrogate and must remain identified as such in reports.
There is no automatic robot skill transfer from importing connectivity.

## Evidence

The native reader compiles on Linux with C++20, warnings treated as errors.
The portable regression suite covers round trips, all byte truncations,
section overlap, duplicate identifiers, non-finite weights, invalid CSR,
reserved header values, padding corruption and fingerprint corruption.
The standalone Swift graph/binding source was type-checked with Swift 6.2.1.
These checks do not establish an Apple Metal build, full-release execution,
real-time performance, biological validity or robot task success.
