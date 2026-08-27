import CoreGraphics
import Darwin
import Foundation
import ImageIO
import NumiBrainCore
import NumiBrainMetal
import UniformTypeIdentifiers

private enum Backend: String, Codable {
  case cpu
  case metal
}

private struct Options {
  var backend: Backend = .metal
  var width = 128
  var height = 128
  var durationMilliseconds: Float = 300
  var controlMilliseconds: Float = 20
  var outputPath: String?
  var snapshotPath: String?
  var verifyCPU = false
  var verifyReplay = false

  static func parse(_ arguments: [String]) throws -> Options {
    var options = Options()
    var index = 0

    func value(after flag: String) throws -> String {
      let valueIndex = index + 1
      guard valueIndex < arguments.count else {
        throw CLIError("\(flag) requires a value")
      }
      index = valueIndex
      return arguments[valueIndex]
    }

    while index < arguments.count {
      let argument = arguments[index]
      switch argument {
      case "--backend":
        let raw = try value(after: argument)
        guard let backend = Backend(rawValue: raw) else {
          throw CLIError("--backend must be cpu or metal")
        }
        options.backend = backend
      case "--width":
        options.width = try parseInt(try value(after: argument), flag: argument)
      case "--height":
        options.height = try parseInt(try value(after: argument), flag: argument)
      case "--duration-ms":
        options.durationMilliseconds = try parseFloat(
          try value(after: argument),
          flag: argument
        )
      case "--control-ms":
        options.controlMilliseconds = try parseFloat(
          try value(after: argument),
          flag: argument
        )
      case "--output":
        options.outputPath = try value(after: argument)
      case "--snapshot":
        options.snapshotPath = try value(after: argument)
      case "--verify-cpu":
        options.verifyCPU = true
      case "--verify-replay":
        options.verifyReplay = true
      case "--help", "-h":
        printUsage()
        Darwin.exit(EXIT_SUCCESS)
      default:
        throw CLIError("unknown argument: \(argument)")
      }
      index += 1
    }

    guard options.width > 0, options.height > 0 else {
      throw CLIError("grid dimensions must be positive")
    }
    guard options.durationMilliseconds > 0, options.controlMilliseconds > 0 else {
      throw CLIError("duration and control interval must be positive")
    }
    return options
  }

  private static func parseInt(_ raw: String, flag: String) throws -> Int {
    guard let value = Int(raw) else {
      throw CLIError("\(flag) expects an integer")
    }
    return value
  }

  private static func parseFloat(_ raw: String, flag: String) throws -> Float {
    guard let value = Float(raw), value.isFinite else {
      throw CLIError("\(flag) expects a finite number")
    }
    return value
  }

  private static func printUsage() {
    print(
      """
      Usage: numi-brain-tissue [options]

        --backend cpu|metal   Execution backend (default: metal)
        --width N             Tissue grid width (default: 128)
        --height N            Tissue grid height (default: 128)
        --duration-ms N       Accepted simulation duration (default: 300)
        --control-ms N        Root transaction interval (default: 20)
        --output PATH         Write JSON evidence to PATH
        --snapshot PATH       Write final activity as a PNG heatmap
        --verify-cpu          Compare the final Metal state with the CPU oracle
        --verify-replay       Repeat the run and compare the final state hash
        --help                Show this help
      """
    )
  }
}

private struct CLIError: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}

private struct GridShape: Codable {
  let width: Int
  let height: Int
  let cells: Int
}

private struct TimingEvidence: Codable {
  let wallSeconds: Double
  let gpuSeconds: Double?
  let attemptedSubsteps: Int
  let acceptedSubsteps: Int
  let rootTransactions: Int
  let cellUpdatesPerSecond: Double
  let gpuCellUpdatesPerSecond: Double?
}

private struct MemoryEvidence: Codable {
  let bytesPerCell: Int
  let stateGenerationCount: Int
  let stateGenerationBytes: Int
  let uniformArenaBytes: Int
  let residencyAllocatedBytes: UInt64?
  let storageMode: String
}

