#!/usr/bin/env python3
"""Fail CI if generated executable-model files or deployed ABI literals drift."""
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "Contracts/NumiBrainExecutableModelV1.json"
SWIFT = ROOT / "Sources/NumiBrainCore/Generated/BrainExecutableModelContract.generated.swift"
METAL = ROOT / "Sources/NumiBrainMetal/Shaders/GeneratedExecutableModelContract.metalh"

def die(message):
    print(message, file=sys.stderr)
    raise SystemExit(1)

def metal_uint_expression(name, source):
    match = re.search(rf"constant uint {re.escape(name)}\s*=\s*([^;]+);", source)
    if not match:
        die(f"Metal shader is missing {name}")
    expression = re.sub(r"\s+", "", match.group(1))
    literal = re.fullmatch(r"(\d+)u", expression)
    if literal:
        return int(literal.group(1))
    shift = re.fullmatch(r"(\d+)u<<(\d+)", expression)
    if shift:
        return int(shift.group(1)) << int(shift.group(2))
    die(f"Metal shader {name} uses an unsupported constant expression: {match.group(1)}")

def main():
    with tempfile.TemporaryDirectory() as td:
        generated_swift = Path(td) / "Contract.swift"
        generated_metal = Path(td) / "Contract.metalh"
        subprocess.run([sys.executable, str(ROOT / "scripts/generate-executable-model-contract.py"),
                        "--contract", str(CONTRACT), "--swift", str(generated_swift),
                        "--metal", str(generated_metal)], check=True)
        if generated_swift.read_bytes() != SWIFT.read_bytes():
            die("generated Swift executable-model contract is stale")
        if generated_metal.read_bytes() != METAL.read_bytes():
            die("generated Metal executable-model contract is stale")

    data = json.loads(CONTRACT.read_text())
    t = data["committedTransition"]
    arena = (ROOT / "Sources/NumiBrainMetal/MetalAgentStateArena.swift").read_text()
    expected_stride = f"{t['strideBytes']:,}".replace(",", "_?")
    if not re.search(rf"committedTransitionStride\s*=\s*{expected_stride}\b", arena):
        die("MetalAgentStateArena committed-transition stride drifted from contract")
    if not re.search(r"recordLayoutVersion\s*:\s*UInt32\s*=\s*18\b", arena):
        die("MetalAgentStateArena record-layout version must advance for affect metadata")
    batch = (ROOT / "Sources/NumiBrainMetal/MetalLearningBatch.swift").read_text()
    if not re.search(r"formatVersion\s*:\s*UInt32\s*=\s*13\b", batch):
        die("MetalLearningBatch format version must advance for affect metadata")
    if not re.search(rf"transitionRecordVersion\s*:\s*UInt32\s*=\s*{t['recordVersion']}\b", batch):
        die("MetalLearningBatch transition record version drifted from contract")
    shader = (ROOT / "Sources/NumiBrainMetal/Shaders/MemoryState.metal").read_text()
    expected = {
        "NB_COMMITTED_TRANSITION_RECORD_VERSION": t["recordVersion"],
        "NB_COMMITTED_TRANSITION_HAS_EMBODIED_TRACE": t["flags"]["hasEmbodiedTrace"],
        "NB_COMMITTED_TRANSITION_ACCEPTED_STOP": t["flags"]["acceptedStop"],
    }
    for name, value in expected.items():
        if metal_uint_expression(name, shader) != value:
            die(f"Metal shader {name} drifted from contract")
    arrays = {
        "prior_state": 24, "posterior_state": 24, "observation": 24,
        "action": 16, "factored_reinforcement": 8, "teacher_state": 24,
        "fast_plasticity_trace": 16, "cerebellar_trace": 16,
        "active_sensing_trace": 4, "autonomic_action": 16,
        "active_sensing_action": 16, "internal_action": 32, "body_schema_trace": 16,
        "affect": 8,
    }
    for name, count in arrays.items():
        if not re.search(rf"float {name}\[{count}\];", shader):
            die(f"Metal committed-transition field {name} drifted from contract")
    scalars = {
        "affect_source_validity_mask": "uint",
        "affect_reserved": "uint",
        "affect_timestamp_microseconds": "ulong",
    }
    for name, kind in scalars.items():
        if not re.search(rf"{kind} {name};", shader):
            die(f"Metal committed-transition field {name} drifted from contract")
    mlx = (ROOT / "Sources/NumiBrainMLX/MLXEmbodiedPolicyHead.swift").read_text()
    if "BrainExecutableModelContract.PolicyHead" not in mlx:
        die("MLX embodied policy head is not consuming the generated contract")
    print("Executable model contract is canonical and deployed literals match.")

if __name__ == "__main__":
    main()
