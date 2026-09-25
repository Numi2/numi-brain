#!/bin/bash
set -euo pipefail

if (( $# != 6 )); then
  echo "usage: run-mini.sh NAME PROGRAM SEED STEPS PUSH_START PUSH_FORCE_X_N (0 start means no push)" >&2
  exit 2
fi
name=$1
program=$2
seed=$3
steps=$4
push_start=$5
push_force=$6
case "$name" in *[!a-zA-Z0-9-]*|'') echo "invalid run name" >&2; exit 2;; esac

root=/Users/n/NumiHumanBrainRuns/embodied-push-recovery-v5-push5-20260925
prior=/Users/n/NumiHumanBrainRuns/brain-v4-behavior-20260923
binary=$prior/runtime/mini-build/bin/metalrobo_numilab_human_myosim_visual_probe
library=$root/inputs/libNumiBrainHumanStanding.dylib
launcher=/Users/n/numi-lab-brain-bootstrap-source-20260923-b223dfb1/.numi/commands/human-brain-standing
output=$root/$name
[[ ! -e "$output" ]] || { echo "run already exists: $output" >&2; exit 1; }
[[ -f "$program" ]] || { echo "program missing: $program" >&2; exit 1; }
[[ $(shasum -a 256 "$binary" | awk '{print $1}') == b976b85539f7329c55ef03afdcfd6efd84c8d333b3310e2f3b127c15b4cbd8e9 ]]
[[ $(shasum -a 256 "$library" | awk '{print $1}') == e983986a23b938d81754bdc4365b39db1a405bd3ade4f67d8c6b81c1a3725eb2 ]]
available_kib=$(df -Pk /Users/n | awk 'NR==2 {print $4}')
(( available_kib >= 10485760 )) || { echo "less than 10 GiB free" >&2; exit 1; }
if ps -axo command | grep -q "^$binary "; then
  echo "another Human GPU owner is active" >&2
  exit 1
fi

export NUMI_HUMAN_BRAIN_BINARY=$binary
export NUMI_HUMAN_BRAIN_BUILD_DIR=$prior/runtime/mini-build
export NUMI_HUMAN_BRAIN_SOURCE_DIR=$prior/inputs
export NUMI_HUMAN_BRAIN_BONES=$prior/inputs/bodyparts3d-myosim-major-bones.nhbones
export NUMI_HUMAN_BRAIN_MUSCLE_SURFACES=$prior/inputs/bodyparts3d-myosim-fullbody-muscle-surfaces.nhtissue
export NUMI_HUMAN_BRAIN_DYLIB=$library
export NUMI_HUMAN_BRAIN_PROGRAM=$program
export NUMI_HUMAN_BRAIN_JOINT_PATH_CALIBRATION=1
export NUMI_HUMAN_BRAIN_SEED=$seed
export NUMI_HUMAN_BRAIN_STEPS=$steps
export NUMI_HUMAN_BRAIN_SENSOR_AUDIT=1
export NUMI_HUMAN_EXECUTION_STAGES=1
if (( push_start > 0 )); then
  export NUMI_HUMAN_BRAIN_PUSH_START_STEP=$push_start
  export NUMI_HUMAN_BRAIN_PUSH_DURATION_STEPS=20
  export NUMI_HUMAN_BRAIN_PUSH_FORCE_X_N=$push_force
  export NUMI_HUMAN_BRAIN_PUSH_FORCE_Y_N=0
  export NUMI_HUMAN_BRAIN_PUSH_FORCE_Z_N=0
fi

"$launcher" "$output" > "$root/$name-console.log" 2>&1