private struct VerificationEvidence: Codable {
  let cpuReferenceMaximumAbsoluteError: Float?
  let cpuReferenceTolerance: Float?
  let cpuReferencePassed: Bool?
  let replayExact: Bool?
}

private struct SimulationEvidence: Codable {
  let schema: String
  let backend: Backend
  let device: String
  let operatingSystem: String
  let revision: String
  let model: String
  let numericalScope: String
  let grid: GridShape
  let timestepMilliseconds: Float
  let acceptedDurationMilliseconds: Float
  let controlIntervalMilliseconds: Float
  let timing: TimingEvidence
  let memory: MemoryEvidence
  let metrics: TissueMetrics
  let rollbackRetryExact: Bool
  let rootAbortExact: Bool
  let verification: VerificationEvidence
  let snapshotPath: String?
  let executionPath: String
}

@main
private struct NumiBrainTissueCommand {
  static func main() {
    do {
      let options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
      let evidence = try run(options: options)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      let data = try encoder.encode(evidence)
      if let outputPath = options.outputPath {
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
          at: outputURL.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        try data.write(to: outputURL, options: .atomic)
      }
      FileHandle.standardOutput.write(data)
      FileHandle.standardOutput.write(Data([0x0a]))
    } catch {
      FileHandle.standardError.write(Data("numi-brain-tissue: \(error)\n".utf8))
      Darwin.exit(EXIT_FAILURE)
    }
  }

