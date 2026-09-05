#!/usr/bin/env bash
# Reference/boundary verification only; never executes native physics.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
work="$(mktemp -d "${TMPDIR:-/tmp}/numibrain-boundaries.XXXXXXXX")"
work="$(cd "$work" && pwd -P)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Sources" "$work/Tests/NumiBrainQualificationTests" "$work/Tests/NumiBrainValidationTests"
for module in NumiBrainQualification NumiBrainValidation NumiBrainWatchdogCLI NumiBrainGateECLI NumiBrainQualificationCLI; do
  cp -R "$repo/Sources/$module" "$work/Sources/"
done
for name in QualificationFileIOTests QualificationDeclarationTests SafetyBoundaryTests PerformanceAttemptLedgerTests; do
  cp "$repo/Tests/NumiBrainQualificationTests/$name.swift" "$work/Tests/NumiBrainQualificationTests/"
done
for name in ReachHoldObjectiveTests PhysicalSensorFieldTests; do
  cp "$repo/Tests/NumiBrainValidationTests/$name.swift" "$work/Tests/NumiBrainValidationTests/"
done
cat > "$work/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "NumiBrainBoundaryChecks", platforms: [.macOS("26.0")], products: [
  .executable(name: "numi-brain-watchdog", targets: ["NumiBrainWatchdogCLI"]),
  .executable(name: "numi-brain-gate-e", targets: ["NumiBrainGateECLI"]),
  .executable(name: "numi-brain-qualify", targets: ["NumiBrainQualificationCLI"])
], targets: [
  .target(name: "NumiBrainQualification"), .target(name: "NumiBrainValidation"),
  .executableTarget(name: "NumiBrainWatchdogCLI", dependencies: ["NumiBrainQualification"]),
  .executableTarget(name: "NumiBrainGateECLI", dependencies: ["NumiBrainQualification"]),
  .executableTarget(name: "NumiBrainQualificationCLI", dependencies: ["NumiBrainQualification"]),
  .testTarget(name: "NumiBrainQualificationTests", dependencies: ["NumiBrainQualification"]),
  .testTarget(name: "NumiBrainValidationTests", dependencies: ["NumiBrainValidation"])
])
PACKAGE
swift --version
swift test --package-path "$work"
bin="$(swift build --package-path "$work" --show-bin-path)"
set +e
"$bin/numi-brain-watchdog" check --heartbeat "$work/missing-heartbeat.json" \
  --stop-request "$work/stop.json" --expected-process 00000000-0000-4000-8000-000000000001 \
  --max-age-ns 1000000000 --max-progress-age-ns 2000000000
status="$?"
set -e
[[ "$status" == 1 && -s "$work/stop.json" ]] || { echo "missing heartbeat did not request safe state" >&2; exit 1; }
echo "Portable boundary/reference checks only; no native, MLX or physical qualification."
