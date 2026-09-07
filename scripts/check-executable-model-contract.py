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
    t, p = data["committedTransition"], data["policyHead"]
    arena = (ROOT / "Sources/NumiBrainMetal/MetalAgentStateArena.swift").read_text()
    if not re.search(r"committedTransitionStride\s*=\s*1_?104\b", arena):
        die("MetalAgentStateArena committed-transition stride drifted from contract")
    shader = (ROOT / "Sources/NumiBrainMetal/Shaders/MemoryState.metal").read_text()
    expected = {
        "NB_COMMITTED_TRANSITION_RECORD_VERSION": t["recordVersion"],
        "NB_COMMITTED_TRANSITION_HAS_EMBODIED_TRACE": t["flags"]["hasEmbodiedTrace"],
        "NB_COMMITTED_TRANSITION_ACCEPTED_STOP": t["flags"]["acceptedStop"],
    }
    for name, value in expected.items():
        if not re.search(rf"constant uint {name}\s*=\s*{value}u", shader):
            die(f"Metal shader {name} drifted from contract")
    arrays = {
        "prior_state": 24, "posterior_state": 24, "observation": 24,
        "action": 16, "factored_reinforcement": 8, "teacher_state": 24,
        "fast_plasticity_trace": 16, "cerebellar_trace": 16,
        "active_sensing_trace": 4, "autonomic_action": 16,
        "active_sensing_action": 16, "internal_action": 32, "body_schema_trace": 16,
    }
    for name, count in arrays.items():
        if not re.search(rf"float {name}\[{count}\];", shader):
            die(f"Metal committed-transition field {name} drifted from contract")
    mlx = (ROOT / "Sources/NumiBrainMLX/MLXEmbodiedPolicyHead.swift").read_text()
    if "BrainExecutableModelContract.PolicyHead" not in mlx:
        die("MLX embodied policy head is not consuming the generated contract")
    print("Executable model contract is canonical and deployed literals match.")

if __name__ == "__main__":
    main()