  private static func run(options: Options) throws -> SimulationEvidence {
    let parameters = TissueParameters.corticalSheetV0
    let stimulus = TissueStimulus(
      radius: 0.08,
      excitatoryDrive: 5,
      startMilliseconds: 20,
      endMilliseconds: 70
    )
    let initialState = try CPUTissueDynamics.makeRestingGrid(
      width: options.width,
      height: options.height,
      parameters: parameters
    )
    let totalSubsteps = Int(
      ceil(
        options.durationMilliseconds / parameters.timestepMilliseconds
      ))
    let substepsPerControl = max(
      1,
      Int(
        round(
          options.controlMilliseconds / parameters.timestepMilliseconds
        )))

    let start = ContinuousClock.now
    let result:
      (
        state: TissueGrid,
        device: String,
        gpuSeconds: Double?,
        rootTransactions: Int,
        residencyAllocatedBytes: UInt64?
      )
    switch options.backend {
    case .cpu:
      result = try runCPU(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        totalSubsteps: totalSubsteps,
        substepsPerControl: substepsPerControl
      )
    case .metal:
      guard #available(macOS 26.0, *) else {
        throw CLIError("Metal 4 execution requires macOS 26 or later")
      }
      result = try runMetal(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        totalSubsteps: totalSubsteps,
        substepsPerControl: substepsPerControl
      )
    }
    let elapsed = start.duration(to: .now).components
    let wallSeconds =
      Double(elapsed.seconds)
      + Double(elapsed.attoseconds) / 1_000_000_000_000_000_000
    let rollback = try rollbackEvidence(
      backend: options.backend,
      initialState: initialState,
      parameters: parameters,
      stimulus: stimulus
    )
    let cpuParity: (error: Float, tolerance: Float, passed: Bool)?
    if options.verifyCPU, options.backend == .metal {
      let reference = try runCPU(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        totalSubsteps: totalSubsteps,
        substepsPerControl: substepsPerControl
      ).0
      let error = maximumDifference(reference, result.state)
      let tolerance: Float = 3e-5
      cpuParity = (error, tolerance, error <= tolerance)
    } else {
      cpuParity = nil
    }
    let replayExact: Bool?
    if options.verifyReplay {
      let replay: TissueGrid
      switch options.backend {
      case .cpu:
        replay = try runCPU(
          initialState: initialState,
          parameters: parameters,
          stimulus: stimulus,
          totalSubsteps: totalSubsteps,
          substepsPerControl: substepsPerControl
        ).0
      case .metal:
        guard #available(macOS 26.0, *) else {
          throw CLIError("Metal replay verification requires macOS 26 or later")
        }
        replay = try runMetal(
          initialState: initialState,
          parameters: parameters,
          stimulus: stimulus,
          totalSubsteps: totalSubsteps,
          substepsPerControl: substepsPerControl
        ).0
      }
      replayExact = replay.stableHash() == result.state.stableHash()
    } else {
      replayExact = nil
    }
    let metrics = CPUTissueDynamics.metrics(for: result.state, stimulus: stimulus)
    let cellUpdates = Double(initialState.count * totalSubsteps)
    if let snapshotPath = options.snapshotPath {
      try writeSnapshot(result.state, to: snapshotPath)
    }

    return SimulationEvidence(
      schema: "numibrain.tissue-simulation-evidence.v0",
      backend: options.backend,
      device: result.device,
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      revision: ProcessInfo.processInfo.environment["NUMIBRAIN_REVISION"] ?? "unknown",
      model: "spatially-extended normalized Wilson-Cowan E/I field with adaptation",
      numericalScope: "mesoscale neural population tissue; uncalibrated research scaffold",
      grid: GridShape(
        width: initialState.width,
        height: initialState.height,
        cells: initialState.count
      ),
      timestepMilliseconds: parameters.timestepMilliseconds,
      acceptedDurationMilliseconds: Float(totalSubsteps) * parameters.timestepMilliseconds,
      controlIntervalMilliseconds: Float(substepsPerControl) * parameters.timestepMilliseconds,
      timing: TimingEvidence(
        wallSeconds: wallSeconds,
        gpuSeconds: result.gpuSeconds,
        attemptedSubsteps: totalSubsteps,
        acceptedSubsteps: totalSubsteps,
        rootTransactions: result.rootTransactions,
        cellUpdatesPerSecond: wallSeconds > 0 ? cellUpdates / wallSeconds : 0,
        gpuCellUpdatesPerSecond: result.gpuSeconds.flatMap {
          $0 > 0 ? cellUpdates / $0 : nil
        }
      ),
      memory: MemoryEvidence(
        bytesPerCell: MemoryLayout<TissueCell>.stride,
        stateGenerationCount: 3,
        stateGenerationBytes: initialState.count * MemoryLayout<TissueCell>.stride * 3,
        uniformArenaBytes: max(substepsPerControl, 2) * TissueUniforms.byteCount,
        residencyAllocatedBytes: result.residencyAllocatedBytes,
        storageMode: options.backend == .metal
          ? "MTLStorageMode.shared unified memory; no per-substep CPU access"
          : "CPU reference arrays"
      ),
      metrics: metrics,
      rollbackRetryExact: rollback.retry,
      rootAbortExact: rollback.abort,
      verification: VerificationEvidence(
        cpuReferenceMaximumAbsoluteError: cpuParity?.error,
        cpuReferenceTolerance: cpuParity?.tolerance,
        cpuReferencePassed: cpuParity?.passed,
        replayExact: replayExact
      ),
      snapshotPath: options.snapshotPath,
      executionPath: options.backend == .metal
        ? "MTL4CommandQueue -> reusable MTL4CommandBuffer -> MTL4ComputeCommandEncoder -> MTL4ArgumentTable"
        : "Swift FP32 CPU oracle"
    )
  }

  private static func runCPU(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    totalSubsteps: Int,
    substepsPerControl: Int
  ) throws -> (TissueGrid, String, Double?, Int, UInt64?) {
    var runtime = try CPUTissueRuntime(
      initialState: initialState,
      parameters: parameters,
      stimulus: stimulus
    )
    var completed = 0
    var rootTransactions = 0
    while completed < totalSubsteps {
      let count = min(substepsPerControl, totalSubsteps - completed)
      try runtime.runRootTransaction(
        at: Float(completed) * parameters.timestepMilliseconds,
        acceptedSubsteps: Array(repeating: true, count: count)
      )
      completed += count
      rootTransactions += 1
    }
    return (runtime.committed, "CPU reference", nil, rootTransactions, nil)
  }

  @available(macOS 26.0, *)
  private static func runMetal(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    totalSubsteps: Int,
    substepsPerControl: Int
  ) throws -> (TissueGrid, String, Double?, Int, UInt64?) {
    let runtime = try MetalTissueRuntime(
      initialState: initialState,
      parameters: parameters,
      stimulus: stimulus,
      maxEncodedSubsteps: max(substepsPerControl, 2)
    )
    var completed = 0
    var rootTransactions = 0
    var gpuSeconds = 0.0
    while completed < totalSubsteps {
      let count = min(substepsPerControl, totalSubsteps - completed)
      let submission = try runtime.runRootTransaction(
        at: Float(completed) * parameters.timestepMilliseconds,
        acceptedSubsteps: Array(repeating: true, count: count)
      )
      try runtime.commitRootTransaction()
      gpuSeconds += submission.gpuDurationSeconds
      completed += count
      rootTransactions += 1
    }
    return (
      try runtime.snapshotCommitted(),
      runtime.deviceName,
      gpuSeconds,
      rootTransactions,
      runtime.residencyAllocatedBytes
    )
  }

  private static func rollbackEvidence(
    backend: Backend,
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus
  ) throws -> (retry: Bool, abort: Bool) {
    switch backend {
    case .cpu:
      var direct = try CPUTissueRuntime(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus
      )
      var retried = direct
      var aborted = direct
      try direct.runRootTransaction(at: 0, acceptedSubsteps: [true])
      try retried.runRootTransaction(at: 0, acceptedSubsteps: [false, true])
      try aborted.runRootTransaction(at: 0, acceptedSubsteps: [true], commit: false)
      return (
        direct.committed.stableHash() == retried.committed.stableHash(),
        aborted.committed.stableHash() == initialState.stableHash()
      )
    case .metal:
      guard #available(macOS 26.0, *) else {
        throw CLIError("Metal rollback evidence requires macOS 26 or later")
      }
      let direct = try MetalTissueRuntime(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        maxEncodedSubsteps: 2
      )
      let retried = try MetalTissueRuntime(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        maxEncodedSubsteps: 2
      )
      let aborted = try MetalTissueRuntime(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        maxEncodedSubsteps: 2
      )
      _ = try direct.runRootTransaction(at: 0, acceptedSubsteps: [true])
      try direct.commitRootTransaction()
      _ = try retried.runRootTransaction(at: 0, acceptedSubsteps: [false, true])
      try retried.commitRootTransaction()
      _ = try aborted.runRootTransaction(at: 0, acceptedSubsteps: [true])
      try aborted.abortRootTransaction()
      return (
        try direct.snapshotCommitted().stableHash()
          == retried.snapshotCommitted().stableHash(),
        try aborted.snapshotCommitted().stableHash() == initialState.stableHash()
      )
    }
  }

  private static func maximumDifference(_ lhs: TissueGrid, _ rhs: TissueGrid) -> Float {
    zip(lhs.cells, rhs.cells).reduce(0) { result, pair in
      let difference = pair.0 - pair.1
      return max(
        result,
        max(abs(difference.x), abs(difference.y), abs(difference.z), abs(difference.w))
      )
    }
  }

  private static func writeSnapshot(_ grid: TissueGrid, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    var pixels = Data()
    pixels.reserveCapacity(grid.count * 4)
    for cell in grid.cells {
      let excitatory = min(max((cell.x - 0.04) / 0.84, 0), 1)
      let inhibitory = min(max((cell.y - 0.04) / 0.40, 0), 1)
      let adaptation = min(max((cell.z - 0.04) / 0.30, 0), 1)
      pixels.append(UInt8(255 * sqrt(excitatory)))
      pixels.append(UInt8(255 * min(excitatory * 0.35 + adaptation * 0.65, 1)))
      pixels.append(UInt8(255 * min(inhibitory * 0.85 + 0.05, 1)))
      pixels.append(255)
    }
    guard let provider = CGDataProvider(data: pixels as CFData),
      let image = CGImage(
        width: grid.width,
        height: grid.height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: grid.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(
          rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      ),
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
      )
    else {
      throw CLIError("failed to create PNG snapshot at \(path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw CLIError("failed to finalize PNG snapshot at \(path)")
    }
  }
}
