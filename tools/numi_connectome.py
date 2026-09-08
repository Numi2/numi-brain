"""Male CNS acquisition/compiler for the shared NumiLab/NumiBrain NUMICNS1 format.

The official Janelia/Google release remains the source of truth. This module
turns its Arrow/Feather tables into compact, deterministic shared graph packs. The runtime is connectivity-grounded and parameterizable;
it does not claim that static morphology alone supplies complete biological
cell dynamics, receptor kinetics, neuromodulation, or learned state.
"""

from __future__ import annotations

import argparse
import dataclasses
import hashlib
import json
import math
import os
import re
import shutil
import struct
import sys
import tempfile
import urllib.error
import urllib.request
from collections.abc import Iterable, Iterator, Mapping, Sequence
from pathlib import Path
from typing import Any, BinaryIO, Final

import numpy as np

GRAPH_MAGIC: Final[bytes] = b"NUMICNS1"
EMBODIMENT_MAGIC: Final[bytes] = b"NUMIBDY1"
GRAPH_ABI: Final[int] = 1
EMBODIMENT_ABI: Final[int] = 1
HEADER_BYTES: Final[int] = 256
INVALID_INDEX: Final[int] = 0xFFFFFFFF
MAX_DEVICE_FEATURES: Final[int] = 256

GRAPH_RESOLUTION_NEURON: Final[int] = 0
GRAPH_RESOLUTION_CELL_TYPE: Final[int] = 1

INPUT_CLAMP: Final[int] = 1
INPUT_ABSOLUTE: Final[int] = 2

NODE_SENSORY: Final[int] = 1
NODE_MOTOR: Final[int] = 2
NODE_INTRINSIC: Final[int] = 4
NODE_DESCENDING: Final[int] = 8
NODE_ASCENDING: Final[int] = 16
NODE_VNC: Final[int] = 32
NODE_BRAIN: Final[int] = 64

FLAG_NAMES: Final[dict[str, int]] = {
    "sensory": NODE_SENSORY,
    "motor": NODE_MOTOR,
    "intrinsic": NODE_INTRINSIC,
    "descending": NODE_DESCENDING,
    "ascending": NODE_ASCENDING,
    "vnc": NODE_VNC,
    "brain": NODE_BRAIN,
}

OFFICIAL_VERSION: Final[str] = "male-cns:v1.0"
OFFICIAL_BASE: Final[str] = (
    "https://storage.googleapis.com/flyem-male-cns/v1.0/"
    "connectome-data/flat-connectome"
)
OFFICIAL_FILES: Final[dict[str, str]] = {
    "annotations": (
        "body-annotations-male-cns-v1.0-minconf-0.5.feather"
    ),
    "neurotransmitters": (
        "body-neurotransmitters-male-cns-v1.0.feather"
    ),
    "weights": (
        "connectome-weights-male-cns-v1.0-minconf-0.5.feather"
    ),
}

# Audited v1.0 source bytes. Versioned URLs alone are not content pins. A
# future source revision requires an explicit reviewed update of these hashes.
OFFICIAL_SHA256: Final[dict[str, str]] = {
    "annotations": "2177e246113e4cfbf1e7772ec37c6da1955ff22e8063d0b1f833101f99a9a3b2",
    "neurotransmitters": "95c9289220663abeb3409f3ad9e5a7f8a53f8093f5139d15502cd08da8879621",
    "weights": "e35da783d1c686b2b58b3b87cd6a403ae43bfcfba8bff28e08ef752c1a56afc1",
}

def verify_official_digest(name: str, digest: str) -> None:
    if name not in OFFICIAL_SHA256 or digest != OFFICIAL_SHA256[name]:
        raise ConnectomeError(f"official release content pin mismatch: {name}")

NODE_DTYPE: Final[np.dtype[Any]] = np.dtype(
    [
        ("dynamics", "<f4", (4,)),
        ("modulation", "<f4", (4,)),
        ("identity", "<u4", (4,)),
    ],
    align=False,
)
INPUT_DISK_STRUCT: Final[struct.Struct] = struct.Struct("<8I4f")
GRAPH_HEADER_STRUCT: Final[struct.Struct] = struct.Struct("<8s4I29Q")
EMBODIMENT_HEADER_STRUCT: Final[struct.Struct] = struct.Struct("<8s4I29Q")

assert NODE_DTYPE.itemsize == 48
assert INPUT_DISK_STRUCT.size == 48
assert GRAPH_HEADER_STRUCT.size == HEADER_BYTES
assert EMBODIMENT_HEADER_STRUCT.size == HEADER_BYTES




class ConnectomeError(RuntimeError):
    """Raised for invalid source data, pack schemas, or user mappings."""


@dataclasses.dataclass(frozen=True)
class SourcePaths:
    annotations: Path
    neurotransmitters: Path | None
    weights: Path


@dataclasses.dataclass
class GraphPack:
    resolution: int
    source_fingerprint: int
    fingerprint: int
    node_ids: np.ndarray
    nodes: np.ndarray
    incoming_offsets: np.ndarray
    incoming_sources: np.ndarray
    incoming_weights: np.ndarray
    labels: list[str]
    manifest_json: str

    @property
    def node_count(self) -> int:
        return int(self.node_ids.size)

    @property
    def edge_count(self) -> int:
        return int(self.incoming_sources.size)


class FNV64:
    """Exact byte-order-compatible FNV-1a used by the C++ pack loader."""

    __slots__ = ("value",)

    def __init__(self) -> None:
        self.value = 14695981039346656037

    def update(self, payload: bytes | bytearray | memoryview) -> None:
        array = np.frombuffer(payload, dtype=np.uint8)
        self.value = int(_native().nb_connectome_hash_update(self.value, array.ctypes.data, array.size))

    def u32(self, value: int) -> None:
        self.update(struct.pack("<I", value))

    def u64(self, value: int) -> None:
        self.update(struct.pack("<Q", value))

    def f32(self, value: float) -> None:
        self.update(struct.pack("<f", value))

    def text(self, value: str) -> None:
        payload = value.encode("utf-8")
        self.u64(len(payload))
        self.update(payload)

    def finish(self) -> int:
        return self.value or 1


def _canonical_json(value: Any) -> str:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    )


def _u32_array(values: Any) -> np.ndarray:
    return np.ascontiguousarray(np.asarray(values, dtype="<u4"))


def _u64_array(values: Any) -> np.ndarray:
    return np.ascontiguousarray(np.asarray(values, dtype="<u8"))


def _f32_array(values: Any) -> np.ndarray:
    return np.ascontiguousarray(np.asarray(values, dtype="<f4"))


def _array_bytes(values: np.ndarray) -> memoryview:
    return memoryview(np.ascontiguousarray(values)).cast("B")


