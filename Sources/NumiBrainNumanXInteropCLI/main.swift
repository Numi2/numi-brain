import Darwin
import Foundation
import NumiBrainABI
import NumiBrainCore
import NumiBrainMetal

@available(macOS 26.0, *)
private final class NumanXMyoSimBridge {
  private typealias CreateFunction =
    @convention(c) (
      UnsafePointer<CChar>?, UnsafePointer<CChar>?, UInt32,
      UnsafeMutablePointer<CChar>?, UInt
    ) -> UnsafeMutableRawPointer?
  private typealias DestroyFunction = @convention(c) (UnsafeMutableRawPointer?) -> Void
  private typealias StatusFunction = @convention(c) (UnsafeMutableRawPointer?) -> UInt32
  private typealias VoidFunction = @convention(c) (UnsafeMutableRawPointer?) -> Void
  private typealias CandidateFunction =
    @convention(c) (
      UnsafeMutableRawPointer?, UnsafeRawPointer?, UInt64, UInt32, UInt32,
      UInt32, UInt64, UInt64
    ) -> UInt32
  private typealias UInt64Function = @convention(c) (UnsafeMutableRawPointer?) -> UInt64
  private typealias UInt32Function = @convention(c) (UnsafeMutableRawPointer?) -> UInt32
  private typealias IndexedUInt32Function =
    @convention(c) (UnsafeMutableRawPointer?, UInt32) -> UInt32
  private typealias IndexedEndpointUInt32Function =
    @convention(c) (UnsafeMutableRawPointer?, UInt32, UInt32) -> UInt32
  private typealias IndexedEndpointAxisFloatFunction =
    @convention(c) (UnsafeMutableRawPointer?, UInt32, UInt32, UInt32) -> Float
  private typealias CStringFunction =
    @convention(c) (UnsafeMutableRawPointer?) -> UnsafePointer<CChar>?
  private typealias FloatFunction = @convention(c) (UnsafeMutableRawPointer?) -> Float
  private typealias DoubleFunction = @convention(c) (UnsafeMutableRawPointer?) -> Double

  private let library: UnsafeMutableRawPointer
  private let bridge: UnsafeMutableRawPointer
  private let destroyFunction: DestroyFunction
  private let lastErrorFunction: CStringFunction
  private let muscleCountFunction: UInt32Function
  private let muscleIdentifierFunction: IndexedUInt32Function
  private let bodyCountFunction: UInt32Function
  private let attachmentRouteNodeCountFunction: IndexedUInt32Function
  private let attachmentBodyIdentifierFunction: IndexedEndpointUInt32Function
  private let attachmentLocalCoordinateFunction: IndexedEndpointAxisFloatFunction
  private let attachmentCatalogFingerprintFunction: UInt64Function
  private let beginRootFunction: StatusFunction
  private let runCandidateFunction: CandidateFunction
  private let acceptCandidateFunction: StatusFunction
  private let rejectCandidateFunction: VoidFunction
  private let commitRootFunction: StatusFunction
  private let abortRootFunction: VoidFunction
  private let pendingFingerprintFunction: UInt64Function
  private let pendingBorrowedAddressFunction: UInt64Function
  private let pendingMaximumExcitationFunction: FloatFunction
  private let pendingMaximumActivationFunction: FloatFunction
  private let pendingMaximumCommandedMuscleForceFunction: FloatFunction
  private let pendingMaximumCommandedForceMuscleIdentifierFunction: UInt32Function
  private let pendingMaximumForceFunction: FloatFunction
  private let pendingMaximumMuscleForceFunction: FloatFunction
  private let pendingMaximumForceMuscleIdentifierFunction: UInt32Function
  private let pendingMaximumVelocityDeltaFunction: DoubleFunction
  private let pendingMaximumConfigurationDeltaFunction: DoubleFunction
  private let committedFingerprintFunction: UInt64Function
  private let committedGenerationFunction: UInt64Function
  let muscleIdentifiers: [UInt32]
  let attachmentCatalog: NumanXMuscleAttachmentCatalog

