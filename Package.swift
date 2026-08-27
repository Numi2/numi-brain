// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "NumiBrain",
  platforms: [
    .macOS("26.0")
  ],
  products: [
    .library(name: "NumiBrainCore", targets: ["NumiBrainCore"]),
    .library(name: "NumiBrainMetal", targets: ["NumiBrainMetal"]),
    .executable(name: "numi-brain-tissue", targets: ["NumiBrainTissueCLI"]),
  ],
  targets: [
    .target(name: "NumiBrainCore"),
    .target(
      name: "NumiBrainMetal",
      dependencies: ["NumiBrainCore"],
      resources: [.process("Shaders")]
    ),
    .executableTarget(
      name: "NumiBrainTissueCLI",
      dependencies: ["NumiBrainCore", "NumiBrainMetal"]
    ),
    .testTarget(
      name: "NumiBrainCoreTests",
      dependencies: ["NumiBrainCore"]
    ),
    .testTarget(
      name: "NumiBrainMetalTests",
      dependencies: ["NumiBrainCore", "NumiBrainMetal"]
    ),
  ]
)