def _align(value: int, alignment: int = 64) -> int:
    return (value + alignment - 1) // alignment * alignment


def _write_padding(stream: BinaryIO, offset: int) -> None:
    current = stream.tell()
    if current > offset:
        raise ConnectomeError("pack section overlaps a previous section")
    if current < offset:
        stream.write(b"\0" * (offset - current))


def _stable_hash64(text: str) -> int:
    digest = hashlib.sha256(text.encode("utf-8")).digest()
    value = int.from_bytes(digest[:8], "little")
    return value or 1


def _stable_hash32(text: str) -> int:
    return int.from_bytes(hashlib.sha256(text.encode("utf-8")).digest()[:4], "little")


def _sha256(path: Path, block_bytes: int = 8 * 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while block := stream.read(block_bytes):
            digest.update(block)
    return digest.hexdigest()


def _source_fingerprint(paths: SourcePaths) -> int:
    digest = hashlib.sha256()
    for label, path in (
        ("annotations", paths.annotations),
        ("neurotransmitters", paths.neurotransmitters),
        ("weights", paths.weights),
    ):
        if path is None:
            continue
        digest.update(label.encode("ascii"))
        digest.update(path.name.encode("utf-8"))
        with path.open("rb") as stream:
            while block := stream.read(8 * 1024 * 1024):
                digest.update(block)
    value = int.from_bytes(digest.digest()[:8], "little")
    return value or 1


def graph_fingerprint(pack: GraphPack) -> int:
    h = FNV64()
    h.u32(GRAPH_ABI)
    h.u32(pack.resolution)
    h.u64(pack.source_fingerprint)
    h.u64(pack.node_count)
    h.u64(pack.edge_count)
    h.update(_array_bytes(pack.node_ids))
    h.update(_array_bytes(pack.nodes))
    h.update(_array_bytes(pack.incoming_offsets))
    h.update(_array_bytes(pack.incoming_sources))
    h.update(_array_bytes(pack.incoming_weights))
    for label in pack.labels:
        h.text(label)
    h.text(pack.manifest_json)
    return h.finish()


def _validate_graph(pack: GraphPack) -> None:
    if pack.resolution not in (
        GRAPH_RESOLUTION_NEURON,
        GRAPH_RESOLUTION_CELL_TYPE,
    ):
        raise ConnectomeError("unknown graph resolution")
    if pack.node_count == 0 or pack.node_count > INVALID_INDEX:
        raise ConnectomeError("graph node count is outside the 32-bit runtime ABI")
    if pack.edge_count > INVALID_INDEX:
        raise ConnectomeError("graph edge count is outside the 32-bit runtime ABI")
    if pack.node_ids.dtype != np.dtype("<u8") or pack.node_ids.ndim != 1:
        raise ConnectomeError("node_ids must be one-dimensional little-endian uint64")
    if pack.nodes.dtype != NODE_DTYPE or pack.nodes.shape != (pack.node_count,):
        raise ConnectomeError("node parameter table has the wrong dtype or shape")
    if pack.incoming_offsets.shape != (pack.node_count + 1,):
        raise ConnectomeError("incoming offset table must contain node_count + 1 entries")
    if pack.incoming_sources.shape != (pack.edge_count,):
        raise ConnectomeError("incoming source table has the wrong length")
    if pack.incoming_weights.shape != (pack.edge_count,):
        raise ConnectomeError("incoming weight table has the wrong length")
    if len(pack.labels) != pack.node_count:
        raise ConnectomeError("node label count does not match node count")
    offsets = pack.incoming_offsets.astype(np.uint64, copy=False)
    if int(offsets[0]) != 0 or int(offsets[-1]) != pack.edge_count:
        raise ConnectomeError("incoming offsets do not span the edge table")
    if np.any(offsets[1:] < offsets[:-1]):
        raise ConnectomeError("incoming offsets are not monotonic")
    if pack.edge_count and int(pack.incoming_sources.max()) >= pack.node_count:
        raise ConnectomeError("incoming source index exceeds node count")
    if not np.isfinite(pack.incoming_weights).all():
        raise ConnectomeError("incoming weights contain non-finite values")
    dynamics = pack.nodes["dynamics"]
    modulation = pack.nodes["modulation"]
    if not np.isfinite(dynamics).all() or not np.isfinite(modulation).all():
        raise ConnectomeError("node parameters contain non-finite values")
    if np.any(dynamics[:, 0] <= 0.0) or np.any(dynamics[:, 0] > 1.0):
        raise ConnectomeError("node update alpha must be in (0, 1]")
    if np.any(modulation[:, 0] <= 0.0):
        raise ConnectomeError("node output gain must be positive")
    identity = pack.nodes["identity"]
    if np.any(identity[:, 0] != (pack.node_ids & np.uint64(0xFFFFFFFF)).astype("<u4")):
        raise ConnectomeError("node identity low words do not match node IDs")
    if np.any(identity[:, 1] != (pack.node_ids >> np.uint64(32)).astype("<u4")):
        raise ConnectomeError("node identity high words do not match node IDs")


def write_graph_pack(path: Path, pack: GraphPack) -> None:
    pack.node_ids = _u64_array(pack.node_ids)
    pack.nodes = np.ascontiguousarray(pack.nodes, dtype=NODE_DTYPE)
    pack.incoming_offsets = _u32_array(pack.incoming_offsets)
    pack.incoming_sources = _u32_array(pack.incoming_sources)
    pack.incoming_weights = _f32_array(pack.incoming_weights)
    _validate_graph(pack)
    pack.fingerprint = graph_fingerprint(pack)

    label_payloads = [label.encode("utf-8") for label in pack.labels]
    label_offsets = np.zeros(pack.node_count + 1, dtype="<u4")
    cursor = 0
    for index, payload in enumerate(label_payloads, start=1):
        cursor += len(payload)
        if cursor > INVALID_INDEX:
            raise ConnectomeError("node-label blob exceeds the 32-bit label ABI")
        label_offsets[index] = cursor
    labels_blob = b"".join(label_payloads)
    labels_section = _array_bytes(label_offsets).tobytes() + labels_blob
    manifest = pack.manifest_json.encode("utf-8")

    offset = HEADER_BYTES
    node_ids_offset = _align(offset)
    offset = node_ids_offset + pack.node_ids.nbytes
    node_parameters_offset = _align(offset)
    offset = node_parameters_offset + pack.nodes.nbytes
    incoming_offsets_offset = _align(offset)
    offset = incoming_offsets_offset + pack.incoming_offsets.nbytes
    incoming_sources_offset = _align(offset)
    offset = incoming_sources_offset + pack.incoming_sources.nbytes
    incoming_weights_offset = _align(offset)
    offset = incoming_weights_offset + pack.incoming_weights.nbytes
    labels_offset = _align(offset)
    offset = labels_offset + len(labels_section)
    manifest_offset = _align(offset)
    file_bytes = manifest_offset + len(manifest)

    q_values = [
        pack.node_count,
        pack.edge_count,
        pack.fingerprint,
        pack.source_fingerprint,
        node_ids_offset,
        node_parameters_offset,
        incoming_offsets_offset,
        incoming_sources_offset,
        incoming_weights_offset,
        labels_offset,
        len(labels_section),
        manifest_offset,
        len(manifest),
        file_bytes,
        *([0] * 15),
    ]
    header = GRAPH_HEADER_STRUCT.pack(
        GRAPH_MAGIC,
        HEADER_BYTES,
        GRAPH_ABI,
        pack.resolution,
        0,
        *q_values,
    )

    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp-{os.getpid()}")
    try:
        with temporary.open("wb") as stream:
            stream.write(header)
            for section_offset, payload in (
                (node_ids_offset, _array_bytes(pack.node_ids)),
                (node_parameters_offset, _array_bytes(pack.nodes)),
                (incoming_offsets_offset, _array_bytes(pack.incoming_offsets)),
                (incoming_sources_offset, _array_bytes(pack.incoming_sources)),
                (incoming_weights_offset, _array_bytes(pack.incoming_weights)),
                (labels_offset, labels_section),
                (manifest_offset, manifest),
            ):
                _write_padding(stream, section_offset)
                stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def read_graph_pack(path: Path, verify: bool = True) -> GraphPack:
    file_bytes = path.stat().st_size
    with path.open("rb") as stream:
        header = stream.read(HEADER_BYTES)
        if len(header) != HEADER_BYTES:
            raise ConnectomeError("graph pack is shorter than its fixed header")
        values = GRAPH_HEADER_STRUCT.unpack(header)
        magic, header_bytes, abi, resolution, flags = values[:5]
        q = values[5:]
        if magic != GRAPH_MAGIC or header_bytes != HEADER_BYTES:
            raise ConnectomeError("graph pack magic or header width is invalid")
        if abi != GRAPH_ABI or flags != 0:
            raise ConnectomeError("graph pack ABI or flags are unsupported")
        (
            node_count,
            edge_count,
            fingerprint,
            source_fingerprint,
            node_ids_offset,
            node_parameters_offset,
            incoming_offsets_offset,
            incoming_sources_offset,
            incoming_weights_offset,
            labels_offset,
            labels_bytes,
            manifest_offset,
            manifest_bytes,
            recorded_file_bytes,
            *_reserved,
        ) = q
        if recorded_file_bytes != file_bytes:
            raise ConnectomeError("graph pack file length does not match its header")

        def read_array(offset: int, count: int, dtype: np.dtype[Any]) -> np.ndarray:
            width = int(np.dtype(dtype).itemsize) * count
            if offset < HEADER_BYTES or offset + width > file_bytes:
                raise ConnectomeError("graph pack array exceeds file bounds")
            stream.seek(offset)
            payload = stream.read(width)
            if len(payload) != width:
                raise ConnectomeError("graph pack array is truncated")
            return np.frombuffer(payload, dtype=dtype, count=count).copy()

        node_ids = read_array(node_ids_offset, node_count, np.dtype("<u8"))
        nodes = read_array(node_parameters_offset, node_count, NODE_DTYPE)
        incoming_offsets = read_array(
            incoming_offsets_offset, node_count + 1, np.dtype("<u4")
        )
        incoming_sources = read_array(
            incoming_sources_offset, edge_count, np.dtype("<u4")
        )
        incoming_weights = read_array(
            incoming_weights_offset, edge_count, np.dtype("<f4")
        )
        if labels_offset + labels_bytes > file_bytes:
            raise ConnectomeError("graph label section exceeds file bounds")
        stream.seek(labels_offset)
        label_section = stream.read(labels_bytes)
        offset_bytes = (node_count + 1) * 4
        if len(label_section) < offset_bytes:
            raise ConnectomeError("graph label section lacks its offset table")
        label_offsets = np.frombuffer(
            label_section[:offset_bytes], dtype="<u4"
        )
        label_blob = label_section[offset_bytes:]
        if int(label_offsets[0]) != 0 or int(label_offsets[-1]) != len(label_blob):
            raise ConnectomeError("graph label offsets are invalid")
        labels = [
            label_blob[int(label_offsets[i]) : int(label_offsets[i + 1])].decode(
                "utf-8"
            )
            for i in range(node_count)
        ]
        if manifest_offset + manifest_bytes > file_bytes:
            raise ConnectomeError("graph manifest exceeds file bounds")
        stream.seek(manifest_offset)
        manifest_json = stream.read(manifest_bytes).decode("utf-8")

    pack = GraphPack(
        resolution=resolution,
        source_fingerprint=source_fingerprint,
        fingerprint=fingerprint,
        node_ids=node_ids,
        nodes=nodes,
        incoming_offsets=incoming_offsets,
        incoming_sources=incoming_sources,
        incoming_weights=incoming_weights,
        labels=labels,
        manifest_json=manifest_json,
    )
    _validate_graph(pack)
    if verify and graph_fingerprint(pack) != pack.fingerprint:
        raise ConnectomeError("graph pack fingerprint does not match its contents")
    return pack


def _require_pyarrow() -> tuple[Any, Any]:
    try:
        import pyarrow as pa  # type: ignore[import-not-found]
        import pyarrow.feather as feather  # type: ignore[import-not-found]
    except ImportError as error:
        raise ConnectomeError(
            "connectome compilation requires the optional dependency: "
            "python3 -m pip install numpy pyarrow"
        ) from error
    return pa, feather


def _normalized_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def _resolve_column(names: Sequence[str], aliases: Sequence[str]) -> str | None:
    normalized = {_normalized_name(name): name for name in names}
    for alias in aliases:
        if key := normalized.get(_normalized_name(alias)):
            return key
    return None


def _required_column(names: Sequence[str], aliases: Sequence[str], table: str) -> str:
    value = _resolve_column(names, aliases)
    if value is None:
        raise ConnectomeError(
            f"{table} table lacks required column; tried {', '.join(aliases)}; "
            f"available columns: {', '.join(names)}"
        )
    return value


def _column_pylist(table: Any, name: str) -> list[Any]:
    return table[name].combine_chunks().to_pylist()


def _column_numpy(table: Any, name: str, dtype: Any) -> np.ndarray:
    values = table[name].combine_chunks().to_numpy(zero_copy_only=False)
    return np.asarray(values, dtype=dtype)


def _semantic_flags(superclass: str, label: str = "") -> int:
    text = f"{superclass} {label}".lower()
    flags = 0
    if "sensory" in text or "sensillum" in text or "photoreceptor" in text:
        flags |= NODE_SENSORY
    if "motor" in text or "motoneuron" in text:
        flags |= NODE_MOTOR
    if "descending" in text or re.search(r"\bdn\b", text):
        flags |= NODE_DESCENDING
    if "ascending" in text or re.search(r"\ban\b", text):
        flags |= NODE_ASCENDING
    if "vnc" in text or "ventral nerve cord" in text:
        flags |= NODE_VNC
    if any(token in text for token in ("brain", "optic", "central", "visual", "olfactory")):
        flags |= NODE_BRAIN
    if flags == 0:
        flags = NODE_INTRINSIC
    elif not (flags & (NODE_SENSORY | NODE_MOTOR | NODE_DESCENDING | NODE_ASCENDING)):
        flags |= NODE_INTRINSIC
    return flags


def _read_annotations(path: Path) -> dict[str, Any]:
    _pa, feather = _require_pyarrow()
    table = feather.read_table(path, memory_map=True)
    names = table.column_names
    body_column = _required_column(
        names, ("bodyId", "body_id", "body"), "annotation"
    )
    type_column = _resolve_column(
        names, ("type", "cell_type", "cellType", "hemibrain_type")
    )
    superclass_column = _resolve_column(
        names, ("superclass", "super_class", "class", "cell_class")
    )
    raw_ids = table.column(body_column)
    if raw_ids.null_count or not all(isinstance(v, int) and 0 < v < 2**64 for v in raw_ids.to_pylist()):
        raise ConnectomeError("annotation body IDs must be non-null positive integers")
    body_ids = _column_numpy(table, body_column, np.uint64)
    if np.unique(body_ids).size != body_ids.size:
        raise ConnectomeError("duplicate annotation body IDs")
    types = (
        _column_pylist(table, type_column)
        if type_column is not None
        else [None] * len(body_ids)
    )
    status_column = _resolve_column(names, ("status", "statusLabel", "status_label"))
    statuses = _column_pylist(table, status_column) if status_column is not None else [None] * len(body_ids)
    superclasses = (
        _column_pylist(table, superclass_column)
        if superclass_column is not None
        else [None] * len(body_ids)
    )
    return {
        "body_ids": body_ids,
        "types": ["" if value is None else str(value).strip() for value in types],
        "superclasses": [
            "" if value is None else str(value).strip() for value in superclasses
        ],
        "statuses": ["" if value is None else str(value).strip() for value in statuses],
        "columns": names,
    }


def _dominant_nt_coefficients(path: Path | None, body_ids: np.ndarray) -> np.ndarray:
    coefficients = np.ones(body_ids.size, dtype=np.float32)
    if path is None or not path.exists():
        return coefficients
    _pa, feather = _require_pyarrow()
    table = feather.read_table(path, memory_map=True)
    names = table.column_names
    body_column = _resolve_column(names, ("bodyId", "body_id", "body"))
    if body_column is None:
        return coefficients
    nt_body = _column_numpy(table, body_column, np.uint64)

    token_coefficients = {
        "acetylcholine": 1.0,
        "ach": 1.0,
        "gaba": -1.0,
        "histamine": -1.0,
        "glutamate": -1.0,
        "glut": -1.0,
        "dopamine": 0.25,
        "da": 0.25,
        "serotonin": 0.25,
        "5ht": 0.25,
        "octopamine": 0.25,
        "oa": 0.25,
        "tyramine": 0.25,
    }
    categorical = _resolve_column(
        names,
        (
            "consensus_nt",
            "predicted_nt",
            "predictedNt",
            "neurotransmitter",
            "top_nt",
            "topNt",
        ),
    )
    nt_values = np.ones(nt_body.size, dtype=np.float32)
    if categorical is not None:
        raw = _column_pylist(table, categorical)
        for index, value in enumerate(raw):
            text = "" if value is None else _normalized_name(str(value))
            for token, coefficient in token_coefficients.items():
                if _normalized_name(token) in text:
                    nt_values[index] = coefficient
                    break
    else:
        probability_columns: list[tuple[str, float]] = []
        for name in names:
            normalized = _normalized_name(name)
            for token, coefficient in token_coefficients.items():
                key = _normalized_name(token)
                if key in normalized and any(
                    marker in normalized for marker in ("prob", "score", "confidence")
                ):
                    probability_columns.append((name, coefficient))
                    break
        if probability_columns:
            scores = np.stack(
                [
                    _column_numpy(table, column, np.float32)
                    for column, _coefficient in probability_columns
                ],
                axis=1,
            )
            winners = np.nanargmax(np.nan_to_num(scores, nan=-np.inf), axis=1)
            coefficient_values = np.asarray(
                [coefficient for _column, coefficient in probability_columns],
                dtype=np.float32,
            )
            nt_values = coefficient_values[winners]

    body_order = np.argsort(body_ids, kind="stable")
    sorted_body = body_ids[body_order]
    positions = np.searchsorted(sorted_body, nt_body)
    valid = positions < sorted_body.size
    valid_indices = np.flatnonzero(valid)
    if valid_indices.size:
        valid[valid_indices] &= (
            sorted_body[positions[valid_indices]] == nt_body[valid_indices]
        )
    target = body_order[positions[valid]]
    coefficients[target] = nt_values[valid]
    return coefficients


def _iter_weight_batches(path: Path) -> Iterator[tuple[np.ndarray, np.ndarray, np.ndarray]]:
    pa, _feather = _require_pyarrow()
    source = pa.memory_map(str(path), "r")
    reader = pa.ipc.RecordBatchFileReader(source)
    names = reader.schema.names
    pre_column = _required_column(
        names, ("body_pre", "bodyPre", "pre", "source"), "weight"
    )
    post_column = _required_column(
        names, ("body_post", "bodyPost", "post", "target"), "weight"
    )
    weight_column = _required_column(
        names, ("weight", "synapse_count", "count"), "weight"
    )
    for batch_index in range(reader.num_record_batches):
        batch = reader.get_batch(batch_index)
        for name in (pre_column, post_column, weight_column):
            if batch.column(batch.schema.get_field_index(name)).null_count:
                raise ConnectomeError("null endpoint or synapse count in source weights")
        for name in (pre_column, post_column):
            column = batch.column(batch.schema.get_field_index(name))
            if not pa.types.is_integer(column.type):
                raise ConnectomeError("weight endpoint IDs must be integer typed")
            if np.any(column.to_numpy(zero_copy_only=False) < 0):
                raise ConnectomeError("weight endpoint IDs must be nonnegative")
        yield (
            np.asarray(
                batch.column(batch.schema.get_field_index(pre_column)).to_numpy(
                    zero_copy_only=False
                ),
                dtype=np.uint64,
            ),
            np.asarray(
                batch.column(batch.schema.get_field_index(post_column)).to_numpy(
                    zero_copy_only=False
                ),
                dtype=np.uint64,
            ),
            np.asarray(
                batch.column(batch.schema.get_field_index(weight_column)).to_numpy(
                    zero_copy_only=False
                ),
                dtype=np.float64,
            ),
        )


def _map_bodies(
    queried: np.ndarray,
    sorted_body_ids: np.ndarray,
    sorted_node_indices: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    positions = np.searchsorted(sorted_body_ids, queried)
    valid = positions < sorted_body_ids.size
    valid_indices = np.flatnonzero(valid)
    if valid_indices.size:
        valid[valid_indices] &= (
            sorted_body_ids[positions[valid_indices]] == queried[valid_indices]
        )
    mapped = np.zeros(queried.size, dtype=np.uint32)
    mapped[valid] = sorted_node_indices[positions[valid]]
    return mapped, valid


def _reduce_keyed_weights(keys: np.ndarray, weights: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    if keys.size == 0:
        return keys.astype(np.uint64), weights.astype(np.float64)
    order = np.argsort(keys, kind="stable")
    keys = keys[order]
    weights = weights[order]
    starts = np.concatenate(
        (np.asarray([0], dtype=np.int64), np.flatnonzero(keys[1:] != keys[:-1]) + 1)
    )
    return keys[starts], np.add.reduceat(weights, starts)


def compile_official_graph(
    sources: SourcePaths,
    *,
    resolution: str = "neuron",
    minimum_synapses: int = 1,
    recurrent_scale: float = 1.5,
    update_alpha: float = 0.2,
    state_clip: float = 8.0,
    sign_mode: str = "unsigned",
    maximum_nodes: int = 0,
    minimum_total_synapses: float = 0.0,
) -> GraphPack:
    if minimum_synapses < 1:
        raise ConnectomeError("minimum_synapses must be positive")
    if not math.isfinite(recurrent_scale) or recurrent_scale <= 0:
        raise ConnectomeError("recurrent_scale must be positive and finite")
    if not math.isfinite(update_alpha) or not (0 < update_alpha <= 1):
        raise ConnectomeError("update_alpha must be in (0, 1]")
    if not math.isfinite(state_clip) or state_clip <= 0:
        raise ConnectomeError("state_clip must be positive and finite")
    if sign_mode not in ("heuristic", "unsigned"):
        raise ConnectomeError("sign_mode must be 'heuristic' or 'unsigned'")
    resolution_code = {
        "type": GRAPH_RESOLUTION_CELL_TYPE,
        "cell-type": GRAPH_RESOLUTION_CELL_TYPE,
        "neuron": GRAPH_RESOLUTION_NEURON,
    }.get(resolution)
    if resolution_code is None:
        raise ConnectomeError("resolution must be 'type' or 'neuron'")

    if sign_mode == "heuristic" and (sources.neurotransmitters is None or not sources.neurotransmitters.is_file()):
        raise ConnectomeError("heuristic signs require the exact neurotransmitter table")
    source_hashes = {"annotations": _sha256(sources.annotations), "weights": _sha256(sources.weights)}
    if sources.neurotransmitters is not None: source_hashes["neurotransmitters"] = _sha256(sources.neurotransmitters)
    annotation = _read_annotations(sources.annotations)
    # The release annotation table also contains glia, orphan artifacts and
    # unclassified segments. Those are NOT interchangeable with neurons in
    # this rate model. Preserve every explicitly classified neuronal entry,
    # including its isolated nodes, and report excluded annotation records.
    annotation_count = len(annotation["body_ids"])
    selected = np.asarray([
        bool(superclass) and superclass.lower() not in {"unknown", "none", "glia"}
        and not any(token in status.lower() for token in ("glia", "artifact", "unimportant"))
        for superclass, status in zip(annotation["superclasses"], annotation["statuses"], strict=True)
    ], dtype=bool)
    selected_indices = np.flatnonzero(selected)
    if selected_indices.size == 0:
        raise ConnectomeError("no explicitly classified neuronal entries; refusing to simulate glia or unknown segments as neurons")
    excluded_annotations = annotation_count - int(selected_indices.size)
    body_ids: np.ndarray = annotation["body_ids"][selected_indices]
    type_labels: list[str] = [annotation["types"][i] for i in selected_indices]
    superclasses: list[str] = [annotation["superclasses"][i] for i in selected_indices]
    body_nt = (
        _dominant_nt_coefficients(sources.neurotransmitters, body_ids)
        if sign_mode == "heuristic"
        else np.ones(body_ids.size, dtype=np.float32)
    )

    if resolution_code == GRAPH_RESOLUTION_CELL_TYPE:
        labels = sorted({label for label in type_labels if label})
        if not labels:
            raise ConnectomeError("annotation table contains no valid cell types")
        label_to_node = {label: index for index, label in enumerate(labels)}
        body_to_node = np.asarray(
            [label_to_node.get(label, INVALID_INDEX) for label in type_labels],
            dtype=np.uint32,
        )
        valid_bodies = body_to_node != INVALID_INDEX
        node_ids = _u64_array([_stable_hash64(f"male-cns:v1.0:type:{label}") for label in labels])
        if np.unique(node_ids).size != node_ids.size:
            raise ConnectomeError("stable type IDs collided; compilation aborted")
        node_flags = np.zeros(len(labels), dtype=np.uint32)
        nt_sum = np.zeros(len(labels), dtype=np.float64)
        nt_count = np.zeros(len(labels), dtype=np.uint32)
        for body_index in np.flatnonzero(valid_bodies):
            node = int(body_to_node[body_index])
            node_flags[node] |= _semantic_flags(
                superclasses[body_index], type_labels[body_index]
            )
            nt_sum[node] += float(body_nt[body_index])
            nt_count[node] += 1
        node_sign = np.divide(
            nt_sum,
            np.maximum(nt_count, 1),
            out=np.ones_like(nt_sum),
            where=nt_count > 0,
        ).astype(np.float32)
    else:
        order = np.argsort(body_ids, kind="stable")
        body_ids = body_ids[order]
        type_labels = [type_labels[index] for index in order]
        superclasses = [superclasses[index] for index in order]
        body_nt = body_nt[order]
        labels = [
            label if label else f"body:{int(body)}"
            for label, body in zip(type_labels, body_ids, strict=True)
        ]
        node_ids = _u64_array(body_ids)
        body_to_node = np.arange(body_ids.size, dtype=np.uint32)
        valid_bodies = np.ones(body_ids.size, dtype=bool)
        node_flags = np.asarray(
            [
                _semantic_flags(superclass, label)
                for superclass, label in zip(superclasses, labels, strict=True)
            ],
            dtype=np.uint32,
        )
        node_sign = body_nt.astype(np.float32, copy=False)

    body_order = np.argsort(body_ids, kind="stable")
    sorted_body = body_ids[body_order]
    sorted_nodes = body_to_node[body_order]
    body_is_valid = valid_bodies[body_order]
    sorted_body = sorted_body[body_is_valid]
    sorted_nodes = sorted_nodes[body_is_valid]

    key_parts: list[np.ndarray] = []
    weight_parts: list[np.ndarray] = []
    source_node_parts: list[np.ndarray] = []
    destination_node_parts: list[np.ndarray] = []
    node_count = len(labels)
    source_edge_count = excluded_endpoint_edges = thresholded_edges = 0
    for body_pre, body_post, weights in _iter_weight_batches(sources.weights):
        if not np.isfinite(weights).all() or np.any(weights < 0) or np.any(weights != np.floor(weights)):
            raise ConnectomeError("source synapse counts must be finite nonnegative integers")
        source_edge_count += int(weights.size)
        thresholded_edges += int(np.count_nonzero(weights < minimum_synapses))
        threshold = np.isfinite(weights) & (weights >= minimum_synapses)
        if not np.any(threshold):
            continue
        body_pre = body_pre[threshold]
        body_post = body_post[threshold]
        weights = weights[threshold]
        source_nodes, source_valid = _map_bodies(body_pre, sorted_body, sorted_nodes)
        destination_nodes, destination_valid = _map_bodies(
            body_post, sorted_body, sorted_nodes
        )
        valid = source_valid & destination_valid
        excluded_endpoint_edges += int(np.count_nonzero(~valid))
        if not np.any(valid):
            continue
        source_nodes = source_nodes[valid]
        destination_nodes = destination_nodes[valid]
        weights = weights[valid]
        if resolution_code == GRAPH_RESOLUTION_CELL_TYPE:
            keys = destination_nodes.astype(np.uint64) * np.uint64(node_count) + source_nodes
            batch_keys, batch_weights = _reduce_keyed_weights(keys, weights)
            key_parts.append(batch_keys)
            weight_parts.append(batch_weights)
        else:
            source_node_parts.append(source_nodes)
            destination_node_parts.append(destination_nodes)
            weight_parts.append(weights)

    if not weight_parts:
        raise ConnectomeError("no graph edges survived annotation mapping and thresholding")
    if resolution_code == GRAPH_RESOLUTION_CELL_TYPE:
        keys, raw_weights = _reduce_keyed_weights(
            np.concatenate(key_parts), np.concatenate(weight_parts)
        )
        destination_nodes = (keys // np.uint64(node_count)).astype(np.uint32)
        source_nodes = (keys % np.uint64(node_count)).astype(np.uint32)
    else:
        source_nodes = np.concatenate(source_node_parts)
        destination_nodes = np.concatenate(destination_node_parts)
        raw_weights = np.concatenate(weight_parts)
        keys = destination_nodes.astype(np.uint64) * np.uint64(node_count) + source_nodes
        keys, raw_weights = _reduce_keyed_weights(keys, raw_weights)
        destination_nodes = (keys // np.uint64(node_count)).astype(np.uint32)
        source_nodes = (keys % np.uint64(node_count)).astype(np.uint32)

    degree = np.bincount(
        source_nodes, weights=raw_weights, minlength=node_count
    ) + np.bincount(destination_nodes, weights=raw_weights, minlength=node_count)
    # Pruning is opt-in and explicitly recorded; full neuron mode retains
    # every annotated neuron, including zero-degree neurons after filtering.
    keep = np.ones(node_count, dtype=bool)  # Preserve annotated isolated nodes, too.
    if minimum_total_synapses > 0.0:
        keep &= degree >= minimum_total_synapses
    if maximum_nodes > 0 and int(np.count_nonzero(keep)) > maximum_nodes:
        candidates = np.flatnonzero(keep)
        ranked = sorted(
            candidates.tolist(),
            key=lambda index: (-float(degree[index]), labels[index]),
        )[:maximum_nodes]
        keep[:] = False
        keep[np.asarray(ranked, dtype=np.int64)] = True
    if not np.all(keep):
        retained = np.flatnonzero(keep)
        if retained.size == 0:
            raise ConnectomeError("node pruning removed the complete graph")
        remap = np.full(node_count, INVALID_INDEX, dtype=np.uint32)
        remap[retained] = np.arange(retained.size, dtype=np.uint32)
        edge_keep = keep[source_nodes] & keep[destination_nodes]
        source_nodes = remap[source_nodes[edge_keep]]
        destination_nodes = remap[destination_nodes[edge_keep]]
        raw_weights = raw_weights[edge_keep]
        node_ids = node_ids[retained]
        node_flags = node_flags[retained]
        node_sign = node_sign[retained]
        degree = degree[retained]
        labels = [labels[index] for index in retained]
        node_count = len(labels)

    order = np.lexsort((source_nodes, destination_nodes))
    source_nodes = source_nodes[order]
    destination_nodes = destination_nodes[order]
    raw_weights = raw_weights[order]
    strength = np.log1p(raw_weights) * node_sign[source_nodes]
    denominator = np.bincount(
        destination_nodes,
        weights=np.abs(strength),
        minlength=node_count,
    )
    normalized_weights = (
        recurrent_scale
        * strength
        / np.maximum(denominator[destination_nodes], 1.0e-12)
    ).astype(np.float32)
    if source_nodes.size >= INVALID_INDEX:
        raise ConnectomeError("compiled edge count exceeds the 32-bit Metal ABI")
    edge_counts = np.bincount(destination_nodes, minlength=node_count)
    cumulative = np.cumsum(edge_counts, dtype=np.uint64)
    if cumulative.size and int(cumulative[-1]) >= INVALID_INDEX:
        raise ConnectomeError("compiled CSR offsets exceed the 32-bit Metal ABI")
    incoming_offsets = np.zeros(node_count + 1, dtype=np.uint32)
    incoming_offsets[1:] = cumulative.astype(np.uint32, copy=False)

    nodes = np.zeros(node_count, dtype=NODE_DTYPE)
    nodes["dynamics"][:, 0] = np.float32(update_alpha)
    nodes["dynamics"][:, 1] = 0.0
    nodes["dynamics"][:, 2] = 1.0
    nodes["dynamics"][:, 3] = 1.0
    nodes["modulation"][:, 0] = 1.0
    nodes["modulation"][:, 1] = np.float32(state_clip)
    nodes["modulation"][:, 2] = 0.0
    nodes["modulation"][:, 3] = 0.0
    nodes["identity"][:, 0] = (node_ids & np.uint64(0xFFFFFFFF)).astype(np.uint32)
    nodes["identity"][:, 1] = (node_ids >> np.uint64(32)).astype(np.uint32)
    nodes["identity"][:, 2] = node_flags
    nodes["identity"][:, 3] = np.asarray(
        [_stable_hash32(label) for label in labels], dtype=np.uint32
    )

    source_fingerprint = _source_fingerprint(sources)
    official_source = all(OFFICIAL_SHA256.get(name) == digest for name, digest in source_hashes.items())
    manifest = {
        "format": "numilab-connectome-graph",
        "format_version": GRAPH_ABI,
        "source": {
            "dataset": OFFICIAL_VERSION if official_source else "unverified:user-tables",
            "license": "CC-BY-4.0" if official_source else "unverified",
            "annotations": sources.annotations.name,
            "neurotransmitters": (
                sources.neurotransmitters.name
                if sources.neurotransmitters is not None
                else None
            ),
            "weights": sources.weights.name,
            "sha256": source_hashes,
            "url": "https://male-cns.janelia.org/download/" if official_source else None,
            "scope": "explicitly classified neuronal entries; glia, artifacts, unimportant and unclassified annotation records excluded and counted",
        },
        "compilation": {
            "resolution": "cell-type" if resolution_code else "neuron",
            "minimum_synapses_per_neuron_pair": minimum_synapses,
            "recurrent_scale": recurrent_scale,
            "update_alpha": update_alpha,
            "state_clip": state_clip,
            "sign_mode": sign_mode,
            "maximum_nodes": maximum_nodes,
            "minimum_total_synapses": minimum_total_synapses,
            "normalization": "destination-l1(log1p(synapse_count))",
            "deterministic": True,
        },
        "counts": {
            "nodes": node_count,
            "edges": int(source_nodes.size),
            "annotation_records": annotation_count,
            "excluded_annotation_records": excluded_annotations,
            "classified_neuronal_entries": int(selected_indices.size),
            "source_weight_rows": source_edge_count,
            "thresholded_source_rows": thresholded_edges,
            "unmapped_endpoint_rows": excluded_endpoint_edges,
            "isolated_retained_nodes": int(np.count_nonzero(np.bincount(source_nodes, minlength=node_count) + np.bincount(destination_nodes, minlength=node_count) == 0)),
        },
        "scientific_contract": {
            "connectivity_grounded": True,
            "cell_dynamics_inferred": True,
            "neurotransmitter_signs_heuristic": sign_mode == "heuristic",
            "runtime_dynamics": "deterministic population-rate surrogate",
            "connectome_parameters_frozen_during_rollout": True,
            "robot_decoder_trainable": True,
        },
    }
    pack = GraphPack(
        resolution=resolution_code,
        source_fingerprint=source_fingerprint,
        fingerprint=0,
        node_ids=_u64_array(node_ids),
        nodes=nodes,
        incoming_offsets=_u32_array(incoming_offsets),
        incoming_sources=_u32_array(source_nodes),
        incoming_weights=_f32_array(normalized_weights),
        labels=labels,
        manifest_json=_canonical_json(manifest),
    )
    _validate_graph(pack)
    for name, path in [("annotations", sources.annotations), ("weights", sources.weights), ("neurotransmitters", sources.neurotransmitters)]:
        if path is not None and _sha256(path) != source_hashes[name]:
            raise ConnectomeError("source file changed during compilation")
    pack.fingerprint = graph_fingerprint(pack)
    return pack


def synthetic_graph() -> GraphPack:
    labels = ["sensory-left", "sensory-right", "integrator", "descending"]
    node_ids = _u64_array([_stable_hash64(label) for label in labels])
    nodes = np.zeros(4, dtype=NODE_DTYPE)
    nodes["dynamics"][:] = np.asarray([0.25, 0.0, 1.0, 1.0], dtype=np.float32)
    nodes["modulation"][:] = np.asarray([1.0, 8.0, 0.0, 0.0], dtype=np.float32)
    nodes["identity"][:, 0] = (node_ids & np.uint64(0xFFFFFFFF)).astype(np.uint32)
    nodes["identity"][:, 1] = (node_ids >> np.uint64(32)).astype(np.uint32)
    nodes["identity"][:, 2] = np.asarray(
        [NODE_SENSORY, NODE_SENSORY, NODE_INTRINSIC, NODE_DESCENDING],
        dtype=np.uint32,
    )
    nodes["identity"][:, 3] = np.asarray(
        [_stable_hash32(label) for label in labels], dtype=np.uint32
    )
    pack = GraphPack(
        resolution=GRAPH_RESOLUTION_CELL_TYPE,
        source_fingerprint=_stable_hash64("synthetic-connectome-v1"),
        fingerprint=0,
        node_ids=node_ids,
        nodes=nodes,
        incoming_offsets=_u32_array([0, 0, 0, 2, 3]),
        incoming_sources=_u32_array([0, 1, 2]),
        incoming_weights=_f32_array([0.75, -0.75, 1.0]),
        labels=labels,
        manifest_json=_canonical_json(
            {
                "format": "numilab-connectome-graph",
                "synthetic": True,
                "counts": {"nodes": 4, "edges": 3},
            }
        ),
    )
    pack.fingerprint = graph_fingerprint(pack)
    return pack

# Cold-path native validation and hashing; this is never a simulation backend.
_NATIVE = None
_NATIVE_DIRECTORY = None

def _native():
    global _NATIVE, _NATIVE_DIRECTORY
    if _NATIVE is not None:
        return _NATIVE
    import ctypes
    import subprocess
    _NATIVE_DIRECTORY = tempfile.TemporaryDirectory(prefix="numi-connectome-abi-")
    suffix = ".dylib" if sys.platform == "darwin" else ".so"
    library = Path(_NATIVE_DIRECTORY.name) / ("connectome" + suffix)
    source = Path(__file__).resolve().parents[1] / "Sources/NumiBrainConnectomeABI"
    subprocess.run([os.environ.get("CXX", "clang++"), "-std=c++20", "-O2", "-shared", "-fPIC",
        "-I", str(source / "include"), str(source / "NumiBrainConnectomeABI.cpp"), "-o", str(library)], check=True)
    lib = ctypes.CDLL(str(library))
    lib.nb_connectome_hash_update.argtypes = [ctypes.c_uint64, ctypes.c_void_p, ctypes.c_size_t]
    lib.nb_connectome_hash_update.restype = ctypes.c_uint64
    lib.nb_connectome_validate.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_uint64, ctypes.c_void_p]
    lib.nb_connectome_validate.restype = ctypes.c_uint32
    lib.nb_connectome_status_message.argtypes = [ctypes.c_uint32]
    lib.nb_connectome_status_message.restype = ctypes.c_char_p
    _NATIVE = lib
    return lib


def verify_native(path: Path, maximum_bytes: int = 1 << 30) -> None:
    import ctypes
    if path.stat().st_size > maximum_bytes:
        raise ConnectomeError("graph exceeds native loading budget")
    data = np.memmap(path, mode="r", dtype=np.uint8)
    view = ctypes.create_string_buffer(104)  # 11 uint64 + 4 uint32
    code = _native().nb_connectome_validate(data.ctypes.data, data.size, maximum_bytes, view)
    if code:
        raise ConnectomeError(_native().nb_connectome_status_message(code).decode())


def _atomic_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary_name = tempfile.mkstemp(prefix="." + path.name, dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n")
            stream.flush(); os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def download_official_dataset(output_dir: Path, refresh: bool = False) -> SourcePaths:
    """Pinned release URLs, bounded downloads, exact cache integrity, no login.

    The recorded SHA-256 is computed locally, not a publisher-signed checksum.
    Subsequent reuse must match it. Refresh is explicit and never trusts stale
    cached bytes. Existing complete manifests survive a partially failed fetch.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = output_dir / "source-manifest.json"
    old = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    if old and (old.get("dataset") != OFFICIAL_VERSION or old.get("base") != OFFICIAL_BASE):
        raise ConnectomeError("cache manifest belongs to another source")
    records = {}
    for name, filename in OFFICIAL_FILES.items():
        path = output_dir / filename
        url = f"{OFFICIAL_BASE}/{filename}"
        previous = old.get("files", {}).get(name)
        if path.exists() and not refresh:
            if not previous or previous.get("url") != url or previous.get("bytes") != path.stat().st_size or previous.get("sha256") != _sha256(path):
                raise ConnectomeError(f"unverified or changed cache file {filename}; use --refresh to reacquire")
            verify_official_digest(name, previous["sha256"])
            records[name] = previous
            continue
        fd, tempname = tempfile.mkstemp(prefix="." + filename, dir=output_dir)
        temp = Path(tempname)
        try:
            digest = hashlib.sha256(); total = 0
            request = urllib.request.Request(url, headers={"User-Agent": "NumiBrain-Connectome/1"})
            with os.fdopen(fd, "wb") as stream, urllib.request.urlopen(request, timeout=120) as response:
                expected = response.headers.get("Content-Length")
                while block := response.read(8 << 20):
                    total += len(block)
                    if total > 2 << 30:
                        raise ConnectomeError("release object exceeds the 2 GiB per-file download budget")
                    digest.update(block); stream.write(block)
                stream.flush(); os.fsync(stream.fileno())
                metadata = {"etag": response.headers.get("ETag"), "generation": response.headers.get("x-goog-generation")}
            if total == 0 or (expected is not None and total != int(expected)):
                raise ConnectomeError("truncated release object")
            verify_official_digest(name, digest.hexdigest())
            os.replace(temp, path)
            records[name] = {"name": filename, "url": url, "bytes": total, "sha256": digest.hexdigest(), **metadata}
            # Pin successful objects individually, so an interrupted acquisition
            # is safely resumable without redownloading verified complete files.
            _atomic_json(manifest_path, {"dataset": OFFICIAL_VERSION, "base": OFFICIAL_BASE,
                "license": "CC-BY-4.0", "files": {**old.get("files", {}), **records}})
        finally:
            temp.unlink(missing_ok=True)
    _atomic_json(manifest_path, {"dataset": OFFICIAL_VERSION, "base": OFFICIAL_BASE,
        "license": "CC-BY-4.0", "files": records})
    return SourcePaths(output_dir / OFFICIAL_FILES["annotations"],
        output_dir / OFFICIAL_FILES["neurotransmitters"], output_dir / OFFICIAL_FILES["weights"])


def source_paths(source_dir: Path) -> SourcePaths:
    manifest = json.loads((source_dir / "source-manifest.json").read_text())
    if manifest.get("dataset") != OFFICIAL_VERSION or manifest.get("base") != OFFICIAL_BASE:
        raise ConnectomeError("source manifest does not identify the pinned release")
    for name, filename in OFFICIAL_FILES.items():
        row = manifest["files"][name]; path = source_dir / filename
        verify_official_digest(name, row["sha256"])
        if row.get("url") != f"{OFFICIAL_BASE}/{filename}" or path.stat().st_size != row["bytes"] or _sha256(path) != row["sha256"]:
            raise ConnectomeError(f"source integrity mismatch: {filename}")
    return SourcePaths(source_dir / OFFICIAL_FILES["annotations"],
        source_dir / OFFICIAL_FILES["neurotransmitters"], source_dir / OFFICIAL_FILES["weights"])


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Pinned male-CNS acquisition and native NUMICNS1 compilation; no Python simulation.")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("download", "bootstrap"):
        p = sub.add_parser(name); p.add_argument("--source-dir", type=Path, required=True); p.add_argument("--refresh", action="store_true")
    p = sub.add_parser("compile"); p.add_argument("--source-dir", type=Path, required=True)
    for name in ("compile", "bootstrap"):
        p = sub.choices[name]; p.add_argument("--output", type=Path, required=True)
        p.add_argument("--resolution", choices=("neuron", "type"), default="neuron")
        p.add_argument("--minimum-synapses", type=int, default=1)
        p.add_argument("--sign-mode", choices=("unsigned", "heuristic"), required=True,
            help="Explicit modeling assumption: neither option is complete receptor physiology")
        p.add_argument("--alpha", type=float, default=0.2); p.add_argument("--recurrent-scale", type=float, default=1.5)
    p = sub.add_parser("inspect"); p.add_argument("graph", type=Path)
    p = sub.add_parser("synthetic"); p.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command in ("download", "bootstrap"):
            download_official_dataset(args.source_dir, args.refresh)
        if args.command in ("compile", "bootstrap"):
            graph = compile_official_graph(source_paths(args.source_dir), resolution=args.resolution,
                minimum_synapses=args.minimum_synapses, sign_mode=args.sign_mode,
                update_alpha=args.alpha, recurrent_scale=args.recurrent_scale)
            write_graph_pack(args.output, graph); verify_native(args.output)
            _atomic_json(args.output.with_suffix(args.output.suffix + ".sha256.json"),
                {"sha256": _sha256(args.output), "bytes": args.output.stat().st_size,
                 "graphFingerprint": f"{graph.fingerprint:016x}", "manifest": json.loads(graph.manifest_json)})
        if args.command == "synthetic":
            write_graph_pack(args.output, synthetic_graph()); verify_native(args.output)
        if args.command == "inspect":
            verify_native(args.graph); graph = read_graph_pack(args.graph)
            print(_canonical_json({"nodes": graph.node_count, "edges": graph.edge_count,
                "fingerprint": f"{graph.fingerprint:016x}", "sha256": _sha256(args.graph), "manifest": json.loads(graph.manifest_json)}))
        return 0
    except (OSError, ValueError, KeyError, ConnectomeError) as error:
        print(f"connectome: {error}", file=sys.stderr); return 1

if __name__ == "__main__":
    raise SystemExit(main())
