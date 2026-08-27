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

private enum StructureProfile: String, Codable {
  case homogeneous
  case layered
}

private enum DelayProfile: String, Codable {
  case instantaneous
  case layered
}

private enum ConnectomeProfile: String, Codable {
  case none
  case bilateral
}

private struct LesionOptions: Codable {
  var centerX: Float = 0.5
  var centerY: Float = 0.5
  var radius: Float = 0
  var viability: Float = 0
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
  var structureProfile: StructureProfile = .layered
  var delayProfile: DelayProfile = .layered
  var connectomeProfile: ConnectomeProfile = .bilateral
  var stimulusNoiseAmplitude: Float = 0.25
  var randomSeed: UInt32 = 1
  var environmentIdentifier: UInt32 = 0
  var episodeIdentifier: UInt32 = 0
  var lesion = LesionOptions()
  var stimulus = TissueStimulus(
    radius: 0.08,
    excitatoryDrive: 5,
    startMilliseconds: 20,
    endMilliseconds: 70
  )

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
      case "--structure":
        let raw = try value(after: argument)
        guard let profile = StructureProfile(rawValue: raw) else {
          throw CLIError("--structure must be homogeneous or layered")
        }
        options.structureProfile = profile
      case "--delays":
        let raw = try value(after: argument)
        guard let profile = DelayProfile(rawValue: raw) else {
          throw CLIError("--delays must be instantaneous or layered")
        }
        options.delayProfile = profile
      case "--connectome":
        let raw = try value(after: argument)
        guard let profile = ConnectomeProfile(rawValue: raw) else {
          throw CLIError("--connectome must be none or bilateral")
        }
        options.connectomeProfile = profile
      case "--lesion-x":
        options.lesion.centerX = try parseFloat(try value(after: argument), flag: argument)
      case "--lesion-y":
        options.lesion.centerY = try parseFloat(try value(after: argument), flag: argument)
      case "--lesion-radius":
        options.lesion.radius = try parseFloat(try value(after: argument), flag: argument)
      case "--lesion-viability":
        options.lesion.viability = try parseFloat(try value(after: argument), flag: argument)
      case "--stimulus-x":
        options.stimulus.centerX = try parseFloat(try value(after: argument), flag: argument)
      case "--stimulus-y":
        options.stimulus.centerY = try parseFloat(try value(after: argument), flag: argument)
      case "--stimulus-radius":
        options.stimulus.radius = try parseFloat(try value(after: argument), flag: argument)
      case "--stimulus-drive":
        options.stimulus.excitatoryDrive = try parseFloat(
          try value(after: argument),
          flag: argument
        )
      case "--stimulus-inhibition":
        options.stimulus.inhibitoryDrive = try parseFloat(
          try value(after: argument),
          flag: argument
        )
      case "--stimulus-start-ms":
        options.stimulus.startMilliseconds = try parseFloat(
          try value(after: argument),
          flag: argument
        )
      case "--stimulus-end-ms":
        options.stimulus.endMilliseconds = try parseFloat(
          try value(after: argument),
          flag: argument
        )
      case "--stimulus-noise":
        options.stimulusNoiseAmplitude = try parseFloat(
          try value(after: argument),
          flag: argument
        )
      case "--seed":
        options.randomSeed = try parseUInt32(try value(after: argument), flag: argument)
      case "--environment-id":
        options.environmentIdentifier = try parseUInt32(
          try value(after: argument),
          flag: argument
        )
      case "--episode-id":
        options.episodeIdentifier = try parseUInt32(
          try value(after: argument),
          flag: argument
        )
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
    try options.stimulus.validate()
    guard options.stimulusNoiseAmplitude >= 0 else {
      throw CLIError("--stimulus-noise must be nonnegative")
    }
    guard (0...1).contains(options.lesion.centerX),
      (0...1).contains(options.lesion.centerY),
      options.lesion.radius >= 0,
      (0...1).contains(options.lesion.viability)
    else {
      throw CLIError(
        "lesion center and viability must lie in [0, 1], with nonnegative radius"
      )
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

  private static func parseUInt32(_ raw: String, flag: String) throws -> UInt32 {
    let value: UInt32?
    if raw.lowercased().hasPrefix("0x") {
      value = UInt32(raw.dropFirst(2), radix: 16)
    } else {
      value = UInt32(raw)
    }
    guard let value else {
      throw CLIError("\(flag) expects an unsigned 32-bit integer")
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
        --structure homogeneous|layered  Tissue profile (default: layered)
        --delays instantaneous|layered  Conduction profile (default: layered)
        --connectome none|bilateral  Sparse projection profile (default: bilateral)
        --lesion-x N          Normalized lesion center x (default: 0.5)
        --lesion-y N          Normalized lesion center y (default: 0.5)
        --lesion-radius N     Normalized lesion radius (default: 0, disabled)
        --lesion-viability N  Remaining viability inside lesion (default: 0)
        --stimulus-x N        Normalized stimulus center x (default: 0.5)
        --stimulus-y N        Normalized stimulus center y (default: 0.5)
        --stimulus-radius N   Normalized stimulus radius (default: 0.08)
        --stimulus-drive N    Excitatory drive (default: 5)
        --stimulus-inhibition N  Inhibitory drive (default: 0)
        --stimulus-start-ms N Stimulus start time (default: 20)
        --stimulus-end-ms N   Stimulus end time (default: 70)
        --stimulus-noise N    Bounded receptor-drive noise (default: 0.25)
        --seed N              Counter-random seed, decimal or hex (default: 1)
        --environment-id N    Counter-random environment identity (default: 0)
        --episode-id N        Counter-random episode identity (default: 0)
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
  let gpuEventCompactionDispatches: Int?
  let gpuSchedulerDispatches: Int?
  let cellUpdatesPerSecond: Double
  let gpuCellUpdatesPerSecond: Double?
}

private struct MemoryEvidence: Codable {
  let bytesPerCell: Int
  let stateGenerationCount: Int
  let stateGenerationBytes: Int
  let uniformArenaBytes: Int
  let structureBytes: Int
  let delayFieldBytes: Int
  let projectionOffsetBytes: Int
  let projectionEdgeBytes: Int
  let eventScheduleBytes: Int
  let activeEventIndexBytes: Int
  let relayHistoryPlaneCount: Int
  let relayHistoryBytes: Int
  let relayTransactionBytes: Int
  let residencyAllocatedBytes: UInt64?
  let storageMode: String
}

private struct ConductionEvidence: Codable {
  let profile: DelayProfile
  let hash: String
  let maximumDelaySteps: Int
  let maximumDelayMilliseconds: Float
  let historyCapacity: Int
  let interpretation: String
}

private struct ConnectomeEvidence: Codable {
  let profile: ConnectomeProfile
  let hash: String
  let edgeCount: Int
  let maximumIncomingProjectionCount: Int
  let maximumDelaySteps: Int
  let interpretation: String
}

private struct EventEvidence: Codable {
  let hash: String
  let count: Int
  let maximumScheduleCount: Int
  let maximumSimultaneouslyActiveCount: Int
  let packedBytes: Int
  let stimulusNoiseAmplitude: Float
  let flags: UInt32
  let execution: String
  let interpretation: String
}

private struct SchedulerEvidence: Codable {
  let abiVersion: UInt32
  let scheduleFingerprint: String
  let moduleCount: Int
  let descriptorBytes: Int
  let clockGenerationCount: Int
  let clockBytes: Int
  let sharedEventCapacityBytes: Int
  let sharedUniformBytes: Int
  let privateInvocationCapacityBytes: Int
  let privateResultBytes: Int
  let maximumInputEvents: Int
  let maximumInvocations: Int
  let committedTimeMicroseconds: UInt64
  let committedGeneration: UInt64
  let finalRootInvocationCount: Int
  let finalSnapshotHash: String
  let cpuReferenceExact: Bool
  let status: UInt32
  let execution: String
  let interpretation: String
}

private struct RandomEvidence: Codable {
  let generator: String
  let context: TissueRandomContext
  let mutableStateBytes: Int
  let key: String
}

private struct StructureEvidence: Codable {
  let profile: StructureProfile
  let hash: String
  let bytes: Int
  let lesion: LesionOptions
  let interpretation: String
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
  let parameters: TissueParameters
  let stimulus: TissueStimulus
  let structure: StructureEvidence
  let conduction: ConductionEvidence
  let connectome: ConnectomeEvidence
  let events: EventEvidence
  let scheduler: SchedulerEvidence?
  let random: RandomEvidence
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
    let stimulus = options.stimulus
    var structure: TissueStructure
    switch options.structureProfile {
    case .homogeneous:
      structure = try TissueStructure.homogeneous(
        width: options.width,
        height: options.height
      )
    case .layered:
      structure = try TissueStructure.layeredCorticalSheetV0(
        width: options.width,
        height: options.height
      )
    }
    if options.lesion.radius > 0 {
      try structure.applyCircularLesion(
        centerX: options.lesion.centerX,
        centerY: options.lesion.centerY,
        radius: options.lesion.radius,
        viability: options.lesion.viability
      )
    }
    let delayField: TissueDelayField
    switch options.delayProfile {
    case .instantaneous:
      delayField = try TissueDelayField.instantaneous(
        width: options.width,
        height: options.height
      )
    case .layered:
      delayField = try TissueDelayField.layeredCorticalSheetV0(
        width: options.width,
        height: options.height
      )
    }
    let connectome: TissueConnectome
    switch options.connectomeProfile {
    case .none:
      connectome = try TissueConnectome.none(
        width: options.width,
        height: options.height
      )
    case .bilateral:
      connectome = try TissueConnectome.bilateralBridgeV0(
        width: options.width,
        height: options.height
      )
    }
    let eventSchedule = try TissueEventSchedule.singleStimulus(
      stimulus,
      noiseAmplitude: options.stimulusNoiseAmplitude
    )
    let randomContext = TissueRandomContext(
      seed: options.randomSeed,
      environmentIdentifier: options.environmentIdentifier,
      episodeIdentifier: options.episodeIdentifier
    )
    let initialState = try CPUTissueDynamics.makeRestingGrid(
      parameters: parameters,
      structure: structure
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
        residencyAllocatedBytes: UInt64?,
        eventCompactionDispatches: Int?,
        schedulerDispatches: Int?,
        scheduler: SchedulerEvidence?
      )
    switch options.backend {
    case .cpu:
      result = try runCPU(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        structure: structure,
        delayField: delayField,
        connectome: connectome,
        eventSchedule: eventSchedule,
        randomContext: randomContext,
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
        structure: structure,
        delayField: delayField,
        connectome: connectome,
        eventSchedule: eventSchedule,
        randomContext: randomContext,
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
      stimulus: stimulus,
      structure: structure,
      delayField: delayField,
      connectome: connectome,
      eventSchedule: eventSchedule,
      randomContext: randomContext
    )
    let cpuParity: (error: Float, tolerance: Float, passed: Bool)?
    if options.verifyCPU, options.backend == .metal {
      let reference = try runCPU(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        structure: structure,
        delayField: delayField,
        connectome: connectome,
        eventSchedule: eventSchedule,
        randomContext: randomContext,
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
      var replaySchedulerHash: String?
      switch options.backend {
      case .cpu:
        replay = try runCPU(
          initialState: initialState,
          parameters: parameters,
          stimulus: stimulus,
          structure: structure,
          delayField: delayField,
          connectome: connectome,
          eventSchedule: eventSchedule,
          randomContext: randomContext,
          totalSubsteps: totalSubsteps,
          substepsPerControl: substepsPerControl
        ).0
      case .metal:
        guard #available(macOS 26.0, *) else {
          throw CLIError("Metal replay verification requires macOS 26 or later")
        }
        let metalReplay = try runMetal(
          initialState: initialState,
          parameters: parameters,
          stimulus: stimulus,
          structure: structure,
          delayField: delayField,
          connectome: connectome,
          eventSchedule: eventSchedule,
          randomContext: randomContext,
          totalSubsteps: totalSubsteps,
          substepsPerControl: substepsPerControl
        )
        replay = metalReplay.state
        replaySchedulerHash = metalReplay.scheduler?.finalSnapshotHash
      }
      replayExact =
        replay.stableHash() == result.state.stableHash()
        && replaySchedulerHash == result.scheduler?.finalSnapshotHash
    } else {
      replayExact = nil
    }
    let metrics = CPUTissueDynamics.metrics(
      for: result.state,
      stimulus: stimulus,
      structure: structure
    )
    let cellUpdates = Double(initialState.count * totalSubsteps)
    if let snapshotPath = options.snapshotPath {
      try writeSnapshot(result.state, to: snapshotPath)
    }

    return SimulationEvidence(
      schema: "numibrain.tissue-simulation-evidence.v6",
      backend: options.backend,
      device: result.device,
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      revision: ProcessInfo.processInfo.environment["NUMIBRAIN_REVISION"] ?? "unknown",
      model:
        "heterogeneous Wilson-Cowan E/I field with GPU-compacted receptor events, transactional Metal multi-rate scheduling, adaptation, local conduction delays, and sparse delayed projections",
      numericalScope: "mesoscale neural population tissue; uncalibrated research scaffold",
      grid: GridShape(
        width: initialState.width,
        height: initialState.height,
        cells: initialState.count
      ),
      parameters: parameters,
      stimulus: stimulus,
      structure: StructureEvidence(
        profile: options.structureProfile,
        hash: structure.stableHash(),
        bytes: structure.count * MemoryLayout<TissueSite>.stride,
        lesion: options.lesion,
        interpretation: "synthetic uncalibrated strata; viability gates activity and coupling"
      ),
      conduction: ConductionEvidence(
        profile: options.delayProfile,
        hash: delayField.stableHash(),
        maximumDelaySteps: delayField.maximumConfiguredDelaySteps,
        maximumDelayMilliseconds: Float(delayField.maximumConfiguredDelaySteps)
          * parameters.timestepMilliseconds,
        historyCapacity: TissueDelayField.historyCapacity,
        interpretation: "synthetic outgoing delay classes; not calibrated conduction velocity"
      ),
      connectome: ConnectomeEvidence(
        profile: options.connectomeProfile,
        hash: connectome.stableHash(),
        edgeCount: connectome.edgeCount,
        maximumIncomingProjectionCount: connectome.maximumIncomingProjectionCount,
        maximumDelaySteps: connectome.maximumProjectionDelaySteps,
        interpretation:
          "synthetic destination-major sparse projection graph; not an anatomical connectome"
      ),
      events: EventEvidence(
        hash: eventSchedule.stableHash(),
        count: eventSchedule.eventCount,
        maximumScheduleCount: TissueEventSchedule.maximumEventCount,
        maximumSimultaneouslyActiveCount:
          eventSchedule.maximumSimultaneouslyActiveEventCount,
        packedBytes: eventSchedule.packedByteCount,
        stimulusNoiseAmplitude: options.stimulusNoiseAmplitude,
        flags: eventSchedule.events.reduce(UInt32.zero) { result, event in
          result | event.flags.rawValue
        },
        execution: options.backend == .metal
          ? "GPU compact_receptor_events dispatch per attempted substep, followed by active-only tissue scan"
          : "CPU canonical active-index selection followed by active-only tissue scan",
        interpretation:
          "receptor-derived neural input schedule; not raw or privileged simulator state"
      ),
      scheduler: result.scheduler,
      random: RandomEvidence(
        generator: "NumiBrain counter hash v1 with upper-24-bit FP32 uniform samples",
        context: randomContext,
        mutableStateBytes: 0,
        key:
          "seed, environment, episode, module, accepted step, event identifier, site, sample lane"
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
        gpuEventCompactionDispatches: result.eventCompactionDispatches,
        gpuSchedulerDispatches: result.schedulerDispatches,
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
        structureBytes: structure.count * MemoryLayout<TissueSite>.stride,
        delayFieldBytes: delayField.count * MemoryLayout<UInt8>.stride,
        projectionOffsetBytes: connectome.destinationOffsets.count
          * MemoryLayout<UInt32>.stride,
        projectionEdgeBytes: connectome.edgeCount
          * MemoryLayout<TissueConnectome.PackedEdge>.stride,
        eventScheduleBytes: eventSchedule.packedByteCount,
        activeEventIndexBytes: options.backend == .metal
          ? eventSchedule.activeIndexByteCapacity
          : 0,
        relayHistoryPlaneCount: options.backend == .metal ? 2 : 1,
        relayHistoryBytes: delayField.count * MemoryLayout<Float>.stride
          * TissueDelayField.historyCapacity * (options.backend == .metal ? 2 : 1),
        relayTransactionBytes: delayField.count * MemoryLayout<Float>.stride
          * (options.backend == .metal
            ? 1
            : min(substepsPerControl, TissueDelayField.historyCapacity) + 1),
        residencyAllocatedBytes: result.residencyAllocatedBytes,
        storageMode: options.backend == .metal
          ? "private GPU tissue state, scheduler clocks, descriptors, due invocations, relay history, connectome, receptor events, and active indices plus shared committed inputs and explicit inspection staging"
          : "CPU reference arrays with authoritative relay history and root-local relay journal"
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
        ? "MTL4CommandQueue -> reusable MTL4CommandBuffer -> compact_receptor_events -> neural_tissue_step -> device barrier -> schedule_due_modules -> atomic host generation publication"
        : "Swift FP32 CPU oracle"
    )
  }

  private static func runCPU(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    structure: TissueStructure,
    delayField: TissueDelayField,
    connectome: TissueConnectome,
    eventSchedule: TissueEventSchedule,
    randomContext: TissueRandomContext,
    totalSubsteps: Int,
    substepsPerControl: Int
  ) throws -> (
    state: TissueGrid,
    device: String,
    gpuSeconds: Double?,
    rootTransactions: Int,
    residencyAllocatedBytes: UInt64?,
    eventCompactionDispatches: Int?,
    schedulerDispatches: Int?,
    scheduler: SchedulerEvidence?
  ) {
    var runtime = try CPUTissueRuntime(
      initialState: initialState,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField,
      connectome: connectome,
      eventSchedule: eventSchedule,
      randomContext: randomContext
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
    return (runtime.committed, "CPU reference", nil, rootTransactions, nil, nil, nil, nil)
  }

  @available(macOS 26.0, *)
  private static func runMetal(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    structure: TissueStructure,
    delayField: TissueDelayField,
    connectome: TissueConnectome,
    eventSchedule: TissueEventSchedule,
    randomContext: TissueRandomContext,
    totalSubsteps: Int,
    substepsPerControl: Int
  ) throws -> (
    state: TissueGrid,
    device: String,
    gpuSeconds: Double?,
    rootTransactions: Int,
    residencyAllocatedBytes: UInt64?,
    eventCompactionDispatches: Int?,
    schedulerDispatches: Int?,
    scheduler: SchedulerEvidence?
  ) {
    let runtime = try MetalTissueRuntime(
      initialState: initialState,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField,
      connectome: connectome,
      eventSchedule: eventSchedule,
      randomContext: randomContext,
      maxEncodedSubsteps: max(substepsPerControl, 2)
    )
    var completed = 0
    var rootTransactions = 0
    var gpuSeconds = 0.0
    var eventCompactionDispatches = 0
    var schedulerDispatches = 0
    while completed < totalSubsteps {
      let count = min(substepsPerControl, totalSubsteps - completed)
      let submission = try runtime.runRootTransaction(
        at: Float(completed) * parameters.timestepMilliseconds,
        acceptedSubsteps: Array(repeating: true, count: count)
      )
      try runtime.commitRootTransaction()
      gpuSeconds += submission.gpuDurationSeconds
      eventCompactionDispatches += submission.eventCompactionDispatches
      schedulerDispatches += submission.schedulerDispatches
      completed += count
      rootTransactions += 1
    }
    let schedulerInspection = try runtime.inspectCommittedScheduler()
    var schedulerOracle = CPUMultiRateScheduler(schedule: runtime.brainSchedule)
    var schedulerOracleCompleted = 0
    let schedulerTimestepMicroseconds = UInt64(
      (parameters.timestepMilliseconds * 1_000).rounded()
    )
    while schedulerOracleCompleted < totalSubsteps {
      let count = min(
        substepsPerControl,
        totalSubsteps - schedulerOracleCompleted
      )
      schedulerOracleCompleted += count
      _ = try schedulerOracle.advance(
        to: BrainTimestamp(
          microseconds: UInt64(schedulerOracleCompleted)
            * schedulerTimestepMicroseconds
        )
      )
    }
    let schedulerEvidence = SchedulerEvidence(
      abiVersion: BrainModuleSchedule.abiVersion,
      scheduleFingerprint: runtime.brainSchedule.fingerprintHex,
      moduleCount: runtime.brainSchedule.modules.count,
      descriptorBytes: runtime.schedulerDescriptorByteCount,
      clockGenerationCount: 2,
      clockBytes: runtime.schedulerClockByteCount * 2,
      sharedEventCapacityBytes: runtime.schedulerEventCapacityByteCount,
      sharedUniformBytes: runtime.schedulerUniformByteCount,
      privateInvocationCapacityBytes: runtime.schedulerInvocationCapacityByteCount,
      privateResultBytes: runtime.schedulerResultByteCount,
      maximumInputEvents: runtime.maxSchedulerEvents,
      maximumInvocations: runtime.maxSchedulerInvocations,
      committedTimeMicroseconds: schedulerInspection.snapshot.committedTime.rawValue,
      committedGeneration: schedulerInspection.snapshot.generation,
      finalRootInvocationCount: schedulerInspection.invocations.count,
      finalSnapshotHash: schedulerInspection.snapshot.stableHash(),
      cpuReferenceExact: schedulerInspection.snapshot == schedulerOracle.snapshot,
      status: schedulerInspection.status,
      execution:
        "one Metal schedule_due_modules dispatch per root on the tissue command encoder; private shadow clocks publish only with tissue commit",
      interpretation:
        "eight-module runtime-foundation schedule; due selection is live, regional module operators are not yet dispatched"
    )
    return (
      try runtime.snapshotCommitted(),
      runtime.deviceName,
      gpuSeconds,
      rootTransactions,
      runtime.residencyAllocatedBytes,
      eventCompactionDispatches,
      schedulerDispatches,
      schedulerEvidence
    )
  }

  private static func rollbackEvidence(
    backend: Backend,
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    structure: TissueStructure,
    delayField: TissueDelayField,
    connectome: TissueConnectome,
    eventSchedule: TissueEventSchedule,
    randomContext: TissueRandomContext
  ) throws -> (retry: Bool, abort: Bool) {
    let followUpSteps = min(
      max(
        max(
          delayField.maximumConfiguredDelaySteps,
          connectome.maximumProjectionDelaySteps
        ) + 2,
        2
      ),
      TissueDelayField.historyCapacity
    )
    let followUp = Array(repeating: true, count: followUpSteps)
    let rollbackStartMilliseconds = eventSchedule.events.first?.startMilliseconds ?? 0
    let rollbackFollowUpMilliseconds =
      rollbackStartMilliseconds + parameters.timestepMilliseconds
    switch backend {
    case .cpu:
      var direct = try CPUTissueRuntime(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        structure: structure,
        delayField: delayField,
        connectome: connectome,
        eventSchedule: eventSchedule,
        randomContext: randomContext
      )
      var retried = direct
      var aborted = direct
      var abortBaseline = direct
      try direct.runRootTransaction(
        at: rollbackStartMilliseconds,
        acceptedSubsteps: [true]
      )
      try retried.runRootTransaction(
        at: rollbackStartMilliseconds,
        acceptedSubsteps: [false, true]
      )
      try aborted.runRootTransaction(
        at: rollbackStartMilliseconds,
        acceptedSubsteps: [true],
        commit: false
      )
      try direct.runRootTransaction(
        at: rollbackFollowUpMilliseconds,
        acceptedSubsteps: followUp
      )
      try retried.runRootTransaction(
        at: rollbackFollowUpMilliseconds,
        acceptedSubsteps: followUp
      )
      try aborted.runRootTransaction(
        at: rollbackStartMilliseconds,
        acceptedSubsteps: followUp
      )
      try abortBaseline.runRootTransaction(
        at: rollbackStartMilliseconds,
        acceptedSubsteps: followUp
      )
      return (
        direct.committed.stableHash() == retried.committed.stableHash()
          && direct.committedHistoryHash() == retried.committedHistoryHash(),
        aborted.committed.stableHash() == abortBaseline.committed.stableHash()
          && aborted.committedHistoryHash() == abortBaseline.committedHistoryHash()
      )
    case .metal:
      guard #available(macOS 26.0, *) else {
        throw CLIError("Metal rollback evidence requires macOS 26 or later")
      }
      let direct = try MetalTissueRuntime(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        structure: structure,
        delayField: delayField,
        connectome: connectome,
        eventSchedule: eventSchedule,
        randomContext: randomContext,
        maxEncodedSubsteps: max(followUpSteps, 2)
      )
      let retried = try MetalTissueRuntime(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        structure: structure,
        delayField: delayField,
        connectome: connectome,
        eventSchedule: eventSchedule,
        randomContext: randomContext,
        maxEncodedSubsteps: max(followUpSteps, 2)
      )
      let aborted = try MetalTissueRuntime(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        structure: structure,
        delayField: delayField,
        connectome: connectome,
        eventSchedule: eventSchedule,
        randomContext: randomContext,
        maxEncodedSubsteps: max(followUpSteps, 2)
      )
      let abortBaseline = try MetalTissueRuntime(
        initialState: initialState,
        parameters: parameters,
        stimulus: stimulus,
        structure: structure,
        delayField: delayField,
        connectome: connectome,
        eventSchedule: eventSchedule,
        randomContext: randomContext,
        maxEncodedSubsteps: max(followUpSteps, 2)
      )
      _ = try direct.runRootTransaction(
        at: rollbackStartMilliseconds,
        acceptedSubsteps: [true]
      )
      try direct.commitRootTransaction()
      _ = try retried.runRootTransaction(
        at: rollbackStartMilliseconds,
        acceptedSubsteps: [false, true]
      )
      try retried.commitRootTransaction()
      _ = try aborted.runRootTransaction(
        at: rollbackStartMilliseconds,
        acceptedSubsteps: [true]
      )
      try aborted.abortRootTransaction()
      for runtime in [direct, retried] {
        _ = try runtime.runRootTransaction(
          at: rollbackFollowUpMilliseconds,
          acceptedSubsteps: followUp
        )
        try runtime.commitRootTransaction()
      }
      for runtime in [aborted, abortBaseline] {
        _ = try runtime.runRootTransaction(
          at: rollbackStartMilliseconds,
          acceptedSubsteps: followUp
        )
        try runtime.commitRootTransaction()
      }
      return (
        try direct.snapshotCommitted().stableHash()
          == retried.snapshotCommitted().stableHash()
          && (try direct.snapshotCommittedScheduler())
            == (try retried.snapshotCommittedScheduler()),
        try aborted.snapshotCommitted().stableHash()
          == abortBaseline.snapshotCommitted().stableHash()
          && (try aborted.snapshotCommittedScheduler())
            == (try abortBaseline.snapshotCommittedScheduler())
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
