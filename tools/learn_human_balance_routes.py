#!/usr/bin/env python3
"""Propose a bounded v6 receptor-route update from accepted native outcomes.

This is an off-rollout MLX search update. It cannot qualify its own proposal:
native training and held-out recovery still require fresh physical runs.
"""

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

import mlx.core as mx


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def candidate_loss(row, steps):
    outcome = row["recoveryTask"]
    loss_step = outcome["firstContactLossStep"] or steps + 1
    values = (row["maximumPenetrationM"], outcome["peakFinalCOMDriftM"],
              outcome["peakFinalCOMSpeedMPerS"], outcome["maximumRootDropM"])
    if not 1 <= loss_step <= steps + 1 or not all(
            isinstance(value, (int, float)) and math.isfinite(value) and value >= 0
            for value in values):
        raise ValueError("native recovery outcome is incomplete")
    return (4 * (steps + 1 - loss_step) / steps +
            outcome["peakFinalCOMDriftM"] +
            0.1 * outcome["peakFinalCOMSpeedMPerS"] +
            10 * outcome["maximumRootDropM"] +
            1000 * max(0, row["maximumPenetrationM"] - 5e-6))


def propose(audit_path, grid_path, base_path, output_directory):
    if output_directory.exists():
        raise ValueError("refusing to reuse learning output")
    audit = json.loads(audit_path.read_text())
    grid = json.loads(grid_path.read_text())
    base = json.loads(base_path.read_text())
    if (audit.get("schema") != "numi.human.brain.route-sweep-audit.v1" or
            audit.get("acceptedSweep") is not True or
            audit.get("recoveredCount") != 0 or
            len(audit["workers"]) != 16 or
            len(grid["candidates"]) != 16 or
            grid["sourceSHA256"] != sha256(base_path) or
            base.get("version") != 6 or
            len(base["balanceFeedback"]["routes"]) != 38):
        raise ValueError("learning input is not the exact accepted v6 route sweep")
    candidates = {item["sha256"]: item for item in grid["candidates"]}
    rows = []
    steps = audit["task"]["steps"]
    for worker in audit["workers"]:
        digest = worker["programSHA256"]
        if digest not in candidates or sha256(candidates[digest]["path"]) != digest:
            raise ValueError("candidate grid disagrees with accepted motor program")
        if not all(len(worker[key]) == 64 for key in ("physicalSHA256", "sensorSHA256")):
            raise ValueError("accepted physical or sensory digest is absent")
        item = candidates[digest]
        rows.append({"programSHA256": digest,
                     "positionScale": item["positionScale"],
                     "velocityScale": item["velocityScale"],
                     "loss": candidate_loss(worker, steps)})
    if len({row["programSHA256"] for row in rows}) != 16:
        raise ValueError("learning batch repeats a motor candidate")
    ranked = sorted(rows, key=lambda item: (item["loss"], item["programSHA256"]))
    elite = ranked[:4]
    losses = mx.array([item["loss"] for item in elite], dtype=mx.float32)
    coordinates = mx.array([[item["positionScale"], item["velocityScale"]]
                            for item in elite], dtype=mx.float32)
    weights = mx.softmax(-(losses - losses.min()) / mx.array(0.05, dtype=mx.float32))
    mean = (coordinates * weights.reshape((4, 1))).sum(axis=0)
    best = coordinates[0]
    proposal = (0.5 * best + 0.5 * mean).tolist()
    if (len(proposal) != 2 or not all(math.isfinite(value) for value in proposal)
            or not -0.4 <= proposal[0] <= 0.3
            or not -0.6 <= proposal[1] <= 0.3):
        raise ValueError("MLX proposal left the observed trust region")
    successor = copy.deepcopy(base)
    for route in successor["balanceFeedback"]["routes"]:
        source = route["sourceIdentifier"]
        if source not in (1, 2):
            raise ValueError("unfrozen balance route entered the update")
        route["gain"] = float(route["gain"] * proposal[source - 1])
        if route["gain"] == 0 or abs(route["gain"]) > 10:
            raise ValueError("updated route gain is invalid")
    output_directory.mkdir(parents=True)
    program_path = output_directory / "candidate.v6.json"
    program_path.write_text(json.dumps(successor, indent=2, sort_keys=True) + "\n")
    receipt = {"schema": "numi.human.brain.route-search-update.v1",
               "qualification": "unqualified proposal awaiting native and held-out evaluation",
               "method": "MLX weighted elite update in observed two-coordinate trust region",
               "acceptedSweepSHA256": sha256(audit_path),
               "gridSHA256": sha256(grid_path),
               "baseProgramSHA256": sha256(base_path),
               "candidateProgramSHA256": sha256(program_path),
               "positionScale": proposal[0], "velocityScale": proposal[1],
               "trainingTask": audit["task"], "rankedTrainingOutcomes": ranked}
    (output_directory / "learning-receipt.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit", type=Path, required=True)
    parser.add_argument("--grid", type=Path, required=True)
    parser.add_argument("--base-program", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = propose(args.audit, args.grid, args.base_program, args.output)
    print(json.dumps({key: result[key] for key in (
        "qualification", "candidateProgramSHA256", "positionScale",
        "velocityScale")}, sort_keys=True))


if __name__ == "__main__":
    main()
