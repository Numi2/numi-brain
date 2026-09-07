#!/usr/bin/env python3
"""Cold-path male CNS v1.0 acquisition and NUMICNS1 compilation. Never steps a brain.

python3 -m pip install -r tools/connectome-requirements.txt
python3 tools/import_male_cns.py fetch --cache PATH
python3 tools/import_male_cns.py compile --cache PATH --output PATH.numicns

The release lock binds every input byte. Anatomical counts are retained separately
from explicitly assumed functional weights; unclassified traced neurons and isolated
catalog neurons are retained, not silently pruned. Native C++ validates the output.
"""
from __future__ import annotations
import argparse
import collections
import csv
import ctypes as C
import hashlib
import json
import math
import mmap
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
BASE = 'https://storage.googleapis.com/flyem-male-cns/v1.0/connectome-data/flat-connectome/'
LOCK = ROOT / 'Contracts/MaleCNS_v1.sources.json'
FNV_OFFSET = 14695981039346656037
# Model assumptions, NOT experimentally established signs for every synapse.
NT_PRIOR = {'acetylcholine': 1, 'gaba': -1, 'glutamate': -1, 'histamine': -1,
            'dopamine': 0, 'octopamine': 0, 'serotonin': 0, 'unclear': 0, '': 0}
# Only explicit annotations assign interface roles. "tbc" remains unbound.
ROLES = {'ol_sensory': 1, 'vnc_sensory': 1, 'cb_sensory': 1,
         'ascending_neuron': 16, 'sensory_ascending': 17,
         'descending_neuron': 8, 'sensory_descending': 9,
         'vnc_motor': 2, 'cb_motor': 2}


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def sha256(path: Path) -> str:
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sources(lock_path: Path) -> dict:
    lock = json.loads(lock_path.read_text())
    require(lock.get('dataset') == 'male-cns:v1.0', 'unsupported release lock')
    require(set(lock['files']) == {'annotations', 'neurotransmitters', 'weights'}, 'incomplete source lock')
    for item in lock['files'].values():
        require(Path(item['name']).name == item['name'], 'source name must be a basename')
        require(item['url'] == BASE + item['name'], 'source URL is outside the pinned official release')
        require(isinstance(item['bytes'], int) and 0 < item['bytes'] <= 2*1024**3, 'source byte budget')
        digest = item['sha256']
        require(len(digest) == 64 and all(c in '0123456789abcdef' for c in digest), 'invalid source digest')
    return lock


def check_source(path: Path, item: dict) -> None:
    require(path.is_file() and not path.is_symlink(), f'missing/nonregular source: {path}')
    require(path.stat().st_size == item['bytes'], f'source size mismatch: {path.name}')
    require(sha256(path) == item['sha256'], f'source digest mismatch: {path.name}')


def fetch(cache: Path, lock: dict) -> None:
    cache.mkdir(parents=True, exist_ok=True)
    for item in lock['files'].values():
        target = cache / item['name']
        if target.exists():
            check_source(target, item)
            print(f'verified cached {target.name}', flush=True)
            continue
        fd, temporary = tempfile.mkstemp(prefix='download-', dir=cache)
        try:
            with os.fdopen(fd, 'wb') as out, urllib.request.urlopen(item['url'], timeout=120) as response:
                require(response.geturl() == item['url'], 'unexpected source redirect')
                count = 0
                for block in iter(lambda: response.read(8*1024**2), b''):
                    count += len(block)
                    require(count <= item['bytes'], 'download exceeded pinned byte count')
                    out.write(block)
                out.flush(); os.fsync(out.fileno())
            check_source(Path(temporary), item)
            # No replacement of a concurrently created cache entry.
            os.link(temporary, target)
            print(f'downloaded and verified {target.name}', flush=True)
        finally:
            Path(temporary).unlink(missing_ok=True)