  init(
    libraryPath: String,
    rigidPath: String,
    musclePath: String,
    muscleCount: UInt32
  ) throws {
    guard let library = dlopen(libraryPath, RTLD_NOW | RTLD_LOCAL) else {
      throw NSError(
        domain: "NumiBrainNumanXInterop",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: String(cString: dlerror())]
      )
    }
    self.library = library
    let create: CreateFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_create", from: library
    )
    destroyFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_destroy", from: library
    )
    lastErrorFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_last_error", from: library
    )
    muscleCountFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_muscle_count", from: library
    )
    muscleIdentifierFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_muscle_identifier", from: library
    )
    bodyCountFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_body_count", from: library
    )
    attachmentRouteNodeCountFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_attachment_route_node_count", from: library
    )
    attachmentBodyIdentifierFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_attachment_body_identifier", from: library
    )
    attachmentLocalCoordinateFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_attachment_local_coordinate", from: library
    )
    attachmentCatalogFingerprintFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_attachment_catalog_fingerprint", from: library
    )
    beginRootFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_begin_root", from: library
    )
    runCandidateFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_run_candidate", from: library
    )
    acceptCandidateFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_accept_candidate", from: library
    )
    rejectCandidateFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_reject_candidate", from: library
    )
    commitRootFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_commit_root", from: library
    )
    abortRootFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_abort_root", from: library
    )
    pendingFingerprintFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_pending_fingerprint", from: library
    )
    pendingBorrowedAddressFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_pending_borrowed_gpu_address", from: library
    )
    pendingMaximumExcitationFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_pending_maximum_excitation", from: library
    )
    pendingMaximumActivationFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_pending_maximum_activation", from: library
    )
    pendingMaximumCommandedMuscleForceFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_pending_maximum_commanded_muscle_force", from: library
    )
    pendingMaximumCommandedForceMuscleIdentifierFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_pending_maximum_commanded_force_muscle_identifier",
      from: library
    )
    pendingMaximumForceFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_pending_maximum_force", from: library
    )
    pendingMaximumMuscleForceFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_pending_maximum_muscle_force", from: library
    )
    pendingMaximumForceMuscleIdentifierFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_pending_maximum_force_muscle_identifier",
      from: library
    )
    pendingMaximumVelocityDeltaFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_pending_maximum_velocity_delta", from: library
    )
    pendingMaximumConfigurationDeltaFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_pending_maximum_configuration_delta", from: library
    )
    committedFingerprintFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_committed_fingerprint", from: library
    )
    committedGenerationFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_committed_generation", from: library
    )

    var error = [CChar](repeating: 0, count: 512)
    let created = rigidPath.withCString { rigid in
      musclePath.withCString { muscles in
        error.withUnsafeMutableBufferPointer { errorBuffer in
          create(
            rigid,
            muscles,
            muscleCount,
            errorBuffer.baseAddress,
            UInt(errorBuffer.count)
          )
        }
      }
    }
    guard let created else {
      dlclose(library)
      throw NSError(
        domain: "NumiBrainNumanXInterop",
        code: 2,
        userInfo: [
          NSLocalizedDescriptionKey: error.withUnsafeBufferPointer {
            String(cString: $0.baseAddress!)
          }
        ]
      )
    }
    bridge = created
    let loadedMuscleCount = muscleCountFunction(created)
    var loadedMuscleIdentifiers = [UInt32]()
    loadedMuscleIdentifiers.reserveCapacity(Int(loadedMuscleCount))
    for muscleIndex in 0..<loadedMuscleCount {
      let identifier = muscleIdentifierFunction(created, muscleIndex)
      guard identifier != UInt32.max else {
        destroyFunction(created)
        dlclose(library)
        throw NSError(
          domain: "NumiBrainNumanXInterop",
          code: 9,
          userInfo: [NSLocalizedDescriptionKey: "NumanX muscle catalog is invalid"]
        )
      }
      loadedMuscleIdentifiers.append(identifier)
    }
    guard loadedMuscleCount > 0,
      muscleCount == 0 || loadedMuscleCount == muscleCount
    else {
      destroyFunction(created)
      dlclose(library)
      throw NSError(
        domain: "NumiBrainNumanXInterop",
        code: 10,
        userInfo: [NSLocalizedDescriptionKey: "NumanX muscle catalog count drift"]
      )
    }
    muscleIdentifiers = loadedMuscleIdentifiers
    do {
      let bodyCount = bodyCountFunction(created)
      var attachments = [NumanXMuscleAttachment]()
      attachments.reserveCapacity(Int(loadedMuscleCount))
      for muscleIndex in 0..<loadedMuscleCount {
        let firstPoint = try NumanXBodyLocalPoint(
          x: attachmentLocalCoordinateFunction(created, muscleIndex, 0, 0),
          y: attachmentLocalCoordinateFunction(created, muscleIndex, 0, 1),
          z: attachmentLocalCoordinateFunction(created, muscleIndex, 0, 2)
        )
        let terminalPoint = try NumanXBodyLocalPoint(
          x: attachmentLocalCoordinateFunction(created, muscleIndex, 1, 0),
          y: attachmentLocalCoordinateFunction(created, muscleIndex, 1, 1),
          z: attachmentLocalCoordinateFunction(created, muscleIndex, 1, 2)
        )
        attachments.append(
          try NumanXMuscleAttachment(
            muscleIdentifier: loadedMuscleIdentifiers[Int(muscleIndex)],
            firstBodyIdentifier: attachmentBodyIdentifierFunction(
              created, muscleIndex, 0
            ),
            terminalBodyIdentifier: attachmentBodyIdentifierFunction(
              created, muscleIndex, 1
            ),
            routeNodeCount: attachmentRouteNodeCountFunction(created, muscleIndex),
            firstLocalPoint: firstPoint,
            terminalLocalPoint: terminalPoint
          )
        )
      }
      let catalog = try NumanXMuscleAttachmentCatalog(
        bodyCount: bodyCount,
        attachments: attachments
      )
      guard catalog.fingerprint == attachmentCatalogFingerprintFunction(created) else {
        throw NSError(
          domain: "NumiBrainNumanXInterop",
          code: 11,
          userInfo: [
            NSLocalizedDescriptionKey: "NumanX muscle attachment catalog identity drift"
          ]
        )
      }
      attachmentCatalog = catalog
    } catch {
      destroyFunction(created)
      dlclose(library)
      throw error
    }
  }

  deinit {
    destroyFunction(bridge)
    dlclose(library)
  }

  func beginRoot() throws {
    try requireSuccess(beginRootFunction(bridge), "NumanX root begin")
  }

  func runCandidate(
    lease: MetalTissueRuntime.NumanXMotorBufferLease,
    packet: NumanXMotorCandidate,
    durationMicroseconds: UInt32
  ) throws -> (
    fingerprint: UInt64,
    excitation: Float,
    activation: Float,
    commandedMuscleForce: Float,
    commandedMuscleIdentifier: UInt32,
    force: Float,
    muscleForce: Float,
    muscleIdentifier: UInt32,
    velocityDelta: Double,
    configurationDelta: Double
  ) {
    let status = runCandidateFunction(
      bridge,
      UnsafeRawPointer(lease.excitationMetalBufferObject),
      packet.muscleExcitationGPUAddress,
      packet.muscleCount,
      packet.muscleExcitationByteCount,
      durationMicroseconds,
      packet.transactionFingerprint,
      packet.substepFingerprint
    )
    try requireSuccess(status, "NumanX MyoSim candidate")
    let borrowedAddress = pendingBorrowedAddressFunction(bridge)
    guard borrowedAddress == packet.muscleExcitationGPUAddress else {
      rejectCandidateFunction(bridge)
      throw NSError(
        domain: "NumiBrainNumanXInterop",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "NumanX borrowed a different GPU allocation"]
      )
    }
    let fingerprint = pendingFingerprintFunction(bridge)
    guard fingerprint != 0 else {
      rejectCandidateFunction(bridge)
      throw NSError(
        domain: "NumiBrainNumanXInterop",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "NumanX candidate has no physical identity"]
      )
    }
    return (
      fingerprint,
      pendingMaximumExcitationFunction(bridge),
      pendingMaximumActivationFunction(bridge),
      pendingMaximumCommandedMuscleForceFunction(bridge),
      pendingMaximumCommandedForceMuscleIdentifierFunction(bridge),
      pendingMaximumForceFunction(bridge),
      pendingMaximumMuscleForceFunction(bridge),
      pendingMaximumForceMuscleIdentifierFunction(bridge),
      pendingMaximumVelocityDeltaFunction(bridge),
      pendingMaximumConfigurationDeltaFunction(bridge)
    )
  }

  func acceptCandidate() throws {
    try requireSuccess(acceptCandidateFunction(bridge), "NumanX candidate acceptance")
  }

  func rejectCandidate() {
    rejectCandidateFunction(bridge)
  }

  func commitRoot() throws {
    try requireSuccess(commitRootFunction(bridge), "NumanX root commit")
  }

  func abortRoot() {
    abortRootFunction(bridge)
  }

  var committedFingerprint: UInt64 { committedFingerprintFunction(bridge) }
  var committedGeneration: UInt64 { committedGenerationFunction(bridge) }

  private func requireSuccess(_ status: UInt32, _ operation: String) throws {
    guard status == 0 else {
      let detail = lastErrorFunction(bridge).map(String.init(cString:)) ?? "unknown failure"
      throw NSError(
        domain: "NumiBrainNumanXInterop",
        code: Int(status),
        userInfo: [
          NSLocalizedDescriptionKey:
            "\(operation) failed with status \(status): \(detail)"
        ]
      )
    }
  }

  private static func symbol<T>(
    _ name: String,
    from library: UnsafeMutableRawPointer
  ) throws -> T {
    guard let address = dlsym(library, name) else {
      throw NSError(
        domain: "NumiBrainNumanXInterop",
        code: 5,
        userInfo: [NSLocalizedDescriptionKey: "missing bridge symbol \(name)"]
      )
    }
    return unsafeBitCast(address, to: T.self)
  }
}

