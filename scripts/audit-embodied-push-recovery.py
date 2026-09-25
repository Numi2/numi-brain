#!/usr/bin/env python3
"""Audit a native, matched Brain/Human push pair from accepted-step logs."""

import argparse
import json
import math
import re
import shlex
from pathlib import Path


FIELDS = re.compile(
    r"human_standing_progress=accepted step=(\d+) .*?"
    r"root_xyz_m=\[([^]]+)\].*?"
    r"root_linear_velocity_xyz_m_s=\[([^]]+)\].*?"
    r"root_linear_speed_m_s=([^ ]+) .*?"
    r"penetration_m=([^ ]+) contact_count=(\d+) .*?"
    r"brain_muscle_excitation_max_abs_delta=([^ ]+) .*?"
    r"root_assistance_force_n=([^ ]+) root_assistance_torque_nm=([^ ]+)"
)
SENSOR = re.compile(
    r"human_brain_sensor_audit=accepted step=(\d+) .*?"
    r"receptor_timestamp_us=(\d+) delivery_timestamp_us=(\d+) .*?"
    r"root_linear_velocity_validity=(\d+) "
    r"root_linear_velocity_xyz_m_s=\[([^]]+)\]"
)
MATCHED_MANIFEST_PREFIXES = (
    "native_timestep_microseconds=", "brain_epoch_microseconds=", "seed=",
    "binary ", "brain_library ", "metal_library ", "rigid_source ",
    "muscle_source ", "support_contact_source ", "joint_equality_source ",
    "tendon_source ", "bodyparts3d_bone_source ",
    "bodyparts3d_muscle_surface_source ", "lab_source_revision=",
    "lab_source_file=",
)


def vector(raw):
    return tuple(float(value) for value in raw.split(","))


def read_run(directory, steps):
    log = directory / "launch.log"
    rows, sensors, errors = {}, {}, []
    completed = False
    terminal = False
    for line in log.open(errors="replace"):
        match = FIELDS.search(line)
        if match:
            step = int(match[1])
            if step in rows:
                errors.append(f"duplicate accepted step {step}")
            rows[step] = {
                "raw": line.strip(),
                "position": vector(match[2]),
                "velocity": vector(match[3]),
                "speed": float(match[4]),
                "penetration": float(match[5]),
                "contacts": int(match[6]),
                "muscle_delta": float(match[7]),
                "assistance_force": float(match[8]),
                "assistance_torque": float(match[9]),
            }
        match = SENSOR.search(line)
        if match:
            step = int(match[1])
            if step in sensors:
                errors.append(f"duplicate accepted sensor step {step}")
            sensors[step] = {
                "receptor_us": int(match[2]),
                "delivery_us": int(match[3]),
                "validity": int(match[4]),
                "velocity": vector(match[5]),
            }
        if f"human_execution_stage=native_horizon_end " in line and f"stage_step={steps}" in line:
            completed = True
        if line.startswith("stand_terminal_state="):
            terminal = True
        if ("myosim_articulated_visual=failed" in line
                or "human_brain_completion=failed" in line
                or "human_brain_joint_commit=rejected" in line):
            errors.append(line.strip()[:300])
    exit_file = directory / "launch.exit"
    if not exit_file.exists() or exit_file.read_text().splitlines() != [
        "binary_exit_code=0", "tee_exit_code=0", "launcher_exit_code=0"
    ]:
        errors.append("native launcher did not exit cleanly")
    if not completed or not terminal:
        errors.append("native horizon or terminal state is missing")
    if list(rows) != list(range(1, steps + 1)):
        errors.append(f"expected {steps} ordered accepted steps; found {len(rows)}")
    if list(sensors) != list(range(1, steps + 1)):
        errors.append(f"expected {steps} ordered accepted sensor packets; found {len(sensors)}")
    for step, sensor in sensors.items():
        if (sensor["receptor_us"] != step * 1_000
                or sensor["delivery_us"] != (step + 1) * 1_000):
            errors.append(f"sensor latency or accepted-root clock drift at step {step}")
            break
    for step, row in rows.items():
        if not all(math.isfinite(value) for value in
                   (*row["position"], *row["velocity"], row["speed"], row["penetration"])):
            errors.append(f"nonfinite physical state at step {step}")
            break
        if row["contacts"] < 6 or row["speed"] > 1.0 or row["penetration"] > 0.002:
            errors.append(f"standing envelope failed at step {step}")
            break
        if row["assistance_force"] != 0 or row["assistance_torque"] != 0:
            errors.append(f"root assistance at step {step}")
            break
    return rows, sensors, errors


def matched_manifest(directory):
    lines = (directory / "launch.manifest").read_text().splitlines()
    return sorted(line for line in lines if line.startswith(MATCHED_MANIFEST_PREFIXES))


def matched_command(directory):
    line = next(line for line in (directory / "launch.manifest").read_text().splitlines()
                if line.startswith("command="))
    argv = shlex.split(line.removeprefix("command="))
    argv[4] = "<output-directory>"
    if "--stand-brain-program" in argv:
        argv[argv.index("--stand-brain-program") + 1] = "<motor-program>"
    return argv