class Native:
    """Compile the repository's owning C++ frontend, not a Python pack validator."""
    def __init__(self, directory: Path):
        abi = ROOT / 'Sources/NumiBrainConnectomeABI'
        output = directory / ('libconnectome.dylib' if sys.platform == 'darwin' else 'libconnectome.so')
        subprocess.run([os.environ.get('CXX', 'clang++'), '-std=c++20', '-O2', '-Wall', '-Wextra',
                        '-Wpedantic', '-Werror', '-dynamiclib' if sys.platform == 'darwin' else '-shared',
                        '-fPIC', '-I', str(abi/'include'), str(abi/'NumiBrainConnectomeABI.cpp'),
                        '-o', str(output)], check=True)
        self.lib = C.CDLL(str(output))
        self.lib.nb_connectome_fnv1a_update.argtypes = [C.c_uint64, C.c_void_p, C.c_size_t]
        self.lib.nb_connectome_fnv1a_update.restype = C.c_uint64
        self.lib.nb_connectome_validate.argtypes = [C.c_void_p, C.c_size_t, C.c_uint64, C.c_void_p]
        self.lib.nb_connectome_validate.restype = C.c_uint32
        self.lib.nb_connectome_status_message.argtypes = [C.c_uint32]
        self.lib.nb_connectome_status_message.restype = C.c_char_p

    def update(self, seed: int, data) -> int:
        if hasattr(data, 'ctypes'):
            return self.lib.nb_connectome_fnv1a_update(seed, data.ctypes.data, data.nbytes)
        raw = bytes(data)
        return self.lib.nb_connectome_fnv1a_update(seed, raw, len(raw))

    def validate(self, path: Path) -> None:
        with path.open('rb') as f, mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_COPY) as mapped:
            pointer = C.c_char.from_buffer(mapped)
            view = C.create_string_buffer(104)
            status = self.lib.nb_connectome_validate(C.addressof(pointer), len(mapped), 1024**3, view)
            del pointer
            require(status == 0, self.lib.nb_connectome_status_message(status).decode())


def unsigned_column(column, name: str):
    import numpy as np
    import pyarrow as pa
    require(pa.types.is_integer(column.type) and column.null_count == 0, f'{name} must be non-null integer')
    values = column.to_numpy(zero_copy_only=False)
    require(bool(np.all(values >= 0)), f'{name} contains negative integers')
    return values.astype('<u8', copy=False)


