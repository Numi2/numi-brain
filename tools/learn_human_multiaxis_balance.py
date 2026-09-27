#!/usr/bin/env python3
"""Propose bounded two-axis Brain routes from committed Human interventions.

The output is a training proposal. Only later native, held-out runs can show
whether the learned routes actually recover balance.
"""

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path


SETTINGS = (
    ("axes-045-090", 0.045, 0.090, 0.0, 0.0),
    ("axes-045-150", 0.045, 0.150, 0.0, 0.0),
    ("axes-045-090-hip-pos", 0.045, 0.090, 0.030, 20.0),
    ("axes-060-150-hip-pos", 0.060, 0.150, 0.060, 20.0),
)

VELOCITY_SETTINGS = (
    ("velocity-045-045", 0.045, 0.045, 0.0, 0.0),
    ("velocity-045-045-hip-pos", 0.045, 0.045, 0.030, 20.0),
    ("velocity-060-090-hip-pos", 0.060, 0.090, 0.060, 20.0),
    ("velocity-060-090-hip", 0.060, 0.090, 0.030, 0.0),
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    return json.loads(path.read_text())


def journal(directory, steps, program_digest):
    receipt_path = directory / "receipt.json"
    transitions_path = directory / "transitions.jsonl"
    receipt = read_json(receipt_path)
    if (receipt.get("schema") != "numi.human.brain.committed-transitions.v1"
            or receipt.get("steps") != steps
            or receipt.get("motorAuditInterval") != 10
            or receipt.get("transitionCount") != steps // 10
            or receipt.get("transitionsSHA256") != digest(transitions_path)
            or not any(item["kind"] == "locomotor_program"
                       and item["sha256"] == program_digest
                       for item in receipt["sourceSHA256"])):
        raise ValueError(f"unbound committed Human journal: {directory}")
    rows = {row["step"]: row for row in
            map(json.loads, transitions_path.open())}
    if list(rows) != list(range(10, steps + 1, 10)):
        raise ValueError(f"journal has missing or unordered committed steps: {directory}")
    return rows, digest(receipt_path)


def horizontal_velocity(rows, step):
    row = rows[step]
    observation = row["consequence"]
    if (observation["rootLinearVelocityValidity"] != 896
            or row["physicalConsequence"]["contactCount"] < 6):
        raise ValueError(f"training velocity lacks physical validity at {step}")
    velocity = observation["rootLinearVelocityXYZMPerS"]
    if len(velocity) != 3 or not all(math.isfinite(x) for x in velocity):
        raise ValueError("training velocity is nonfinite")
    return velocity[:2]


def outcome_cost(result):
    recovery = result["recoveryTask"]
    first_loss = recovery["firstContactLossStep"] or 2001
    return (recovery["peakFinalCOMDriftM"]
            + 0.1 * recovery["peakFinalCOMSpeedMPerS"]
            + 0.1 * (2001 - first_loss) / 2000)


def propose(args):
    if args.output.exists():
        raise ValueError("refusing to replace a policy proposal")
    baseline = read_json(args.baseline)
    template = read_json(args.template)
    grid = read_json(args.causal_grid)
    positive = read_json(args.positive_analysis)
    manifest = read_json(args.direction_manifest)
    summary = read_json(args.direction_summary)
    if (baseline.get("version") != 4
            or template.get("version") != 6
            or len(baseline.get("channels", [])) != 416
            or template["channels"] != baseline["channels"]
            or template["jointPathFeedback"] != baseline["jointPathFeedback"]
            or grid.get("schema") != "numi.human.brain.causal-synergy-grid.v1"
            or grid["baseProgramSHA256"] != digest(args.baseline)
            or positive.get("schema") != "numi.human.brain.causal-synergy-analysis.v1"
            or positive.get("preEventPhysicalProgressEqual") is not True
            or manifest.get("workers") != 16
            or manifest.get("stepsPerWorker") != 2000
            or not manifest.get("sameSeedBenchmark")
            or manifest["push"]["startStep"] != 1000
            or manifest["push"]["durationSteps"] != 20
            or summary.get("status") != "ACCEPTED_NATIVE_COHORT"
            or len(summary["results"]) != 16
            or manifest["push"]["xForceNewtons"] != [-50.0] * 8 + [0.0] * 8
            or manifest["push"]["yForceNewtons"] != [0.0] * 8 + [50.0] * 8):
        raise ValueError("causal sources or matched native cohort disagree")

    grid_candidates = {Path(row["path"]).name: row for row in grid["candidates"]}
    if (len(grid_candidates) != 8
            or any(row["programSHA256"] != grid_candidates[row["program"]]["sha256"]
                   for row in positive["rows"])):
        raise ValueError("positive causal response lost its motor program binding")
    direction_rows = {}
    receipts = []
    for index, (program, result) in enumerate(zip(
            manifest["workerPrograms"], summary["results"])):
        name = Path(program["path"]).name
        if (not result["accepted"] or not result["unassisted"]
                or result["acceptedPhysicalSteps"] != 2000
                or grid_candidates[name]["sha256"] != program["sha256"]
                or digest(args.causal_grid.parent / name) != program["sha256"]):
            raise ValueError(f"directional intervention lacks physical authority: {index}")
        rows, receipt_digest = journal(
            args.direction_journals / f"worker-{index:02d}",
            2000, program["sha256"])
        worker_receipt = read_json(
            args.direction_journals / f"worker-{index:02d}" / "receipt.json")
        if not any(item["kind"] == "brain_library"
                   and item["sha256"] == manifest["artifactSHA256"]["brainDylib"]
                   for item in worker_receipt["sourceSHA256"]):
            raise ValueError(f"directional Brain library differs at worker {index}")
        direction_rows[("negative_x" if index < 8 else "positive_y", name)] = (
            rows, result)
        receipts.append(receipt_digest)

    positive_rows, positive_receipt = journal(
        args.positive_journal, 3000, digest(args.baseline))
    if (read_json(args.positive_journal / "receipt.json")["launchLogSHA256"]
            != positive["baselineLogSHA256"]):
        raise ValueError("positive causal analysis does not use the committed baseline")
    vx_positive, vy_positive = horizontal_velocity(positive_rows, 1010)
    negative_rows = direction_rows[("negative_x", "program-hip_y-sign-1.json")][0]
    sideways_rows = direction_rows[("positive_y", "program-hip_y-sign-1.json")][0]
    vx_negative, vy_negative = horizontal_velocity(negative_rows, 1010)
    vx_sideways, vy_sideways = horizontal_velocity(sideways_rows, 1010)
    if not (vx_positive > 0.02 and vx_negative < -0.02
            and abs(vx_sideways) < 0.01
            and vy_positive > 0 and vy_negative > 0
            and vy_sideways > 0.5):
        raise ValueError("committed receptors do not separate the training pushes")
    x_threshold = round(0.5 * min(vx_positive, -vx_negative), 4)
    y_threshold = round(0.5 * (
        max(abs(vy_positive), abs(vy_negative)) + vy_sideways), 4)
    if not (0.001 <= x_threshold <= 1 and 0.001 <= y_threshold <= 1):
        raise ValueError("derived event thresholds exceed Brain admission")

    positive_effect = {row["program"]: row["comYDriftDeltaMM"]["1500"]
                       for row in positive["rows"]}
    lower = "ankle_y_lower"
    minus = f"program-{lower}-sign-1.json"
    plus = f"program-{lower}-sign+1.json"
    if not (positive_effect[minus] < -5
            and positive_effect[plus] > 10
            and outcome_cost(direction_rows[("negative_x", plus)][1])
                < outcome_cost(direction_rows[("negative_x", minus)][1])
            and outcome_cost(direction_rows[("positive_y", minus)][1])
                < outcome_cost(direction_rows[("positive_y", plus)][1])):
        raise ValueError("ankle action lacks observed direction reversal")
    hip_negative = direction_rows[("negative_x", "program-hip_y-sign-1.json")][1]
    if (hip_negative["recoveryTask"]["firstContactLossStep"] is not None
            or outcome_cost(hip_negative) >= outcome_cost(
                direction_rows[("negative_x", "program-hip_y-sign+1.json")][1])):
        raise ValueError("hip response is not a supported corrective intervention")

    lower_routes = read_json(args.causal_grid.parent / minus)["balanceFeedback"]["routes"]
    hip_routes = read_json(args.causal_grid.parent /
                           "program-hip_y-sign+1.json")["balanceFeedback"]["routes"]
    sources = template["balanceFeedback"]["sources"]
    x_velocity = next(source for source in sources
                      if source["bodyReceptorBindingIdentifier"] == 2)
    y_position = next(source for source in sources
                      if source["bodyReceptorBindingIdentifier"] == 5)
    y_velocity = next(source for source in sources
                      if source["bodyReceptorBindingIdentifier"] == 6)
    if (len({source["identifier"] for source in (x_velocity, y_position, y_velocity)}) != 3
            or x_velocity["referenceValue"] != 0
            or y_velocity["referenceValue"] != 0):
        raise ValueError("physical velocity or position source identity changed")
    x_event = copy.deepcopy(x_velocity)
    x_event["eventThreshold"] = x_threshold
    x_event["eventConsecutiveSamples"] = 3
    y_event = copy.deepcopy(y_velocity)
    y_event["eventThreshold"] = y_threshold
    y_event["eventConsecutiveSamples"] = 3
    y_continuous = copy.deepcopy(y_velocity)
    y_continuous.pop("eventThreshold", None)
    y_continuous.pop("eventConsecutiveSamples", None)
    _, vy_positive_1050 = horizontal_velocity(positive_rows, 1050)
    _, vy_negative_1050 = horizontal_velocity(negative_rows, 1050)
    x_velocity_reference = 0.5 * (vx_positive - vx_negative)
    y_velocity_reference = 0.5 * (vy_positive_1050 + vy_negative_1050)
    if not (0.02 < x_velocity_reference < 0.2
            and 0.02 < y_velocity_reference < 0.2):
        raise ValueError("committed velocity scale is unsuitable for a bounded route")

    args.output.mkdir(parents=True)
    candidates = []
    for name, x_amplitude, y_amplitude, hip_amplitude, position_scale in SETTINGS:
        program = copy.deepcopy(baseline)
        program["version"] = 6
        feedback = copy.deepcopy(template["balanceFeedback"])
        feedback["mode"] = 1
        feedback["sources"] = ([x_event, y_position, y_event]
                               if position_scale else [x_event, y_event])
        feedback["routes"] = []
        ankle_cap = 0.15 if position_scale else 0.25
        ankle_sources = [
            (x_event["identifier"], x_amplitude / 0.06),
            (y_event["identifier"], y_amplitude / 0.06),
        ]
        if position_scale:
            ankle_sources.append((y_position["identifier"], position_scale))
        for route in lower_routes:
            for source_id, multiplier in ankle_sources:
                feedback["routes"].append({
                    "sourceIdentifier": source_id,
                    "muscleIdentifier": route["muscleIdentifier"],
                    "gain": round(route["gain"] * multiplier, 8),
                    "maximumCorrection": ankle_cap,
                })
        if hip_amplitude:
            for route in hip_routes:
                feedback["routes"].append({
                    "sourceIdentifier": x_event["identifier"],
                    "muscleIdentifier": route["muscleIdentifier"],
                    "gain": round(route["gain"] * hip_amplitude / 0.06, 8),
                    "maximumCorrection": 0.25,
                })
        if any(route["gain"] == 0 or abs(route["gain"]) > 10
               for route in feedback["routes"]):
            raise ValueError("proposed route exceeds Brain gain contract")
        program["balanceFeedback"] = feedback
        path = args.output / f"program-{name}.json"
        path.write_text(json.dumps(program, indent=2, sort_keys=True) + "\n")
        candidates.append({"name": name, "path": str(path),
                           "sha256": digest(path), "routeCount": len(feedback["routes"]),
                           "xAmplitude": x_amplitude, "yAmplitude": y_amplitude,
                           "hipAmplitude": hip_amplitude,
                           "positionScale": position_scale})
    for name, x_amplitude, y_amplitude, hip_amplitude, position_scale in VELOCITY_SETTINGS:
        program = copy.deepcopy(baseline)
        program["version"] = 6
        feedback = copy.deepcopy(template["balanceFeedback"])
        feedback["mode"] = 1
        feedback["sources"] = ([x_velocity, y_position, y_continuous]
                               if position_scale else [x_velocity, y_continuous])
        feedback["routes"] = []
        lower_sources = [
            (x_velocity["identifier"], x_amplitude / (0.06 * x_velocity_reference),
             0.15 if position_scale else 0.20),
            (y_continuous["identifier"], y_amplitude / (0.06 * y_velocity_reference),
             0.25),
        ]
        if position_scale:
            lower_sources.append((y_position["identifier"], position_scale, 0.10))
        for route in lower_routes:
            for source_id, multiplier, cap in lower_sources:
                feedback["routes"].append({
                    "sourceIdentifier": source_id,
                    "muscleIdentifier": route["muscleIdentifier"],
                    "gain": round(route["gain"] * multiplier, 8),
                    "maximumCorrection": cap,
                })
        if hip_amplitude:
            for route in hip_routes:
                feedback["routes"].append({
                    "sourceIdentifier": x_velocity["identifier"],
                    "muscleIdentifier": route["muscleIdentifier"],
                    "gain": round(route["gain"] * hip_amplitude
                                  / (0.06 * -vx_negative), 8),
                    "maximumCorrection": 0.25,
                })
        if any(route["gain"] == 0 or abs(route["gain"]) > 10
               for route in feedback["routes"]):
            raise ValueError("continuous route exceeds Brain gain contract")
        program["balanceFeedback"] = feedback
        path = args.output / f"program-{name}.json"
        path.write_text(json.dumps(program, indent=2, sort_keys=True) + "\n")
        candidates.append({"name": name, "path": str(path),
                           "sha256": digest(path), "routeCount": len(feedback["routes"]),
                           "xAmplitudeAtReferenceVelocity": x_amplitude,
                           "yAmplitudeAtReferenceVelocity": y_amplitude,
                           "hipAmplitudeAtNegativeXVelocity": hip_amplitude,
                           "positionScale": position_scale})
    receipt = {
        "schema": "numi.human.brain.multiaxis-policy-proposal.v1",
        "qualification": "unqualified data-derived proposals; no recovery or learned-skill claim",
        "method": "source-bound paired muscle interventions and early committed velocity separation",
        "sourceSHA256": {
            "baselineProgram": digest(args.baseline),
            "templateProgram": digest(args.template),
            "causalGrid": digest(args.causal_grid),
            "positiveAnalysis": digest(args.positive_analysis),
            "positiveJournalReceipt": positive_receipt,
            "directionManifest": digest(args.direction_manifest),
            "directionSummary": digest(args.direction_summary),
            "directionJournalReceipts": receipts,
        },
        "velocityAt1010MPerS": {
            "positiveX": [vx_positive, vy_positive],
            "negativeX": [vx_negative, vy_negative],
            "positiveY": [vx_sideways, vy_sideways],
        },
        "derivedEventThresholdMPerS": {"x": x_threshold, "y": y_threshold},
        "derivedVelocityReferenceMPerS": {
            "x": x_velocity_reference, "y": y_velocity_reference,
        },
        "selectedAnkleResponses": {
            "positiveX": minus, "negativeX": plus, "positiveY": minus,
        },
        "candidates": candidates,
    }
    (args.output / "learning-receipt.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("baseline", "template", "causal-grid", "positive-analysis",
                 "positive-journal", "direction-manifest", "direction-summary",
                 "direction-journals", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    result = propose(args)
    print(json.dumps({"candidateCount": len(result["candidates"]),
                      "thresholds": result["derivedEventThresholdMPerS"],
                      "output": str(args.output)}, sort_keys=True))


if __name__ == "__main__":
    main()