def locomotor_program_sha(directory):
    return next(line.split()[1] for line in
                (directory / "launch.manifest").read_text().splitlines()
                if line.startswith("locomotor_program "))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("off", type=Path)
    parser.add_argument("on", type=Path)
    parser.add_argument("--steps", type=int, default=500)
    parser.add_argument("--push-start", type=int, default=100)
    parser.add_argument("--threshold", type=float, default=0.01)
    parser.add_argument("--minimum-improvement", type=float, default=0.10)
    parser.add_argument("--no-push", action="store_true")
    parser.add_argument("--expect-identical", action="store_true")
    parser.add_argument("--replay-identical", action="store_true")
    args = parser.parse_args()
    off, off_sensors, off_errors = read_run(args.off, args.steps)
    on, sensors, on_errors = read_run(args.on, args.steps)
    errors = [f"off: {e}" for e in off_errors] + [f"on: {e}" for e in on_errors]
    if matched_manifest(args.off) != matched_manifest(args.on):
        errors.append("paired native binary, source, seed, or timestep differs")
    if matched_command(args.off) != matched_command(args.on):
        errors.append("paired native invocation differs beyond output and motor program")
    if args.replay_identical and locomotor_program_sha(args.off) != locomotor_program_sha(args.on):
        errors.append("replay motor program differs")
    result = {"schema": "numi.brain.embodied-push-pair-audit.v1",
              "off": str(args.off), "on": str(args.on), "errors": errors}
    if (args.no_push or args.expect_identical or args.replay_identical) and len(off) == args.steps and len(on) == args.steps:
        if off_sensors != sensors:
            errors.append("physical receptor traces diverged")
        first_difference = next((step for step in off if off[step] != on[step]), None)
        result["first_difference_step"] = first_difference
        if first_difference is not None:
            errors.append("expected identical arms diverged")
        if args.no_push:
            if any(sensor["validity"] & (1 << 7) and
                   abs(sensor["velocity"][0]) >= args.threshold
                   for sensor in sensors.values()):
                errors.append("no-push receptor exceeded the event threshold")
            origin = off[1]["position"]
            for name, rows in (("off", off), ("on", on)):
                maximum_horizontal = max(math.hypot(
                    row["position"][0] - origin[0],
                    row["position"][1] - origin[1]) for row in rows.values())
                maximum_vertical = max(abs(row["position"][2] - origin[2])
                                       for row in rows.values())
                maximum_speed = max(row["speed"] for row in rows.values())
                maximum_penetration = max(row["penetration"] for row in rows.values())
                result[name + "_standing_envelope"] = {
                    "maximum_horizontal_m": maximum_horizontal,
                    "maximum_vertical_m": maximum_vertical,
                    "maximum_speed_m_s": maximum_speed,
                    "maximum_penetration_m": maximum_penetration,
                }
                if (maximum_horizontal > 0.02 or maximum_vertical > 0.002
                        or maximum_speed > 0.02 or maximum_penetration > 5e-6):
                    errors.append(name + " 10-second standing envelope failed")
        elif args.expect_identical:
            qualifying = [step for step, sensor in sensors.items()
                if sensor["validity"] & (1 << 7)
                and sensor["velocity"][0] <= -args.threshold]
            first_three = next((step for step in qualifying if
                step - 1 in qualifying and step - 2 in qualifying), None)
            result["first_qualifying_three_sensor_step"] = first_three
            if first_three is None:
                errors.append("opposite push did not reach the physical event threshold")
    elif len(off) == args.steps and len(on) == args.steps:
        start, end = args.push_start, args.steps
        score = lambda rows: abs(rows[end]["position"][0] - rows[start]["position"][0]) + 0.2 * abs(rows[end]["velocity"][0])
        off_score, on_score = score(off), score(on)
        first_command = next((step for step in off if
            off[step]["muscle_delta"] != on[step]["muscle_delta"]), None)
        first_motion = next((step for step in off if
            off[step]["position"] != on[step]["position"] or
            off[step]["velocity"] != on[step]["velocity"]), None)
        qualifying = [step for step, sensor in sensors.items()
            if sensor["validity"] & (1 << 7) and
            abs(sensor["velocity"][0]) >= args.threshold]
        first_three = next((step for step in qualifying if
            step - 1 in qualifying and step - 2 in qualifying
            and sensors[step]["velocity"][0] * sensors[step - 1]["velocity"][0] > 0
            and sensors[step]["velocity"][0] * sensors[step - 2]["velocity"][0] > 0), None)
        result.update({"off_score_m": off_score, "on_score_m": on_score,
            "improvement_fraction": 1 - on_score / off_score if off_score else None,
            "first_qualifying_three_sensor_step": first_three,
            "first_command_difference_step": first_command,
            "first_motion_difference_step": first_motion,
            "off_peak_penetration_m": max(row["penetration"] for row in off.values()),
            "on_peak_penetration_m": max(row["penetration"] for row in on.values()),
            "off_min_contacts": min(row["contacts"] for row in off.values()),
            "on_min_contacts": min(row["contacts"] for row in on.values())})
        if off_score <= 0 or on_score > (1 - args.minimum_improvement) * off_score:
            errors.append("frozen recovery score improvement gate failed")
        if abs(on[end]["velocity"][0]) > abs(off[end]["velocity"][0]):
            errors.append("terminal x velocity worsened")
        if result["on_min_contacts"] < result["off_min_contacts"]:
            errors.append("minimum support contact count worsened")
        if result["on_peak_penetration_m"] > result["off_peak_penetration_m"]:
            errors.append("maximum penetration worsened")
        if first_three is None or first_command != first_three + 1 or not first_motion or first_motion <= first_command:
            errors.append("receptor to muscle to physical timing is not causal")
        if any(off[step] != on[step] for step in range(1, args.push_start + 1)):
            errors.append("matched arms diverged before the push")
    result["passed"] = not errors
    print(json.dumps(result, sort_keys=True, indent=2))
    raise SystemExit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
