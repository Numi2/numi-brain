#!/usr/bin/env bash
# Compile the actual pure reference files without the macOS/Metal package.
# This is an offline verification harness, never a simulation or stepping path.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/numibrain-gate-d.XXXXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Sources" "$work/Tests"
cp -R "$repo/Sources/NumiBrainValidation" "$work/Sources/"
cp -R "$repo/Sources/NumiBrainGateDCLI" "$work/Sources/"
cp -R "$repo/Tests/NumiBrainValidationTests" "$work/Tests/"
cat > "$work/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "NumiBrainGateDPortableChecks",
  platforms: [.macOS("10.15.4")], products: [
  .executable(name: "numi-brain-gate-d", targets: ["NumiBrainGateDCLI"])
], targets: [
  .target(name: "NumiBrainValidation"),
  .executableTarget(name: "NumiBrainGateDCLI", dependencies: ["NumiBrainValidation"]),
  .testTarget(name: "NumiBrainValidationTests", dependencies: ["NumiBrainValidation"])
])
PACKAGE
swift --version
swift test --package-path "$work"
bin="$(swift build --package-path "$work" --show-bin-path)/numi-brain-gate-d"
"$bin" probe --input "$repo/Examples/GateD/energy-pass.json"
"$bin" import-reference --input "$repo/Examples/GateD/synthetic-force.sto" \
  --specification "$repo/Examples/GateD/force-import.json"
set +e
"$bin" probe --input "$repo/Examples/GateD/energy-fail.json"
failed="$?"
"$bin" probe --input "$repo/Examples/GateD/tangent-inconclusive.json"
inconclusive="$?"
set -e
[[ "$failed" == 1 && "$inconclusive" == 2 ]] || {
  echo "Gate D CLI returned incorrect failed/inconclusive exit codes" >&2
  exit 1
}
echo "Portable Gate D reference tests and CLI exit semantics passed. No Apple/native qualification was performed."
