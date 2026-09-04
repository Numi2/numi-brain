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
    .library(name: "NumiBrainMLX", targets: ["NumiBrainMLX"]),
    .library(name: "NumiBrainValidation", targets: ["NumiBrainValidation"]),
    .executable(name: "numi-brain-scheduler", targets: ["NumiBrainSchedulerCLI"]),
    .executable(name: "numi-brain-dispatch", targets: ["NumiBrainDispatchCLI"]),
    .executable(name: "numi-brain-tissue", targets: ["NumiBrainTissueCLI"]),
    .executable(name: "numi-brain-policy", targets: ["NumiBrainPolicyCLI"]),
    .executable(
      name: "numi-brain-numanx-interop",
      targets: ["NumiBrainNumanXInteropCLI"]
    ),
    .executable(name: "numi-brain-gate-c", targets: ["NumiBrainGateCCLI"]),
    .executable(name: "numi-brain-gate-d", targets: ["NumiBrainGateDCLI"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/ml-explore/mlx-swift.git",
      exact: "0.31.3"
    )
  ],
  targets: [
    .target(name: "NumiBrainValidation"),
    .target(
      name: "NumiBrainABI",
      publicHeadersPath: "include"
    ),
    .target(
      name: "NumiBrainCore",
      dependencies: ["NumiBrainABI", "NumiBrainValidation"]
    ),
    .target(
      name: "NumiBrainMetalBridgeABI",
      dependencies: ["NumiBrainABI"],
      publicHeadersPath: "include"
    ),
    .target(
      name: "NumiBrainMetal",
      dependencies: [
        "NumiBrainABI", "NumiBrainCore", "NumiBrainMetalBridgeABI",
      ],
      resources: [.process("Shaders")]
    ),
    .target(
      name: "NumiBrainMLX",
      dependencies: [
        "NumiBrainCore",
        "NumiBrainMetal",
        .product(name: "MLX", package: "mlx-swift"),
      ]
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
    .executableTarget(
      name: "NumiBrainPolicyCLI",
      dependencies: ["NumiBrainCore"]
    ),
    .executableTarget(
      name: "NumiBrainNumanXInteropCLI",
      dependencies: ["NumiBrainABI", "NumiBrainCore", "NumiBrainMetal"]
    ),
    .executableTarget(
      name: "NumiBrainGateCCLI",
      dependencies: ["NumiBrainCore", "NumiBrainMetal", "NumiBrainMLX"]
    ),
    .executableTarget(
      name: "NumiBrainGateDCLI",
      dependencies: ["NumiBrainCore", "NumiBrainValidation"]
    ),
    .testTarget(
      name: "NumiBrainCoreTests",
      dependencies: ["NumiBrainABI", "NumiBrainCore", "NumiBrainValidation"]
    ),
    .testTarget(
      name: "NumiBrainMetalTests",
      dependencies: ["NumiBrainCore", "NumiBrainMetal", "NumiBrainMLX"]
    ),
    .testTarget(name: "NumiBrainValidationTests", dependencies: ["NumiBrainValidation"]),
  ],
  cxxLanguageStandard: .cxx20
)
