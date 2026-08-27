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
  private typealias FloatFunction = @convention(c) (UnsafeMutableRawPointer?) -> Float

  private let library: UnsafeMutableRawPointer
  private let bridge: UnsafeMutableRawPointer
  private let destroyFunction: DestroyFunction
  private let beginRootFunction: StatusFunction
  private let runCandidateFunction: CandidateFunction
  private let acceptCandidateFunction: StatusFunction
  private let rejectCandidateFunction: VoidFunction
  private let commitRootFunction: StatusFunction
  private let abortRootFunction: VoidFunction
  private let pendingFingerprintFunction: UInt64Function
  private let pendingBorrowedAddressFunction: UInt64Function
  private let pendingMaximumExcitationFunction: FloatFunction
  private let pendingMaximumForceFunction: FloatFunction
  private let committedFingerprintFunction: UInt64Function
  private let committedGenerationFunction: UInt64Function

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
    pendingMaximumForceFunction = try Self.symbol(
      "mr_numibrain_myosim_bridge_pending_maximum_force", from: library
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
  ) throws -> (fingerprint: UInt64, excitation: Float, force: Float) {
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
      pendingMaximumForceFunction(bridge)
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
      throw NSError(
        domain: "NumiBrainNumanXInterop",
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "\(operation) failed with status \(status)"]
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
  let runtime = try MetalTissueRuntime(
    initialState: initial,
    parameters: parameters,
    stimulus: .none,
    randomContext: TissueRandomContext(
      seed: 0x4e55_4d49,
      environmentIdentifier: 7,
      episodeIdentifier: 23
    ),
    schedulerEnvironmentIdentifier: 7,
    maxEncodedSubsteps: 3
  )
  let bridge = try NumanXMyoSimBridge(
    libraryPath: CommandLine.arguments[1],
    rigidPath: CommandLine.arguments[2],
    musclePath: CommandLine.arguments[3],
    muscleCount: UInt32(runtime.protectiveMotorProfile.channels.count)
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
  var maximumForces = [Float]()
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
        physical.force == rejectedPhysical.force
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
    maximumForces.append(physical.force)
    let accepted = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: fast.substep,
      physicsStateFingerprint: physical.fingerprint,
      physicsGeneration: 101 + UInt64(candidateIndex)
    )
    let events: [BrainInterruptEvent]
    if candidateIndex == 0 {
      events =
        try muscleLoadTransducer.transduce(
          maximumAbsoluteGeneralizedForce: physical.force,
          acceptedPhysicsState: accepted,
          receptorIdentifier: 0x4d59_4f53
        ).map { [$0] } ?? []
      transducedMyoSimEventCount += events.count
    } else {
      events = []
    }
    do {
      try runtime.acceptPhysicsSubstep(accepted, for: fast.substep, receptorEvents: events)
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

  guard bridge.committedGeneration == 3,
    bridge.committedFingerprint == physicalFingerprints.last,
    transducedMyoSimEventCount == 1,
    maximumExcitations[1] > maximumExcitations[0],
    maximumForces[2] != maximumForces[0]
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
    "candidate_maximum_generalized_forces": maximumForces,
    "rejected_physical_fingerprint": rejectedPhysical.fingerprint,
    "rejected_substep_fingerprint": rejectedPacket.substepFingerprint,
    "retry_substep_fingerprint": retrySubstepFingerprint,
    "rejected_random_counter_generation": rejectedPacket.randomCounterGeneration,
    "retry_random_counter_generation": retryRandomCounterGeneration,
    "rejected_candidate_replayed_exactly": true,
    "actual_borrowed_buffer": true,
    "receptor_interrupt": "muscle-overload",
    "receptor_event_source": "accepted-numanx-myosim-generalized-force",
    "receptor_event_threshold": 1,
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
