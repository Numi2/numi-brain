#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/numibrain-gates-ef.XXXXXXXX")"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/Sources" "$work/Tests"
cp -R "$repo/Sources/NumiBrainQualification" "$work/Sources/"
cp -R "$repo/Sources/NumiBrainGateECLI" "$work/Sources/"
cp -R "$repo/Sources/NumiBrainGateFCLI" "$work/Sources/"
cp -R "$repo/Sources/NumiBrainWatchdogCLI" "$work/Sources/"
cp -R "$repo/Sources/NumiBrainQualificationCLI" "$work/Sources/"
cp -R "$repo/Tests/NumiBrainQualificationTests" "$work/Tests/"

cat > "$work/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(
  name: "NumiBrainGatesEFPortable",
  products: [
    .executable(name: "numi-brain-gate-e", targets: ["NumiBrainGateECLI"]),
    .executable(name: "numi-brain-gate-f", targets: ["NumiBrainGateFCLI"]),
    .executable(name: "numi-brain-watchdog", targets: ["NumiBrainWatchdogCLI"]),
    .executable(name: "numi-brain-qualify", targets: ["NumiBrainQualificationCLI"]),
  ],
  targets: [
    .target(name: "NumiBrainQualification"),
    .executableTarget(name: "NumiBrainGateECLI", dependencies: ["NumiBrainQualification"]),
    .executableTarget(name: "NumiBrainGateFCLI", dependencies: ["NumiBrainQualification"]),
    .executableTarget(name: "NumiBrainWatchdogCLI", dependencies: ["NumiBrainQualification"]),
    .executableTarget(name: "NumiBrainQualificationCLI", dependencies: ["NumiBrainQualification"]),
    .testTarget(name: "NumiBrainQualificationTests", dependencies: ["NumiBrainQualification"]),
  ]
)
PACKAGE

swift --version
swift test --package-path "$work"
swift build --package-path "$work" --product numi-brain-gate-e
swift build --package-path "$work" --product numi-brain-gate-f
swift build --package-path "$work" --product numi-brain-watchdog
swift build --package-path "$work" --product numi-brain-qualify

echo "Portable Gate E/F qualification module, tests, and CLIs compiled."
echo "This does not measure Apple performance, execute NumanX physics, or qualify deployment safety."