@available(macOS 26.0, *)
private func run() throws {
  guard CommandLine.arguments.count == 4 else {
    throw NSError(
      domain: "NumiBrainNumanXInterop",
      code: 64,
      userInfo: [
        NSLocalizedDescriptionKey:
          "usage: numi-brain-numanx-interop <bridge.dylib> <body.nhrigid> <muscles.nhmyo>"
      ]
    )
  }
  let parameters = TissueParameters.corticalSheetV0
  let initial = try CPUTissueDynamics.makeRestingGrid(
    width: 8,
    height: 8,
    parameters: parameters
  )
  let bridge = try NumanXMyoSimBridge(
    libraryPath: CommandLine.arguments[1],
    rigidPath: CommandLine.arguments[2],
    musclePath: CommandLine.arguments[3],
    muscleCount: 0
  )
  let motorProfile = try ProtectiveMotorProfile.runtimeFoundationFixture(
    muscleIdentifiers: bridge.muscleIdentifiers
  )
  try bridge.attachmentCatalog.validate(profile: motorProfile)
  let runtime = try MetalTissueRuntime(
    initialState: initial,
    parameters: parameters,
    stimulus: .none,
    randomContext: TissueRandomContext(
      seed: 0x4e55_4d49,
      environmentIdentifier: 7,
      episodeIdentifier: 23
    ),
    protectiveMotorProfile: motorProfile,
    numanXMuscleAttachmentCatalog: bridge.attachmentCatalog,
    schedulerEnvironmentIdentifier: 7,
    maxEncodedSubsteps: 3
  )
  let muscleLoadTransducer = try MuscleLoadReceptorTransducer(overloadThreshold: 1)
  try bridge.beginRoot()
  var completed = false
  defer {
    if !completed {
      bridge.abortRoot()
      try? runtime.abortInteractiveJointControl()
    }
  }

  let token = try runtime.beginInteractiveJointControl(
    controlStepIdentifier: 1,
    basePhysicsGeneration: 100,
    committedTimestamp: BrainTimestamp(microseconds: 0),
    targetTimestamp: BrainTimestamp(microseconds: 3)
  )
  let rejectedFast = try runtime.advanceFastSystems(candidateDurationMicroseconds: 1)
  let rejectedPacket = try NumanXMotorCandidate(
    transaction: token,
    fastSystems: rejectedFast
  )
  let rejectedLease = try runtime.borrowNumanXMotorBuffers(for: rejectedFast)
  let rejectedPhysical = try bridge.runCandidate(
    lease: rejectedLease,
    packet: rejectedPacket,
    durationMicroseconds: 1
  )
  bridge.rejectCandidate()
  try runtime.rejectPhysicsSubstep(rejectedFast.substep)

  var physicalFingerprints = [UInt64]()
  var maximumExcitations = [Float]()
  var maximumActivations = [Float]()
  var maximumCommandedMuscleForces = [Float]()
  var maximumCommandedForceMuscleIdentifiers = [UInt32]()
  var maximumForces = [Float]()
  var maximumMuscleForces = [Float]()
  var maximumForceMuscleIdentifiers = [UInt32]()
  var maximumVelocityDeltas = [Double]()
  var maximumConfigurationDeltas = [Double]()
  var retrySubstepFingerprint: UInt64 = 0
  var retryRandomCounterGeneration: UInt64 = 0
  var transducedMyoSimEventCount = 0
  for candidateIndex in 0..<3 {
    let fast = try runtime.advanceFastSystems(candidateDurationMicroseconds: 1)
    let packet = try NumanXMotorCandidate(transaction: token, fastSystems: fast)
    let lease = try runtime.borrowNumanXMotorBuffers(for: fast)
    let physical = try bridge.runCandidate(
      lease: lease,
      packet: packet,
      durationMicroseconds: 1
    )
    if candidateIndex == 0 {
      retrySubstepFingerprint = packet.substepFingerprint
      retryRandomCounterGeneration = packet.randomCounterGeneration
      guard packet.substepFingerprint != rejectedPacket.substepFingerprint,
        packet.randomCounterGeneration == rejectedPacket.randomCounterGeneration,
        physical.fingerprint == rejectedPhysical.fingerprint,
        physical.excitation == rejectedPhysical.excitation,
        physical.activation == rejectedPhysical.activation,
        physical.commandedMuscleForce == rejectedPhysical.commandedMuscleForce,
        physical.commandedMuscleIdentifier == rejectedPhysical.commandedMuscleIdentifier,
        physical.force == rejectedPhysical.force,
        physical.muscleForce == rejectedPhysical.muscleForce,
        physical.muscleIdentifier == rejectedPhysical.muscleIdentifier,
        physical.velocityDelta == rejectedPhysical.velocityDelta,
        physical.configurationDelta == rejectedPhysical.configurationDelta
      else {
        bridge.rejectCandidate()
        throw NSError(
          domain: "NumiBrainNumanXInterop",
          code: 7,
          userInfo: [
            NSLocalizedDescriptionKey:
              "rejected physical candidate did not replay from the same causal state"
          ]
        )
      }
    }
    physicalFingerprints.append(physical.fingerprint)
    maximumExcitations.append(physical.excitation)
    maximumActivations.append(physical.activation)
    maximumCommandedMuscleForces.append(physical.commandedMuscleForce)
    maximumCommandedForceMuscleIdentifiers.append(physical.commandedMuscleIdentifier)
    maximumForces.append(physical.force)
    maximumMuscleForces.append(physical.muscleForce)
    maximumForceMuscleIdentifiers.append(physical.muscleIdentifier)
    maximumVelocityDeltas.append(physical.velocityDelta)
    maximumConfigurationDeltas.append(physical.configurationDelta)
    let accepted = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: fast.substep,
      physicsStateFingerprint: physical.fingerprint,
      physicsGeneration: 101 + UInt64(candidateIndex)
    )
    let localizedObservations: [LocalizedMuscleLoadReceptorObservation]
    if candidateIndex == 0 {
      localizedObservations =
        try muscleLoadTransducer.transduceLocalized(
          maximumAbsoluteMuscleForce: physical.muscleForce,
          acceptedPhysicsState: accepted,
          muscleIdentifier: physical.muscleIdentifier,
          attachmentCatalog: bridge.attachmentCatalog
        ).map { [$0] } ?? []
      transducedMyoSimEventCount += localizedObservations.count
    } else {
      localizedObservations = []
    }
    let events = localizedObservations.map(\.event)
    do {
      try runtime.acceptPhysicsSubstep(
        accepted,
        for: fast.substep,
        receptorEvents: events,
        localizedMuscleLoadObservations: localizedObservations
      )
      try bridge.acceptCandidate()
    } catch {
      bridge.rejectCandidate()
      throw error
    }
  }
  _ = try runtime.finishInteractiveJointControl()
  let brainCommit = try runtime.commitJointRootTransaction()
  try bridge.commitRoot()
  completed = true

  let maximumForceAttachments = maximumForceMuscleIdentifiers.compactMap {
    bridge.attachmentCatalog.attachment(forMuscleIdentifier: $0)
  }
  let maximumCommandedForceAttachments =
    maximumCommandedForceMuscleIdentifiers.compactMap {
      bridge.attachmentCatalog.attachment(forMuscleIdentifier: $0)
    }

  guard let committedBodyLoadFrame = runtime.latestCommittedBodyLoadFrame,
    bridge.committedGeneration == 3,
    bridge.committedFingerprint == physicalFingerprints.last,
    transducedMyoSimEventCount == 1,
    maximumExcitations[1] > maximumExcitations[0],
    maximumActivations[0] > 0,
    maximumActivations[1] > maximumActivations[0],
    maximumActivations[2] > maximumActivations[1],
    maximumCommandedMuscleForces[2] != maximumCommandedMuscleForces[0],
    maximumCommandedForceMuscleIdentifiers.allSatisfy(bridge.muscleIdentifiers.contains),
    maximumForces[2] != maximumForces[0],
    maximumMuscleForces.allSatisfy({ $0 > 0 }),
    maximumForceMuscleIdentifiers.allSatisfy(bridge.muscleIdentifiers.contains),
    maximumForceAttachments.count == maximumForceMuscleIdentifiers.count,
    maximumCommandedForceAttachments.count
      == maximumCommandedForceMuscleIdentifiers.count,
    runtime.latestCommittedMuscleLoadObservations.count == 1,
    runtime.latestCommittedMuscleLoadObservations[0].attachment
      == maximumForceAttachments[0],
    runtime.latestCommittedMuscleLoadObservations[0].maximumAbsoluteMuscleForce
      == maximumMuscleForces[0],
    committedBodyLoadFrame.jointCommitFingerprint == brainCommit.fingerprint,
    committedBodyLoadFrame.attachmentCatalogFingerprint
      == bridge.attachmentCatalog.fingerprint,
    committedBodyLoadFrame.samples.count == 2,
    committedBodyLoadFrame.affectedBodyIdentifiers
      == [
        min(
          maximumForceAttachments[0].firstBodyIdentifier,
          maximumForceAttachments[0].terminalBodyIdentifier
        ),
        max(
          maximumForceAttachments[0].firstBodyIdentifier,
          maximumForceAttachments[0].terminalBodyIdentifier
        ),
      ],
    committedBodyLoadFrame.maximumAbsoluteMuscleForce == maximumMuscleForces[0],
    maximumVelocityDeltas.allSatisfy({ $0 > 0 }),
    maximumConfigurationDeltas.allSatisfy({ $0 > 0 })
  else {
    throw NSError(
      domain: "NumiBrainNumanXInterop",
      code: 6,
      userInfo: [NSLocalizedDescriptionKey: "joint causal response did not survive commit"]
    )
  }

  let record: [String: Any] = [
    "status": "pass",
    "device": runtime.deviceName,
    "brain_commit_fingerprint": brainCommit.fingerprint,
    "brain_generation": brainCommit.brainGeneration,
    "physics_generation": brainCommit.physicsGeneration,
    "numanx_state_fingerprint": bridge.committedFingerprint,
    "numanx_generation": bridge.committedGeneration,
    "candidate_physical_fingerprints": physicalFingerprints,
    "candidate_maximum_excitations": maximumExcitations,
    "candidate_maximum_activations": maximumActivations,
    "candidate_maximum_commanded_muscle_forces": maximumCommandedMuscleForces,
    "candidate_maximum_commanded_force_muscle_identifiers":
      maximumCommandedForceMuscleIdentifiers,
    "candidate_maximum_generalized_forces": maximumForces,
    "candidate_maximum_muscle_forces": maximumMuscleForces,
    "candidate_maximum_force_muscle_identifiers": maximumForceMuscleIdentifiers,
    "candidate_maximum_force_first_body_identifiers":
      maximumForceAttachments.map(\.firstBodyIdentifier),
    "candidate_maximum_force_terminal_body_identifiers":
      maximumForceAttachments.map(\.terminalBodyIdentifier),
    "candidate_maximum_force_route_node_counts":
      maximumForceAttachments.map(\.routeNodeCount),
    "candidate_maximum_commanded_force_first_body_identifiers":
      maximumCommandedForceAttachments.map(\.firstBodyIdentifier),
    "candidate_maximum_commanded_force_terminal_body_identifiers":
      maximumCommandedForceAttachments.map(\.terminalBodyIdentifier),
    "candidate_maximum_commanded_force_route_node_counts":
      maximumCommandedForceAttachments.map(\.routeNodeCount),
    "receptor_attachment_first_local_point": [
      maximumForceAttachments[0].firstLocalPoint.x,
      maximumForceAttachments[0].firstLocalPoint.y,
      maximumForceAttachments[0].firstLocalPoint.z,
    ],
    "receptor_attachment_terminal_local_point": [
      maximumForceAttachments[0].terminalLocalPoint.x,
      maximumForceAttachments[0].terminalLocalPoint.y,
      maximumForceAttachments[0].terminalLocalPoint.z,
    ],
    "candidate_maximum_velocity_deltas": maximumVelocityDeltas,
    "candidate_maximum_configuration_deltas": maximumConfigurationDeltas,
    "rejected_physical_fingerprint": rejectedPhysical.fingerprint,
    "rejected_substep_fingerprint": rejectedPacket.substepFingerprint,
    "retry_substep_fingerprint": retrySubstepFingerprint,
    "rejected_random_counter_generation": rejectedPacket.randomCounterGeneration,
    "retry_random_counter_generation": retryRandomCounterGeneration,
    "rejected_candidate_replayed_exactly": true,
    "actual_borrowed_buffer": true,
    "receptor_interrupt": "muscle-overload",
    "receptor_event_source": "accepted-numanx-myosim-muscle-force",
    "receptor_event_threshold": 1,
    "committed_localized_muscle_load_count":
      runtime.latestCommittedMuscleLoadObservations.count,
    "committed_localized_muscle_load_catalog_fingerprint":
      runtime.latestCommittedMuscleLoadObservations[0].attachmentCatalogFingerprint,
    "committed_body_load_frame_fingerprint": committedBodyLoadFrame.fingerprint,
    "committed_body_load_sample_count": committedBodyLoadFrame.samples.count,
    "committed_body_load_body_identifiers": committedBodyLoadFrame.affectedBodyIdentifiers,
    "committed_body_load_maximum_force": committedBodyLoadFrame.maximumAbsoluteMuscleForce,
    "numanx_muscle_count": bridge.muscleIdentifiers.count,
    "numanx_muscle_identifiers": bridge.muscleIdentifiers,
    "numanx_motor_profile_fingerprint": motorProfile.fingerprint,
    "numanx_body_count": bridge.attachmentCatalog.bodyCount,
    "numanx_attachment_catalog_fingerprint": bridge.attachmentCatalog.fingerprint,
  ]
  let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
  print(String(decoding: data, as: UTF8.self))
}

if #available(macOS 26.0, *) {
  do {
    try run()
  } catch {
    fputs("numi-brain-numanx-interop FAIL: \(error)\n", stderr)
    exit(1)
  }
} else {
  fputs("numi-brain-numanx-interop requires macOS 26\n", stderr)
  exit(1)
}
