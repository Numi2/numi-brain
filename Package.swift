// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "NumiBrain",
  platforms: [
    .macOS("26.0")
  ],
  products: [
    .library(name: "NumiBrainABI", targets: ["NumiBrainABI"]),
    .library(name: "NumiBrainCore", targets: ["NumiBrainCore"]),
    .library(name: "NumiBrainMetal", targets: ["NumiBrainMetal"]),
    .executable(name: "numi-brain-scheduler", targets: ["NumiBrainSchedulerCLI"]),
    .executable(name: "numi-brain-dispatch", targets: ["NumiBrainDispatchCLI"]),
    .executable(name: "numi-brain-tissue", targets: ["NumiBrainTissueCLI"]),
  ],
  targets: [
    .target(
      name: "NumiBrainABI",
      publicHeadersPath: "include"
    ),
    .target(
      name: "NumiBrainCore",
      dependencies: ["NumiBrainABI"]
    ),
    .target(
      name: "NumiBrainMetal",
      dependencies: ["NumiBrainABI", "NumiBrainCore"],
      resources: [.process("Shaders")]
    ),
    .executableTarget(
      name: "NumiBrainSchedulerCLI",
      dependencies: ["NumiBrainABI", "NumiBrainCore"]
    ),
    .executableTarget(
      name: "NumiBrainDispatchCLI",
      dependencies: ["NumiBrainABI", "NumiBrainCore", "NumiBrainMetal"]
    ),
    .executableTarget(
      name: "NumiBrainTissueCLI",
      dependencies: ["NumiBrainCore", "NumiBrainMetal"]
    ),
    .testTarget(
      name: "NumiBrainCoreTests",
      dependencies: ["NumiBrainABI", "NumiBrainCore"]
    ),
    .testTarget(
      name: "NumiBrainMetalTests",
      dependencies: ["NumiBrainCore", "NumiBrainMetal"]
    ),
  ],
  cxxLanguageStandard: .cxx20
)
