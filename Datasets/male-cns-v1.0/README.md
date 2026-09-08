# Pinned male-CNS derived graph, data release r1

This is a data release, not a trained robot policy or a biological simulation
qualification. `release.json` pins the 166,700-neuron, 25,582,938-neuron-pair
NUMICNS1 pack and all attribution/provenance assets. The graph derives from
HHMI Janelia / Google / Cambridge / MRC male-CNS v1.0, licensed CC-BY-4.0:
https://male-cns.janelia.org/download/
https://creativecommons.org/licenses/by/4.0/

Changes from source: select explicitly classified neuronal records, exclude
and count non-neuronal/unclassified records, aggregate weighted neuron-pair
connections and assign declared unsigned normalized rate-model parameters.
The source data does not specify those functional dynamics. This derivative
implies no endorsement by the source authors.

Acquire the immutable release without a GitHub account or expiring CI artifact:

```sh
python3 tools/fetch_connectome_release.py --output-dir assets/connectomes/male-cns-v1.0
python3 tools/fetch_connectome_release.py --output-dir assets/connectomes/male-cns-v1.0 --verify-only
```

The downloader is standard-library-only, checks exact sizes/SHA-256, rejects
symlinked or changed cache files, bounds network transfers and publishes files
atomically without overwriting existing content. It does not load a controller.
Release tag: `data-male-cns-v1.0-numicns1-r1`. Source and derived-graph identities
are distinct; frozen graph parameters are not anatomical measurements.

Reproduce the pinned graph from official source tables:

```sh
python3 -m venv .venv-connectome
.venv-connectome/bin/python -m pip install numpy==2.5.3 pyarrow==25.0.1
.venv-connectome/bin/python tools/numi_connectome.py bootstrap \
  --source-dir assets/connectomes/source-male-cns-v1.0 \
  --output assets/connectomes/male-cns-v1.0/male-cns-v1.0-neuron-unsigned.numicns \
  --resolution neuron --minimum-synapses 1 --sign-mode unsigned
```

The importer rejects changed official bytes. The publication workflow rebuilds
from those original public tables, requires the exact derived graph and metadata
hashes, and attaches the actual compiler, Python and dependency versions. It
never rewrites `main` or silently replaces an existing release asset. A changed
model/importer requiring changed bytes needs a new reviewed data-release tag.