def compile_graph(cache: Path, output: Path, lock: dict, *, minimum_synapses: int = 1,
                  alpha: float = 0.2, recurrent_scale: float = 1.0, maximum_edges: int = 100_000_000) -> dict:
    import numpy as np
    import pyarrow as pa
    import pyarrow.feather as feather
    require(isinstance(minimum_synapses, int) and minimum_synapses >= 1, 'invalid synapse threshold')
    require(math.isfinite(alpha) and 0 < alpha <= 1, 'alpha outside (0,1]')
    require(math.isfinite(recurrent_scale) and 0 < recurrent_scale <= 64, 'recurrent scale outside (0,64]')
    require(0 < maximum_edges <= 100_000_000, 'edge capacity outside (0,100M]')
    require(not output.exists(), 'output exists; choose a new output path')
    paths = {key: cache/item['name'] for key, item in lock['files'].items()}
    for key, path in paths.items(): check_source(path, lock['files'][key])
    table = feather.read_table(paths['annotations'])
    for column in ['bodyId', 'status', 'superclass', 'type', 'somaSide']:
        require(column in table.column_names, f'missing annotation column {column}')
    ids = unsigned_column(table['bodyId'], 'bodyId')
    require(bool(np.all(ids > 0)) and np.unique(ids).size == ids.size, 'duplicate/zero annotation identity')
    annotation_rows = table.num_rows
    status = table['status'].to_pylist(); classes = table['superclass'].to_pylist()
    selected = np.asarray([s not in ('Glia', 'Unimportant') and (s == 'Traced' or c is not None)
                           for s, c in zip(status, classes, strict=True)])
    positions = np.flatnonzero(selected)
    positions = positions[np.argsort(ids[positions], kind='stable')]
    body_ids = ids[positions]; n = len(body_ids)
    require(0 < n < 2**32-1, 'node index capacity')
    types = table['type'].to_pylist(); sides = table['somaSide'].to_pylist()
    labels = [types[i] or f'body:{int(ids[i])}' for i in positions]
    classes = [classes[i] or '' for i in positions]
    sides = [sides[i] or '' for i in positions]
    flags = np.asarray([ROLES.get(c, 4) for c in classes], dtype='<u4')
    nt_table = feather.read_table(paths['neurotransmitters'], columns=['body', 'consensus_nt'])
    nt_ids = unsigned_column(nt_table['body'], 'neurotransmitter body')
    require(np.unique(nt_ids).size == nt_ids.size, 'duplicate neurotransmitter identity')
    nt_values = nt_table['consensus_nt'].to_pylist()
    mapping = {int(i): t or '' for i, t in zip(nt_ids, nt_values, strict=True)}
    nt_names = [mapping.get(int(i), '') for i in body_ids]
    unexpected = set(nt_names) - set(NT_PRIOR)
    require(not unexpected, f'unknown neurotransmitter labels: {sorted(unexpected)}')
    signs = np.asarray([NT_PRIOR[t] for t in nt_names], dtype=np.float64)
    del table, mapping, nt_table, nt_ids, nt_values

    def map_ids(values):
        index = np.searchsorted(body_ids, values)
        keep = index < n
        keep &= body_ids[np.minimum(index, n-1)] == values
        return index, keep

    parts, counts = [], []
    rows = retained_rows = 0
    # Feather v2 is Arrow IPC. Read bounded batches, never deserialize the full
    # segment graph into Python dictionaries or float-valued neuron IDs.
    with pa.memory_map(str(paths['weights']), 'r') as mapped:
        reader = pa.ipc.RecordBatchFileReader(mapped)
        require(all(c in reader.schema.names for c in ['body_pre', 'body_post', 'weight']), 'unsupported weights schema')
        schema = str(reader.schema)
        for batch_index in range(reader.num_record_batches):
            batch = reader.get_batch(batch_index)
            pre = unsigned_column(batch.column(reader.schema.get_field_index('body_pre')), 'body_pre')
            post = unsigned_column(batch.column(reader.schema.get_field_index('body_post')), 'body_post')
            weight = unsigned_column(batch.column(reader.schema.get_field_index('weight')), 'weight')
            require(bool(np.all(weight <= 2**32-1)), 'synapse count exceeds bounded integer capacity')
            rows += batch.num_rows
            require(rows <= 500_000_000, 'source row capacity exceeded')
            a, ak = map_ids(pre); b, bk = map_ids(post); keep = ak & bk & (weight > 0)
            retained_rows += int(keep.sum())
            require(retained_rows <= maximum_edges, 'mapped row capacity exceeded')
            if np.any(keep):
                parts.append((b[keep].astype('<u8')*np.uint64(n) + a[keep]).astype('<u8'))
                counts.append(weight[keep])
    require(bool(parts), 'no weighted connections resolve in selected neurons')
    keys = np.concatenate(parts); raw_counts = np.concatenate(counts); del parts, counts
    order = np.argsort(keys, kind='stable')
    keys = keys[order]; raw_counts = raw_counts[order]; del order
    starts = np.r_[0, np.flatnonzero(keys[1:] != keys[:-1])+1]
    keys = keys[starts]; raw_counts = np.add.reduceat(raw_counts, starts); del starts
    # Maximum rows * maximum count < UInt64.max, including before aggregation.
    anatomical_synapses = int(raw_counts.sum())
    keep = raw_counts >= minimum_synapses
    removed_by_threshold = int((~keep).sum())
    keys = keys[keep]; raw_counts = raw_counts[keep]
    pre = (keys % np.uint64(n)).astype('<u4'); post = (keys // np.uint64(n)).astype('<u4'); del keys, keep
    require(len(pre) < 2**32-1, 'compiled edge capacity')
    strength = np.log1p(raw_counts.astype(np.float64)) * signs[pre]
    mass = np.bincount(post, weights=np.abs(strength), minlength=n)
    values = (recurrent_scale*strength/np.maximum(mass[post], 1)).astype('<f4')
    # Keep zero-prior anatomical edges. A zero assumed weight does not imply no synapse.
    edge_counts = np.bincount(post, minlength=n)
    offsets = np.r_[np.uint64(0), np.cumsum(edge_counts, dtype=np.uint64)].astype('<u4')
    touched = np.zeros(n, dtype=bool); touched[pre] = True; touched[post] = True
    nodes = np.zeros(n, dtype=np.dtype([('f', '<f4', 8), ('u', '<u4', 4)]))
    nodes['f'][:, 0] = alpha; nodes['f'][:, 2:5] = 1; nodes['f'][:, 5] = 8
    nodes['u'][:, 0] = (body_ids & np.uint64(0xffffffff)).astype('<u4')
    nodes['u'][:, 1] = (body_ids >> np.uint64(32)).astype('<u4'); nodes['u'][:, 2] = flags
    manifest = {'format': 'NUMICNS1', 'compiler_version': 1, 'dataset': lock['dataset'],
                'license': lock['license'], 'sources': lock['files'],
                'compiler_sha256': sha256(Path(__file__)),
                'dependencies': {'numpy': np.__version__, 'pyarrow': pa.__version__},
                'selection': 'status not Glia/Unimportant AND (Traced OR superclass is nonnull)',
                'resolution': 'neuron', 'minimum_synapses_after_pair_aggregation': minimum_synapses,
                'preserve_isolated_neurons': True, 'alpha_at_nominal_step': alpha,
                'recurrent_scale': recurrent_scale, 'nt_prior': NT_PRIOR,
                'normalization': 'scale*log1p(count)*prior(source)/max(destination_L1,1)',
                'counts': {'source_annotation_rows': annotation_rows, 'neurons': n,
                           'source_weight_rows': rows, 'mapped_positive_weight_rows': retained_rows,
                           'neuron_pair_edges': len(pre), 'isolated_neurons': int((~touched).sum()),
                           'removed_pairs_by_threshold': removed_by_threshold,
                           'mapped_synapses_before_threshold': anatomical_synapses,
                           'retained_synapses': int(raw_counts.sum()), 'zero_prior_edges': int((values == 0).sum()),
                           'nt_labels': dict(collections.Counter(nt_names))},
                'scientific_boundary': 'Anatomical connectivity with assumed rate dynamics/signs; no biological or behavioral qualification.'}
    source_fp = int.from_bytes(hashlib.sha256(canonical(lock)).digest()[:8], 'little') or 1
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='numibrain-import-') as tmp:
        native = Native(Path(tmp))
        fp = write_pack(output, native, body_ids, nodes, offsets, pre, values, labels, manifest, source_fp)
    port_path = output.with_suffix(output.suffix+'.ports.csv')
    with port_path.open('x', newline='') as f:
        w = csv.writer(f); w.writerow(['node_index', 'body_id', 'type', 'superclass', 'soma_side', 'flags', 'consensus_nt'])
        for i in range(n): w.writerow([i, int(body_ids[i]), labels[i], classes[i], sides[i], int(flags[i]), nt_names[i]])
    report = {'graphFingerprint': f'{fp:016x}', 'sha256': sha256(output), 'bytes': output.stat().st_size,
              'portsSHA256': sha256(port_path), 'manifest': manifest}
    output.with_suffix(output.suffix+'.report.json').write_bytes(canonical(report)+b'\n')
    return report


def write_pack(output: Path, native: Native, ids, nodes, offsets, pre, weights,
               labels: list[str], manifest: dict, source_fp: int) -> int:
    import numpy as np
    n, e = len(ids), len(pre)
    texts = [s.encode('utf-8') for s in labels]
    lens = np.asarray([len(s) for s in texts], dtype='<u8')
    label_offsets = np.r_[np.uint64(0), np.cumsum(lens, dtype=np.uint64)]
    require(int(label_offsets[-1]) < 2**32, 'label capacity')
    label_section = label_offsets.astype('<u4').tobytes()+b''.join(texts)
    metadata = canonical(manifest)
    h = native.update(FNV_OFFSET, struct.pack('<IIQQQ', 1, 0, source_fp, n, e))
    sections = [ids, nodes, offsets, pre, weights, label_section, metadata]
    for section in sections[:5]: h = native.update(h, section)
    for text in texts:
        h = native.update(h, struct.pack('<Q', len(text))); h = native.update(h, text)
    h = native.update(h, struct.pack('<Q', len(metadata))); h = native.update(h, metadata)
    h = h or 1
    fd, temporary = tempfile.mkstemp(prefix='graph-', dir=output.parent)
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(bytes(256)); starts = []
            for section in sections:
                f.write(bytes((-f.tell()) % 64)); starts.append(f.tell())
                f.write(memoryview(section).cast('B') if hasattr(section, 'dtype') else section)
            total = f.tell()
            require(total <= 1024**3, 'graph exceeds native file budget')
            q = [n, e, h, source_fp, *starts[:5], starts[5], len(label_section), starts[6], len(metadata), total, *([0]*15)]
            f.seek(0); f.write(struct.pack('<8s4I29Q', b'NUMICNS1', 256, 1, 0, 0, *q)); f.flush(); os.fsync(f.fileno())
        native.validate(Path(temporary))
        os.link(temporary, output)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return h


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('command', choices=['fetch', 'compile'])
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--lock', type=Path, default=LOCK)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--minimum-synapses', type=int, default=1)
    args = parser.parse_args()
    lock = sources(args.lock)
    if args.command == 'fetch': fetch(args.cache, lock)
    else:
        require(args.output is not None, 'compile requires --output')
        print(json.dumps(compile_graph(args.cache, args.output, lock, minimum_synapses=args.minimum_synapses), indent=2))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'male-CNS import failed: {error}', file=sys.stderr)
        sys.exit(1)
