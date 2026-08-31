import Darwin
import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore
import NumiBrainMetalBridgeABI

@available(macOS 26.0, *)
@_spi(NumanXInterop)
public enum MetalNumanXBridgeV1Error: Error, CustomStringConvertible {
  case dynamicLibrary(String)
  case invalidABI(String)
  case runtime(UInt32, UInt32)
  case rejected(String)

  public var description: String {
    switch self {
    case .dynamicLibrary(let detail): return detail
    case .invalidABI(let detail): return detail
    case .runtime(let status, let stage):
      return "NumanX native runtime failed with status \(status), stage \(stage)"
    case .rejected(let detail): return detail
    }
  }
}

@available(macOS 26.0, *)
private final class MetalNumanXBridgeV1Symbols: @unchecked Sendable {
  typealias RuntimeCreate = @convention(c) (
    UnsafePointer<mrnx_runtime_config_v1>?,
    UnsafeMutablePointer<mrnx_runtime_info_v1>?
  ) -> UnsafeMutableRawPointer?
  typealias HandleVoid = @convention(c) (UnsafeMutableRawPointer?) -> Void
  typealias RuntimeCopyInfo = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutablePointer<mrnx_runtime_info_v1>?
  ) -> UInt8
  typealias RuntimeBegin = @convention(c) (
    UnsafeMutableRawPointer?, UnsafePointer<mrnx_physical_root_request_v1>?,
    UnsafeMutableRawPointer?, MetalNumanXBridgeV1RootCallback?
  ) -> UInt8
  typealias RuntimeCopySnapshot = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutablePointer<mrnx_aggregate_snapshot_v1>?
  ) -> UInt8
  typealias CopyRoot = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutablePointer<mrnx_root_v1>?
  ) -> UInt8
  typealias CopyWire = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutablePointer<mrnx_wire_lease_v1>?
  ) -> UInt8
  typealias CopyCandidate = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutablePointer<mrnx_candidate_view_v1>?
  ) -> UInt8
  typealias CopyChannel = @convention(c) (
    UnsafeMutableRawPointer?, UInt32,
    UnsafeMutablePointer<mrnx_candidate_channel_v1>?
  ) -> UInt8
  typealias SubmitProposal = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutableRawPointer?,
    UnsafePointer<mrnx_wire_lease_v1>?, UnsafeMutableRawPointer?,
    MetalNumanXBridgeV1ProposalCallback?
  ) -> UInt8
  typealias ReserveWire = @convention(c) (
    UnsafeMutableRawPointer?, UnsafePointer<mrnx_wire_lease_v1>?
  ) -> UInt8
  typealias SubmitApply = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutableRawPointer?,
    UnsafePointer<mrnx_wire_lease_v1>?, UnsafeMutableRawPointer?,
    MetalNumanXBridgeV1ApplyCallback?
  ) -> UInt8
  typealias SubmitTimeoutProposal = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutableRawPointer?,
    UnsafeMutableRawPointer?, MetalNumanXBridgeV1ProposalCallback?
  ) -> UInt8
  typealias SubmitTimeoutApply = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutableRawPointer?,
    UnsafeMutableRawPointer?, MetalNumanXBridgeV1ApplyCallback?
  ) -> UInt8
  typealias ReservePublication = @convention(c) (
    UnsafeMutableRawPointer?, UnsafePointer<mrnx_publication_v1>?
  ) -> UInt8
  typealias ReleaseAccepted = @convention(c) (
    UnsafeMutableRawPointer?, UnsafePointer<mrnx_publication_v1>?,
    UnsafeMutableRawPointer?, MetalNumanXBridgeV1LatchCallback?
  ) -> UInt32
  typealias ReleasePrepared = @convention(c) (UnsafeMutableRawPointer?) -> UInt32

  let library: UnsafeMutableRawPointer
  let runtimeCreate: RuntimeCreate
  let runtimeRetain: HandleVoid
  let runtimeDrop: HandleVoid
  let runtimeCopyInfo: RuntimeCopyInfo
  let runtimeBegin: RuntimeBegin
  let runtimeCopySnapshot: RuntimeCopySnapshot
  let preparedRetain: HandleVoid
  let preparedDrop: HandleVoid
  let candidateRetain: HandleVoid
  let candidateDrop: HandleVoid
  let copyRoot: CopyRoot
  let copyPhysicalGate: CopyWire
  let copyCandidate: CopyCandidate
  let copyChannel: CopyChannel
  let submitProposal: SubmitProposal
  let reserveApplication: ReserveWire
  let submitApply: SubmitApply
  let submitTimeoutProposal: SubmitTimeoutProposal
  let reserveTimeoutApplication: ReserveWire
  let submitTimeoutApply: SubmitTimeoutApply
  let reservePublication: ReservePublication
  let releaseAccepted: ReleaseAccepted
  let releaseRejected: ReleasePrepared
  let quarantineTimeout: @convention(c) (UnsafeMutableRawPointer?) -> UInt8

  init(path: String) throws {
    guard let library = dlopen(path, RTLD_NOW | RTLD_LOCAL) else {
      let detail = dlerror().map { String(cString: $0) }
      throw MetalNumanXBridgeV1Error.dynamicLibrary(
        detail ?? "failed to load MetalRobo"
      )
    }
    self.library = library
    do {
      let abi: @convention(c) () -> UInt32 = try Self.symbol(
        "mrnx_bridge_v1_abi_version", library: library
      )
      guard abi() == UInt32(MRNX_BRIDGE_ABI_V1) else {
        throw MetalNumanXBridgeV1Error.invalidABI(
          "MetalRobo NumanX bridge ABI is not v1"
        )
      }
      runtimeCreate = try Self.symbol("mrnx_bridge_v1_runtime_create", library: library)
      runtimeRetain = try Self.symbol("mrnx_bridge_v1_runtime_retain", library: library)
      runtimeDrop = try Self.symbol("mrnx_bridge_v1_runtime_drop", library: library)
      runtimeCopyInfo = try Self.symbol(
        "mrnx_bridge_v1_runtime_copy_info", library: library
      )
      runtimeBegin = try Self.symbol(
        "mrnx_bridge_v1_runtime_begin_physical_root", library: library
      )
      runtimeCopySnapshot = try Self.symbol(
        "mrnx_bridge_v1_runtime_copy_aggregate_snapshot", library: library
      )
      preparedRetain = try Self.symbol("mrnx_bridge_v1_prepared_retain", library: library)
      preparedDrop = try Self.symbol("mrnx_bridge_v1_prepared_drop", library: library)
      candidateRetain = try Self.symbol("mrnx_bridge_v1_candidate_retain", library: library)
      candidateDrop = try Self.symbol("mrnx_bridge_v1_candidate_drop", library: library)
      copyRoot = try Self.symbol("mrnx_bridge_v1_prepared_copy_root", library: library)
      copyPhysicalGate = try Self.symbol(
        "mrnx_bridge_v1_prepared_copy_physical_gate", library: library
      )
      copyCandidate = try Self.symbol(
        "mrnx_bridge_v1_candidate_copy_view", library: library
      )
      copyChannel = try Self.symbol(
        "mrnx_bridge_v1_candidate_copy_channel", library: library
      )
      submitProposal = try Self.symbol("mrnx_bridge_v1_submit_proposal", library: library)
      reserveApplication = try Self.symbol(
        "mrnx_bridge_v1_reserve_application", library: library
      )
      submitApply = try Self.symbol("mrnx_bridge_v1_submit_apply", library: library)
      submitTimeoutProposal = try Self.symbol(
        "mrnx_bridge_v1_submit_timeout_reject_proposal", library: library
      )
      reserveTimeoutApplication = try Self.symbol(
        "mrnx_bridge_v1_reserve_timeout_reject_application", library: library
      )
      submitTimeoutApply = try Self.symbol(
        "mrnx_bridge_v1_submit_timeout_reject_apply", library: library
      )
      reservePublication = try Self.symbol(
        "mrnx_bridge_v1_reserve_publication", library: library
      )
      releaseAccepted = try Self.symbol("mrnx_bridge_v1_release_accepted", library: library)
      releaseRejected = try Self.symbol("mrnx_bridge_v1_release_rejected", library: library)
      quarantineTimeout = try Self.symbol("mrnx_bridge_v1_quarantine_timeout", library: library)
    } catch {
      dlclose(library)
      throw error
    }
  }

  deinit { dlclose(library) }

  private static func symbol<T>(
    _ name: String, library: UnsafeMutableRawPointer
  ) throws -> T {
    guard let address = dlsym(library, name) else {
      throw MetalNumanXBridgeV1Error.dynamicLibrary(
        "missing MetalRobo bridge symbol \(name)"
      )
    }
    return unsafeBitCast(address, to: T.self)
  }
}

@available(macOS 26.0, *)
private typealias MetalNumanXBridgeV1RootCallback = @convention(c) (
  UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?,
  UnsafePointer<mrnx_completion_v1>?, UnsafePointer<mrnx_root_v1>?
) -> Void
@available(macOS 26.0, *)
private typealias MetalNumanXBridgeV1ProposalCallback = @convention(c) (
  UnsafeMutableRawPointer?, UnsafePointer<mrnx_completion_v1>?,
  UnsafePointer<mrnx_proposal_view_v1>?
) -> Void
@available(macOS 26.0, *)
private typealias MetalNumanXBridgeV1ApplyCallback = @convention(c) (
  UnsafeMutableRawPointer?, UnsafePointer<mrnx_completion_v1>?,
  UnsafePointer<mrnx_applied_view_v1>?
) -> Void
@available(macOS 26.0, *)
private typealias MetalNumanXBridgeV1LatchCallback = @convention(c) (
  UnsafeMutableRawPointer?, UInt64
) -> UInt8

@available(macOS 26.0, *)
private enum MetalNumanXBridgeV1Convert {
  static func buffer(_ raw: UnsafeMutableRawPointer?) throws -> any MTLBuffer {
    guard let raw,
      let value = Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue()
        as? any MTLBuffer
    else {
      throw MetalNumanXBridgeV1Error.invalidABI("bridge range has no MTLBuffer")
    }
    return value
  }

  static func event(_ raw: UnsafeMutableRawPointer?) throws -> any MTLSharedEvent {
    guard let raw,
      let value = Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue()
        as? any MTLSharedEvent
    else {
      throw MetalNumanXBridgeV1Error.invalidABI("bridge point has no MTLSharedEvent")
    }
    return value
  }

  static func point(_ value: mrnx_event_point_v1) throws -> MetalSharedEventPoint {
    guard value.abi_version == UInt32(MRNX_BRIDGE_ABI_V1),
      value.struct_size == MemoryLayout<mrnx_event_point_v1>.stride,
      value.device_registry_id > 0
    else {
      throw MetalNumanXBridgeV1Error.invalidABI("invalid bridge event descriptor")
    }
    return try MetalSharedEventPoint(event: event(value.shared_event), value: value.value)
  }

  static func identity(_ value: mrnx_root_v1) throws
    -> MetalNumanXHumanMatterRootIdentity
  {
    guard value.abi_version == UInt32(MRNX_BRIDGE_ABI_V1),
      value.struct_size == MemoryLayout<mrnx_root_v1>.stride,
      value.owner_wire_abi_version == UInt32(MRNX_OWNER_WIRE_ABI_V4),
      value.environment_count == 1,
      value.q_coordinate_count == UInt32(MRNX_FULL_BODY_NQ),
      value.dof_count == UInt32(MRNX_FULL_BODY_NV), value.reserved0 == 0
    else {
      throw MetalNumanXBridgeV1Error.invalidABI("invalid full-body root descriptor")
    }
    return try MetalNumanXHumanMatterRootIdentity(
      programFingerprint: value.program_fingerprint,
      transactionFingerprint: value.transaction_fingerprint,
      linearizationEpoch: value.linearization_epoch,
      slotGeneration: value.slot_generation,
      transactionSlot: value.transaction_slot,
      environment: value.environment,
      stepIndex: value.step_index,
      controlStep: value.control_step,
      substepIndex: value.substep_index,
      physicsSubstepCount: value.physics_substep_count
    )
  }

  static func range(
    _ value: mrnx_metal_range_v1,
    expectedType: UInt32,
    expectedElementBytes: UInt32
  ) throws -> MetalNumanXHumanIOCandidateRangeLease {
    let buffer = try buffer(value.metal_buffer)
    guard value.abi_version == UInt32(MRNX_BRIDGE_ABI_V1),
      value.struct_size == MemoryLayout<mrnx_metal_range_v1>.stride,
      value.element_type == expectedType,
      value.element_byte_count == expectedElementBytes,
      let offset = Int(exactly: value.byte_offset),
      let count = Int(exactly: value.byte_count)
    else {
      throw MetalNumanXBridgeV1Error.invalidABI("invalid bridge Metal range")
    }
    return try MetalNumanXHumanIOCandidateRangeLease(
      buffer: buffer,
      metalBufferObject: value.metal_buffer!,
      gpuAddress: value.gpu_address,
      byteOffset: offset,
      byteCount: count,
      elementType: value.element_type,
      elementByteCount: value.element_byte_count
    )
  }
}

@available(macOS 26.0, *)
private final class MetalNumanXBridgeV1CandidateOwner: @unchecked Sendable {
  let symbols: MetalNumanXBridgeV1Symbols
  let handle: UnsafeMutableRawPointer

  init(symbols: MetalNumanXBridgeV1Symbols, borrowed: UnsafeMutableRawPointer) {
    self.symbols = symbols
    handle = borrowed
    symbols.candidateRetain(handle)
  }

  deinit { symbols.candidateDrop(handle) }
}

@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalNumanXBridgeV1PreparedRoot: @unchecked Sendable {
  public let identity: MetalNumanXHumanMatterRootIdentity
  public let physicalPreparedPoint: MetalSharedEventPoint
  public let acceptedPhysicsGate: MetalAcceptedPhysicsGateLease
  public let sensorCandidate: MetalNumanXPendingSensorCandidateLease

  private let symbols: MetalNumanXBridgeV1Symbols
  private let handle: UnsafeMutableRawPointer
  private let candidateOwner: MetalNumanXBridgeV1CandidateOwner
  private let commandQueue: any MTLCommandQueue

  fileprivate init(
    symbols: MetalNumanXBridgeV1Symbols,
    device: any MTLDevice,
    prepared: UnsafeMutableRawPointer,
    candidate: UnsafeMutableRawPointer
  ) throws {
    self.symbols = symbols
    handle = prepared
    symbols.preparedRetain(handle)
    candidateOwner = MetalNumanXBridgeV1CandidateOwner(
      symbols: symbols, borrowed: candidate
    )
    guard let commandQueue = device.makeCommandQueue() else {
      symbols.preparedDrop(handle)
      throw MetalNumanXBridgeV1Error.rejected("failed to create owner phase queue")
    }
    self.commandQueue = commandQueue
    do {
      var root = mrnx_root_v1()
      var gate = mrnx_wire_lease_v1()
      var candidateView = mrnx_candidate_view_v1()
      root.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
      root.struct_size = UInt32(MemoryLayout<mrnx_root_v1>.stride)
      gate.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
      gate.struct_size = UInt32(MemoryLayout<mrnx_wire_lease_v1>.stride)
      candidateView.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
      candidateView.struct_size = UInt32(
        MemoryLayout<mrnx_candidate_view_v1>.stride
      )
      guard symbols.copyRoot(handle, &root) != 0 else {
        throw MetalNumanXBridgeV1Error.invalidABI(
          "prepared root omitted its exact root identity"
        )
      }
      guard symbols.copyPhysicalGate(handle, &gate) != 0 else {
        throw MetalNumanXBridgeV1Error.invalidABI(
          "prepared root omitted its exact physical gate"
        )
      }
      guard symbols.copyCandidate(candidateOwner.handle, &candidateView) != 0,
        candidateView.channel_count == 2
      else {
        throw MetalNumanXBridgeV1Error.invalidABI(
          "prepared root omitted its exact HumanIO view"
        )
      }
      let identity = try MetalNumanXBridgeV1Convert.identity(root)
      guard gate.root.transaction_fingerprint == root.transaction_fingerprint,
        gate.record.byte_count == UInt64(MetalAcceptedPhysicsGateLease.byteCount),
        gate.record.element_type == UInt32(MRNX_ELEMENT_RAW_BYTES_V1.rawValue),
        gate.record.element_byte_count == 1,
        let gateOffset = Int(exactly: gate.record.byte_offset)
      else {
        throw MetalNumanXBridgeV1Error.invalidABI("invalid physical gate lease")
      }
      let gateBuffer = try MetalNumanXBridgeV1Convert.buffer(gate.record.metal_buffer)
      let physicalPoint = try MetalNumanXBridgeV1Convert.point(gate.ready)
      let key = try MetalNumanXHumanIOCandidateKey(
        transactionFingerprint: candidateView.key.transaction_fingerprint,
        programFingerprint: candidateView.key.program_fingerprint,
        sensorFingerprint: candidateView.key.sensor_fingerprint,
        transactionInstanceFingerprint:
          candidateView.key.transaction_instance_fingerprint,
        sensorGeneration: candidateView.key.sensor_generation,
        commandBufferIdentity: candidateView.key.command_buffer_identity
      )
      guard key.fingerprint == candidateView.key.fingerprint else {
        throw MetalNumanXBridgeV1Error.invalidABI("HumanIO candidate key drifted")
      }
      var sensorChannels: [MetalNumanXHumanIOSensorCandidateChannel] = []
      sensorChannels.reserveCapacity(Int(candidateView.channel_count))
      for channelIndex in 0..<candidateView.channel_count {
        var channel = mrnx_candidate_channel_v1()
        channel.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
        channel.struct_size = UInt32(
          MemoryLayout<mrnx_candidate_channel_v1>.stride
        )
        guard symbols.copyChannel(
          candidateOwner.handle, channelIndex, &channel) != 0,
          channel.flags & 1 != 0,
          let modality = SensoryModality(rawValue: UInt16(channel.modality)),
          modality == .proprioception || modality == .interoception
        else {
          throw MetalNumanXBridgeV1Error.invalidABI(
            "prepared root omitted a canonical HumanIO sensor channel"
          )
        }
        let values = try MetalNumanXBridgeV1Convert.range(
          channel.values,
          expectedType: UInt32(MRNX_ELEMENT_FLOAT32_V1.rawValue),
          expectedElementBytes: UInt32(MemoryLayout<Float>.stride)
        )
        let validity = try MetalNumanXBridgeV1Convert.range(
          channel.validity,
          expectedType: UInt32(MRNX_ELEMENT_UINT32_V1.rawValue),
          expectedElementBytes: UInt32(MemoryLayout<UInt32>.stride)
        )
        sensorChannels.append(
          try MetalNumanXHumanIOSensorCandidateChannel(
            modality: modality,
            receptorTimestamp: BrainTimestamp(
              microseconds: channel.receptor_timestamp_microseconds
            ),
            receptorCount: channel.receptor_count,
            featureDimension: channel.feature_dimension,
            values: values,
            validity: validity
          )
        )
      }
      guard Set(sensorChannels.map(\.modality)) ==
        Set([.proprioception, .interoception])
      else {
        throw MetalNumanXBridgeV1Error.invalidABI(
          "prepared root HumanIO modality set is incomplete"
        )
      }
      let pendingView = try MetalNumanXHumanIOPendingCandidateView(
        abiVersion: candidateView.abi_version,
        transactionFingerprint: candidateView.key.transaction_fingerprint,
        acceptedBrainGeneration: candidateView.accepted_brain_generation,
        sensorGeneration: candidateView.key.sensor_generation,
        humanIOProgramFingerprint: candidateView.key.program_fingerprint,
        sensorFingerprint: candidateView.key.sensor_fingerprint,
        transactionInstanceFingerprint:
          candidateView.key.transaction_instance_fingerprint,
        candidateKey: key,
        candidateKeyFingerprint: candidateView.key.fingerprint,
        candidatePublicationFingerprint:
          candidateView.candidate_publication_fingerprint,
        candidateIdentityFingerprint:
          candidateView.candidate_identity_fingerprint,
        deviceRegistryID: candidateView.device_registry_id,
        channels: sensorChannels,
        retainedOwner: candidateOwner
      )
      self.identity = identity
      physicalPreparedPoint = physicalPoint
      acceptedPhysicsGate = try MetalAcceptedPhysicsGateLease(
        buffer: gateBuffer, byteOffset: gateOffset
      )
      sensorCandidate = try MetalNumanXPendingSensorCandidateLease(
        bridgeCandidate: pendingView
      )
    } catch {
      symbols.preparedDrop(handle)
      throw error
    }
  }

  deinit { symbols.preparedDrop(handle) }

  public func quarantineTimeout() -> Bool {
    symbols.quarantineTimeout(handle) != 0
  }

  /// Encodes the bridge's explicit teardown-only owner proposal after a
  /// sticky timeout. It consumes no Brain witness and can never propose
  /// ACCEPT; the callback still carries the canonical owner proposal record.
  public func submitTimeoutRejectProposal(
    completion: @escaping @Sendable (
      Result<MetalNumanXHumanMatterProposalLease, Error>
    ) -> Void
  ) throws {
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      throw MetalNumanXBridgeV1Error.rejected(
        "failed to allocate timeout-reject proposal command"
      )
    }
    let box = MetalNumanXBridgeV1ProposalBox(
      owner: self, commandBuffer: commandBuffer, completion: completion
    )
    let opaque = Unmanaged.passRetained(box).toOpaque()
    guard symbols.submitTimeoutProposal(
      handle,
      Unmanaged.passUnretained(commandBuffer as AnyObject).toOpaque(),
      opaque,
      metalNumanXBridgeV1ProposalCallback
    ) != 0 else {
      Unmanaged<MetalNumanXBridgeV1ProposalBox>.fromOpaque(opaque).release()
      throw MetalNumanXBridgeV1Error.rejected(
        "native owner rejected timeout-reject proposal"
      )
    }
    commandBuffer.commit()
  }

  public func submitProposal(
    brain ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket,
    completion: @escaping @Sendable (Result<MetalNumanXHumanMatterProposalLease, Error>) -> Void
  ) throws {
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      throw MetalNumanXBridgeV1Error.rejected("failed to allocate proposal command")
    }
    let witnessBuffer = try MetalNumanXBridgeV1Convert.buffer(
      ticket.brainCommitWitnessMetalBufferObject
    )
    let wire = try makeWire(
      buffer: witnessBuffer,
      gpuAddress: ticket.brainCommitWitnessGPUAddress,
      byteCount: ticket.brainCommitWitnessByteCount,
      point: ticket.brainPreparedPoint
    )
    let box = MetalNumanXBridgeV1ProposalBox(
      owner: self, commandBuffer: commandBuffer, completion: completion
    )
    let opaque = Unmanaged.passRetained(box).toOpaque()
    var mutableWire = wire
    guard symbols.submitProposal(
      handle,
      Unmanaged.passUnretained(commandBuffer as AnyObject).toOpaque(),
      &mutableWire,
      opaque,
      metalNumanXBridgeV1ProposalCallback
    ) != 0 else {
      Unmanaged<MetalNumanXBridgeV1ProposalBox>.fromOpaque(opaque).release()
      throw MetalNumanXBridgeV1Error.rejected("native owner rejected proposal")
    }
    commandBuffer.commit()
  }

  public func reserveApplication(
    brain ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket
  ) throws {
    let buffer = ticket.brainCommitPreflightBuffer
    var wire = try makeWire(
      buffer: buffer,
      gpuAddress: buffer.gpuAddress,
      byteCount: 128,
      point: ticket.brainCommitPreflightReadyPoint
    )
    guard symbols.reserveApplication(handle, &wire) != 0 else {
      throw MetalNumanXBridgeV1Error.rejected(
        "native owner rejected Brain preflight reservation"
      )
    }
  }

  /// Reserves the exact already-produced Brain preflight solely so the owner
  /// can restore a timed-out prepared root. It does not authorize ACK or
  /// publication.
  public func reserveTimeoutRejectApplication(
    brain ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket
  ) throws {
    let buffer = ticket.brainCommitPreflightBuffer
    var wire = try makeWire(
      buffer: buffer,
      gpuAddress: buffer.gpuAddress,
      byteCount: 128,
      point: ticket.brainCommitPreflightReadyPoint
    )
    guard symbols.reserveTimeoutApplication(handle, &wire) != 0 else {
      throw MetalNumanXBridgeV1Error.rejected(
        "native owner rejected timeout-reject preflight reservation"
      )
    }
  }

  public func submitApply(
    ack ticket: MetalNumanXHumanMatterBrainAckTicket,
    completion: @escaping @Sendable (Result<MetalNumanXHumanMatterAppliedLease, Error>) -> Void
  ) throws {
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      throw MetalNumanXBridgeV1Error.rejected("failed to allocate apply command")
    }
    var wire = try makeWire(
      buffer: ticket.ackBuffer,
      gpuAddress: ticket.ackGPUAddress,
      byteCount: 128,
      point: ticket.ackReadyPoint
    )
    let box = MetalNumanXBridgeV1ApplyBox(
      owner: self, commandBuffer: commandBuffer, completion: completion
    )
    let opaque = Unmanaged.passRetained(box).toOpaque()
    guard symbols.submitApply(
      handle,
      Unmanaged.passUnretained(commandBuffer as AnyObject).toOpaque(),
      &wire,
      opaque,
      metalNumanXBridgeV1ApplyCallback
    ) != 0 else {
      Unmanaged<MetalNumanXBridgeV1ApplyBox>.fromOpaque(opaque).release()
      throw MetalNumanXBridgeV1Error.rejected("native owner rejected apply")
    }
    commandBuffer.commit()
  }

  /// Encodes the teardown-only forced restore after timeout. No Brain ACK is
  /// accepted or fabricated; successful completion must be rejectedRestored.
  public func submitTimeoutRejectApply(
    completion: @escaping @Sendable (
      Result<MetalNumanXHumanMatterAppliedLease, Error>
    ) -> Void
  ) throws {
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      throw MetalNumanXBridgeV1Error.rejected(
        "failed to allocate timeout-reject apply command"
      )
    }
    let box = MetalNumanXBridgeV1ApplyBox(
      owner: self, commandBuffer: commandBuffer, completion: completion
    )
    let opaque = Unmanaged.passRetained(box).toOpaque()
    guard symbols.submitTimeoutApply(
      handle,
      Unmanaged.passUnretained(commandBuffer as AnyObject).toOpaque(),
      opaque,
      metalNumanXBridgeV1ApplyCallback
    ) != 0 else {
      Unmanaged<MetalNumanXBridgeV1ApplyBox>.fromOpaque(opaque).release()
      throw MetalNumanXBridgeV1Error.rejected(
        "native owner rejected timeout-reject apply"
      )
    }
    commandBuffer.commit()
  }

  /// Releases an exact restored root and its bound HumanIO candidate. This is
  /// a synchronous scalar lifecycle transition; it publishes no Brain,
  /// physics, or sensor generation.
  public func releaseRejected() -> Bool {
    symbols.releaseRejected(handle)
      == UInt32(MRNX_PUBLICATION_REJECTED_V1.rawValue)
  }

  public func makeResolution(
    proposal: MetalNumanXHumanMatterProposalLease,
    applied: MetalNumanXHumanMatterAppliedLease,
    jointCommitFingerprint: UInt64,
    brainGeneration: UInt64
  ) throws -> MetalNumanXJointResolutionReservation {
    if applied.commandDisposition == .acceptedPendingPublication {
      var publication = mrnx_publication_v1()
      publication.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
      publication.struct_size = UInt32(MemoryLayout<mrnx_publication_v1>.stride)
      publication.joint_commit_fingerprint = jointCommitFingerprint
      publication.brain_generation = brainGeneration
      guard symbols.reservePublication(handle, &publication) != 0 else {
        throw MetalNumanXBridgeV1Error.rejected(
          "native owner rejected joint publication reservation"
        )
      }
    }
    return try MetalNumanXJointResolutionReservation(
      identity: identity,
      proposal: proposal,
      applied: applied,
      sensorCandidate: sensorCandidate,
      jointCommitFingerprint: jointCommitFingerprint,
      brainGeneration: brainGeneration,
      releaseAccepted: { [self] latch in
        var publication = mrnx_publication_v1()
        publication.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
        publication.struct_size = UInt32(MemoryLayout<mrnx_publication_v1>.stride)
        publication.joint_commit_fingerprint = jointCommitFingerprint
        publication.brain_generation = brainGeneration
        let raw = withoutActuallyEscaping(latch) { escapingLatch in
          let box = MetalNumanXBridgeV1LatchBox(escapingLatch)
          let opaque = Unmanaged.passRetained(box).toOpaque()
          let result = symbols.releaseAccepted(
            handle, &publication, opaque, metalNumanXBridgeV1LatchCallback
          )
          Unmanaged<MetalNumanXBridgeV1LatchBox>.fromOpaque(opaque).release()
          return result
        }
        return raw == UInt32(MRNX_PUBLICATION_RELEASED_V1.rawValue)
          ? .released : .terminalNoTouch
      },
      releaseRejected: { [self] in
        symbols.releaseRejected(handle)
          == UInt32(MRNX_PUBLICATION_REJECTED_V1.rawValue)
          ? .released : .terminalNoTouch
      }
    )
  }

  fileprivate func proposalLease(_ value: mrnx_proposal_view_v1) throws
    -> MetalNumanXHumanMatterProposalLease
  {
    guard let proposalOffset = Int(exactly: value.proposal.byte_offset),
      let tokenOffset = Int(exactly: value.proposed_token.byte_offset),
      let fenceOffset = Int(exactly: value.publication_fence.byte_offset)
    else {
      throw MetalNumanXBridgeV1Error.invalidABI(
        "owner proposal offsets exceed the Swift address space"
      )
    }
    let proposalBuffer = try MetalNumanXBridgeV1Convert.buffer(value.proposal.metal_buffer)
    let tokenBuffer = try MetalNumanXBridgeV1Convert.buffer(value.proposed_token.metal_buffer)
    let fenceBuffer = try MetalNumanXBridgeV1Convert.buffer(
      value.publication_fence.metal_buffer
    )
    return try MetalNumanXHumanMatterProposalLease(
      identity: try MetalNumanXBridgeV1Convert.identity(value.root),
      proposalBuffer: proposalBuffer,
      proposalByteOffset: proposalOffset,
      proposalGPUAddress: value.proposal.gpu_address,
      proposedTokenBuffer: tokenBuffer,
      proposedTokenByteOffset: tokenOffset,
      proposedTokenGPUAddress: value.proposed_token.gpu_address,
      publicationFenceBuffer: fenceBuffer,
      publicationFenceByteOffset: fenceOffset,
      publicationFenceGPUAddress: value.publication_fence.gpu_address,
      readyPoint: try MetalNumanXBridgeV1Convert.point(value.ready)
    )
  }

  fileprivate func appliedLease(_ value: mrnx_applied_view_v1) throws
    -> MetalNumanXHumanMatterAppliedLease
  {
    guard let disposition = MetalNumanXHumanMatterAppliedCommandDisposition(
      rawValue: value.command_disposition
    ), value.reserved0 == 0,
      let appliedOffset = Int(exactly: value.applied.byte_offset),
      let finalTokenOffset = Int(exactly: value.final_token.byte_offset)
    else {
      throw MetalNumanXBridgeV1Error.invalidABI("invalid owner apply disposition")
    }
    return try MetalNumanXHumanMatterAppliedLease(
      identity: try MetalNumanXBridgeV1Convert.identity(value.root),
      appliedBuffer: try MetalNumanXBridgeV1Convert.buffer(value.applied.metal_buffer),
      appliedByteOffset: appliedOffset,
      appliedGPUAddress: value.applied.gpu_address,
      finalTokenBuffer: try MetalNumanXBridgeV1Convert.buffer(
        value.final_token.metal_buffer
      ),
      finalTokenByteOffset: finalTokenOffset,
      finalTokenGPUAddress: value.final_token.gpu_address,
      readyPoint: try MetalNumanXBridgeV1Convert.point(value.ready),
      commandDisposition: disposition
    )
  }

  private func makeWire(
    buffer: any MTLBuffer,
    gpuAddress: UInt64,
    byteCount: Int,
    point: MetalSharedEventPoint
  ) throws -> mrnx_wire_lease_v1 {
    guard buffer.gpuAddress == gpuAddress, buffer.length == byteCount,
      buffer.device.registryID == identityDeviceRegistryID,
      point.event.signaledValue <= point.value
    else {
      throw MetalNumanXBridgeV1Error.invalidABI("Brain wire range is not exact")
    }
    var wire = mrnx_wire_lease_v1()
    wire.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
    wire.struct_size = UInt32(MemoryLayout<mrnx_wire_lease_v1>.stride)
    wire.root = rootRecord()
    wire.record = makeRange(
      buffer: buffer, byteCount: byteCount,
      elementType: UInt32(MRNX_ELEMENT_RAW_BYTES_V1.rawValue), elementBytes: 1
    )
    wire.ready = makePoint(point)
    return wire
  }

  private var identityDeviceRegistryID: UInt64 {
    acceptedPhysicsGate.buffer.device.registryID
  }

  private func rootRecord() -> mrnx_root_v1 {
    var root = mrnx_root_v1()
    root.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
    root.struct_size = UInt32(MemoryLayout<mrnx_root_v1>.stride)
    root.owner_wire_abi_version = UInt32(MRNX_OWNER_WIRE_ABI_V4)
    root.environment_count = 1
    root.environment = identity.environment
    root.transaction_slot = identity.transactionSlot
    root.step_index = identity.stepIndex
    root.control_step = identity.controlStep
    root.substep_index = identity.substepIndex
    root.physics_substep_count = identity.physicsSubstepCount
    root.q_coordinate_count = UInt32(MRNX_FULL_BODY_NQ)
    root.dof_count = UInt32(MRNX_FULL_BODY_NV)
    root.dof_layout_version = 1
    root.program_fingerprint = identity.programFingerprint
    root.transaction_fingerprint = identity.transactionFingerprint
    root.linearization_epoch = identity.linearizationEpoch
    root.slot_generation = identity.slotGeneration
    root.device_registry_id = identityDeviceRegistryID
    return root
  }

  private func makeRange(
    buffer: any MTLBuffer,
    byteCount: Int,
    elementType: UInt32,
    elementBytes: UInt32
  ) -> mrnx_metal_range_v1 {
    var range = mrnx_metal_range_v1()
    range.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
    range.struct_size = UInt32(MemoryLayout<mrnx_metal_range_v1>.stride)
    range.metal_buffer = Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
    range.gpu_address = buffer.gpuAddress
    range.byte_count = UInt64(byteCount)
    range.element_type = elementType
    range.element_byte_count = elementBytes
    return range
  }

  private func makePoint(_ point: MetalSharedEventPoint) -> mrnx_event_point_v1 {
    var value = mrnx_event_point_v1()
    value.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
    value.struct_size = UInt32(MemoryLayout<mrnx_event_point_v1>.stride)
    value.shared_event = Unmanaged.passUnretained(point.event as AnyObject).toOpaque()
    value.value = point.value
    value.device_registry_id = identityDeviceRegistryID
    return value
  }
}

@available(macOS 26.0, *)
private final class MetalNumanXBridgeV1RootBox: @unchecked Sendable {
  let runtime: MetalNumanXBridgeV1Runtime
  let completion: @Sendable (Result<MetalNumanXBridgeV1PreparedRoot, Error>) -> Void
  init(
    runtime: MetalNumanXBridgeV1Runtime,
    completion: @escaping @Sendable (Result<MetalNumanXBridgeV1PreparedRoot, Error>) -> Void
  ) {
    self.runtime = runtime
    self.completion = completion
  }
}

@available(macOS 26.0, *)
private final class MetalNumanXBridgeV1ProposalBox: @unchecked Sendable {
  let owner: MetalNumanXBridgeV1PreparedRoot
  let commandBuffer: any MTLCommandBuffer
  let completion: @Sendable (Result<MetalNumanXHumanMatterProposalLease, Error>) -> Void
  init(
    owner: MetalNumanXBridgeV1PreparedRoot,
    commandBuffer: any MTLCommandBuffer,
    completion: @escaping @Sendable (Result<MetalNumanXHumanMatterProposalLease, Error>) -> Void
  ) {
    self.owner = owner
    self.commandBuffer = commandBuffer
    self.completion = completion
  }
}

@available(macOS 26.0, *)
private final class MetalNumanXBridgeV1ApplyBox: @unchecked Sendable {
  let owner: MetalNumanXBridgeV1PreparedRoot
  let commandBuffer: any MTLCommandBuffer
  let completion: @Sendable (Result<MetalNumanXHumanMatterAppliedLease, Error>) -> Void
  init(
    owner: MetalNumanXBridgeV1PreparedRoot,
    commandBuffer: any MTLCommandBuffer,
    completion: @escaping @Sendable (Result<MetalNumanXHumanMatterAppliedLease, Error>) -> Void
  ) {
    self.owner = owner
    self.commandBuffer = commandBuffer
    self.completion = completion
  }
}

@available(macOS 26.0, *)
private final class MetalNumanXBridgeV1LatchBox: @unchecked Sendable {
  let latch: @Sendable () -> Bool
  init(_ latch: @escaping @Sendable () -> Bool) { self.latch = latch }
}

@available(macOS 26.0, *)
private let metalNumanXBridgeV1RootCallback: MetalNumanXBridgeV1RootCallback = {
  context, prepared, candidate, completion, _ in
  guard let context else { return }
  let box = Unmanaged<MetalNumanXBridgeV1RootBox>
    .fromOpaque(context).takeRetainedValue()
  guard let completion, completion.pointee.status == UInt32(MRNX_COMPLETION_READY_V1.rawValue),
    let prepared, let candidate
  else {
    box.completion(.failure(MetalNumanXBridgeV1Error.rejected(
      "native physical root did not prepare"
    )))
    return
  }
  do {
    box.completion(.success(try MetalNumanXBridgeV1PreparedRoot(
      symbols: box.runtime.symbols,
      device: box.runtime.device,
      prepared: prepared,
      candidate: candidate
    )))
  } catch {
    box.completion(.failure(error))
  }
}

@available(macOS 26.0, *)
private let metalNumanXBridgeV1ProposalCallback: MetalNumanXBridgeV1ProposalCallback = {
  context, completion, proposal in
  guard let context else { return }
  let box = Unmanaged<MetalNumanXBridgeV1ProposalBox>
    .fromOpaque(context).takeRetainedValue()
  guard let completion,
    completion.pointee.status == UInt32(MRNX_COMPLETION_READY_V1.rawValue)
      || completion.pointee.status
        == UInt32(MRNX_COMPLETION_TIMEOUT_QUARANTINED_V1.rawValue),
    let proposal
  else {
    box.completion(.failure(MetalNumanXBridgeV1Error.rejected(
      "native proposal did not settle READY"
    )))
    return
  }
  do { box.completion(.success(try box.owner.proposalLease(proposal.pointee))) }
  catch { box.completion(.failure(error)) }
}

@available(macOS 26.0, *)
private let metalNumanXBridgeV1ApplyCallback: MetalNumanXBridgeV1ApplyCallback = {
  context, completion, applied in
  guard let context else { return }
  let box = Unmanaged<MetalNumanXBridgeV1ApplyBox>
    .fromOpaque(context).takeRetainedValue()
  guard let completion, let applied,
    completion.pointee.status == UInt32(MRNX_COMPLETION_ACCEPTED_PENDING_PUBLICATION_V1.rawValue)
      || completion.pointee.status == UInt32(MRNX_COMPLETION_REJECTED_RELEASED_V1.rawValue)
      || completion.pointee.status == UInt32(MRNX_COMPLETION_TIMEOUT_QUARANTINED_V1.rawValue)
  else {
    box.completion(.failure(MetalNumanXBridgeV1Error.rejected(
      "native apply did not settle as accepted or restored"
    )))
    return
  }
  do { box.completion(.success(try box.owner.appliedLease(applied.pointee))) }
  catch { box.completion(.failure(error)) }
}

@available(macOS 26.0, *)
private let metalNumanXBridgeV1LatchCallback: MetalNumanXBridgeV1LatchCallback = {
  context, _ in
  guard let context else { return 0 }
  let box = Unmanaged<MetalNumanXBridgeV1LatchBox>.fromOpaque(context)
    .takeUnretainedValue()
  return box.latch() ? 1 : 0
}

@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalNumanXBridgeV1Runtime: @unchecked Sendable {
  public struct Configuration: Sendable {
    public let rigidPayloadPath: String
    public let musclePayloadPath: String
    public let metalRoboMetallibPath: String
    public let matterMetallibPath: String
    public let matterMaterialPath: String
    public let timestepMicroseconds: UInt64
    public let maximumRetainedBytes: UInt64
    public let transactionSlotCount: UInt32

    public init(
      rigidPayloadPath: String,
      musclePayloadPath: String,
      metalRoboMetallibPath: String,
      matterMetallibPath: String,
      matterMaterialPath: String,
      timestepMicroseconds: UInt64,
      maximumRetainedBytes: UInt64 = 1 << 30,
      transactionSlotCount: UInt32 = 2
    ) {
      self.rigidPayloadPath = rigidPayloadPath
      self.musclePayloadPath = musclePayloadPath
      self.metalRoboMetallibPath = metalRoboMetallibPath
      self.matterMetallibPath = matterMetallibPath
      self.matterMaterialPath = matterMaterialPath
      self.timestepMicroseconds = timestepMicroseconds
      self.maximumRetainedBytes = maximumRetainedBytes
      self.transactionSlotCount = transactionSlotCount
    }
  }

  public struct Info: Sendable {
    public let bodyCount: UInt32
    public let qCoordinateCount: UInt32
    public let dofCount: UInt32
    public let muscleCount: UInt32
    public let residentContinuationCount: UInt32
    public let deviceRegistryID: UInt64
    public let acceptedStateProofProgramFingerprint: UInt64
    public let modelSourceFingerprint: UInt64
  }

  /// One jointly visible Brain/physics/HumanIO root copied while the native
  /// bridge holds its shared publication gate. The channel leases retain the
  /// exact Metal objects named by the snapshot; their bytes remain native
  /// publication authority and are never copied through the host.
  public struct AggregateSnapshot: Sendable {
    public let publicationEpoch: UInt64
    public let brainGeneration: UInt64
    public let physicsGeneration: UInt64
    public let sensorGeneration: UInt64
    public let identity: MetalNumanXHumanMatterRootIdentity
    public let proprioception: MetalNumanXHumanIOSensorCandidateChannel
    public let interoception: MetalNumanXHumanIOSensorCandidateChannel

    /// Rebinds this jointly published HumanIO view as the causal sensor input
    /// for the immediately following Brain root. No payload is copied or read
    /// on the host; the returned packet retains the exact published MTLBuffer
    /// objects and validates morphology, latency, and prior generations.
    public func sensorPacket(
      for transaction: BrainJointTransactionToken,
      compiledSpeciesTemplate: CompiledSpeciesTemplate
    ) throws -> NumanXSensorPacketLease {
      guard transaction.environmentIdentifier == 0,
        transaction.baseBrainGeneration == brainGeneration,
        transaction.basePhysicsGeneration == physicsGeneration
      else {
        throw MetalNumanXBridgeV1Error.rejected(
          "aggregate sensors do not precede the requested Brain root"
        )
      }
      return try NumanXSensorPacketLease(
        transaction: transaction,
        compiledSpeciesTemplate: compiledSpeciesTemplate,
        rawSensors: [proprioception.rawSensor, interoception.rawSensor]
      )
    }
  }

  fileprivate let symbols: MetalNumanXBridgeV1Symbols
  fileprivate let device: any MTLDevice
  private let runtime: UnsafeMutableRawPointer
  public let info: Info

  public init(
    libraryPath: String,
    device: any MTLDevice,
    configuration: Configuration
  ) throws {
    precondition(MemoryLayout<mrnx_physical_root_request_v1>.stride == 600)
    let symbols = try MetalNumanXBridgeV1Symbols(path: libraryPath)
    var rawInfo = mrnx_runtime_info_v1()
    rawInfo.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
    rawInfo.struct_size = UInt32(MemoryLayout<mrnx_runtime_info_v1>.stride)
    let created: UnsafeMutableRawPointer? = configuration.rigidPayloadPath.withCString {
      rigid in configuration.musclePayloadPath.withCString {
        muscles in configuration.metalRoboMetallibPath.withCString {
          metalRobo in configuration.matterMetallibPath.withCString {
            matter in configuration.matterMaterialPath.withCString { material in
              var config = mrnx_runtime_config_v1()
              config.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
              config.struct_size = UInt32(MemoryLayout<mrnx_runtime_config_v1>.stride)
              config.metal_device = Unmanaged.passUnretained(device as AnyObject).toOpaque()
              config.rigid_payload_path = rigid
              config.muscle_payload_path = muscles
              config.metalrobo_metallib_path = metalRobo
              config.matter_metallib_path = matter
              config.matter_material_path = material
              config.timestep_microseconds = configuration.timestepMicroseconds
              config.maximum_retained_bytes = configuration.maximumRetainedBytes
              config.transaction_slot_count = configuration.transactionSlotCount
              return symbols.runtimeCreate(&config, &rawInfo)
            }
          }
        }
      }
    }
    guard let created else {
      throw MetalNumanXBridgeV1Error.runtime(
        rawInfo.status, rawInfo.request_failure_stage
      )
    }
    guard rawInfo.status == UInt32(MRNX_RUNTIME_READY_V1.rawValue),
      rawInfo.body_count > 0,
      rawInfo.q_coordinate_count == UInt32(MRNX_FULL_BODY_NQ),
      rawInfo.dof_count == UInt32(MRNX_FULL_BODY_NV),
      rawInfo.muscle_count == UInt32(MRNX_FULL_BODY_MUSCLE_COUNT),
      rawInfo.device_registry_id == device.registryID
    else {
      symbols.runtimeDrop(created)
      throw MetalNumanXBridgeV1Error.runtime(
        rawInfo.status, rawInfo.request_failure_stage
      )
    }
    self.symbols = symbols
    self.device = device
    runtime = created
    info = Info(
      bodyCount: rawInfo.body_count,
      qCoordinateCount: rawInfo.q_coordinate_count,
      dofCount: rawInfo.dof_count,
      muscleCount: rawInfo.muscle_count,
      residentContinuationCount: rawInfo.resident_continuation_count,
      deviceRegistryID: rawInfo.device_registry_id,
      acceptedStateProofProgramFingerprint:
        rawInfo.accepted_state_proof_program_fingerprint,
      modelSourceFingerprint: rawInfo.model_source_fingerprint
    )
  }

  deinit { symbols.runtimeDrop(runtime) }

  /// Returns current scalar diagnostics without waiting for Metal. The
  /// continuation count increments only after the owner has armed a root that
  /// consumes the prior accepted q/v/MyoSim arenas in place.
  public func currentInfo() throws -> Info {
    var rawInfo = mrnx_runtime_info_v1()
    rawInfo.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
    rawInfo.struct_size = UInt32(MemoryLayout<mrnx_runtime_info_v1>.stride)
    guard symbols.runtimeCopyInfo(runtime, &rawInfo) != 0,
      rawInfo.device_registry_id == info.deviceRegistryID,
      rawInfo.model_source_fingerprint == info.modelSourceFingerprint,
      rawInfo.accepted_state_proof_program_fingerprint
        == info.acceptedStateProofProgramFingerprint
    else {
      throw MetalNumanXBridgeV1Error.invalidABI(
        "native runtime diagnostics changed immutable identity"
      )
    }
    return Info(
      bodyCount: rawInfo.body_count,
      qCoordinateCount: rawInfo.q_coordinate_count,
      dofCount: rawInfo.dof_count,
      muscleCount: rawInfo.muscle_count,
      residentContinuationCount: rawInfo.resident_continuation_count,
      deviceRegistryID: rawInfo.device_registry_id,
      acceptedStateProofProgramFingerprint:
        rawInfo.accepted_state_proof_program_fingerprint,
      modelSourceFingerprint: rawInfo.model_source_fingerprint
    )
  }

  /// Copies the sole aggregate public tuple. A nil result means no root has
  /// published yet or the native domain is sticky-poisoned. This method never
  /// reads sensor payload bytes and never falls back to independent component
  /// snapshots.
  public func aggregateSnapshotIfAvailable() throws -> AggregateSnapshot? {
    var value = mrnx_aggregate_snapshot_v1()
    value.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
    value.struct_size = UInt32(MemoryLayout<mrnx_aggregate_snapshot_v1>.stride)
    guard symbols.runtimeCopySnapshot(runtime, &value) != 0 else { return nil }
    guard value.abi_version == UInt32(MRNX_BRIDGE_ABI_V1),
      value.struct_size == MemoryLayout<mrnx_aggregate_snapshot_v1>.stride,
      value.publication_epoch > 0,
      value.brain_generation > 0,
      value.physics_generation > 0,
      value.sensor_generation > 0,
      value.sensor.channel_count == 2,
      value.sensor.accepted_brain_generation == value.brain_generation,
      value.sensor.key.sensor_generation == value.sensor_generation,
      value.proprioception.modality
        == UInt32(MRNX_CANDIDATE_MODALITY_PROPRIOCEPTION_V1),
      value.interoception.modality
        == UInt32(MRNX_CANDIDATE_MODALITY_INTEROCEPTION_V1)
    else {
      throw MetalNumanXBridgeV1Error.invalidABI(
        "native aggregate publication tuple is malformed"
      )
    }
    return AggregateSnapshot(
      publicationEpoch: value.publication_epoch,
      brainGeneration: value.brain_generation,
      physicsGeneration: value.physics_generation,
      sensorGeneration: value.sensor_generation,
      identity: try MetalNumanXBridgeV1Convert.identity(value.root),
      proprioception: try Self.snapshotChannel(value.proprioception),
      interoception: try Self.snapshotChannel(value.interoception)
    )
  }

  public func beginPhysicalRoot(
    transaction: BrainJointTransactionToken,
    motor ticket: MetalNumiBrainRuntime.NumanXMotorSubmissionTicket,
    completion: @escaping @Sendable (Result<MetalNumanXBridgeV1PreparedRoot, Error>) -> Void
  ) throws {
    guard transaction.environmentIdentifier == 0,
      ticket.candidate.transactionFingerprint == transaction.fingerprint,
      ticket.fastSystems.substep.substepIndex == 0,
      ticket.candidate.usesDecisionShadow,
      ticket.buffers.output.muscleCount == UInt32(MRNX_FULL_BODY_MUSCLE_COUNT)
    else {
      throw MetalNumanXBridgeV1Error.rejected(
        "async motor ticket is not the canonical full-body root"
      )
    }
    var request = mrnx_physical_root_request_v1()
    request.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
    request.struct_size = UInt32(MemoryLayout<mrnx_physical_root_request_v1>.stride)
    request.root = transaction.abiRecord
    request.substep = ticket.fastSystems.substep.abiRecord
    request.candidate = ticket.candidate.abiRecord
    request.motor_header = try makeRange(
      object: ticket.buffers.headerMetalBufferObject,
      address: ticket.buffers.output.headerGPUAddress,
      byteCount: ticket.buffers.output.headerByteCount,
      elementType: UInt32(MRNX_ELEMENT_RAW_BYTES_V1.rawValue),
      elementByteCount: 1
    )
    request.muscle_excitation = try makeRange(
      object: ticket.buffers.excitationMetalBufferObject,
      address: ticket.buffers.output.muscleExcitationGPUAddress,
      byteCount: ticket.buffers.output.muscleExcitationByteCount,
      elementType: UInt32(MRNX_ELEMENT_FLOAT32_V1.rawValue),
      elementByteCount: UInt32(MemoryLayout<Float>.stride)
    )
    request.autonomic_command = try makeRange(
      object: ticket.buffers.autonomicMetalBufferObject,
      address: ticket.fastSystems.fastAutonomicOutput.gpuAddress,
      byteCount: ticket.fastSystems.fastAutonomicOutput.byteCount,
      elementType: UInt32(MRNX_ELEMENT_RAW_BYTES_V1.rawValue),
      elementByteCount: 1
    )
    request.active_sensing_command = try makeRange(
      object: ticket.buffers.activeSensingMetalBufferObject,
      address: ticket.fastSystems.activeSensingOutput.gpuAddress,
      byteCount: ticket.fastSystems.activeSensingOutput.byteCount,
      elementType: UInt32(MRNX_ELEMENT_RAW_BYTES_V1.rawValue),
      elementByteCount: 1
    )
    request.motor_ready_gate = try makeRange(
      object: ticket.motorReadyGate.metalBufferObject,
      address: ticket.motorReadyGate.gpuAddress,
      byteCount: MetalNumanXMotorReadyGateLease.byteCount,
      elementType: UInt32(MRNX_ELEMENT_RAW_BYTES_V1.rawValue),
      elementByteCount: 1
    )
    request.motor_ready.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
    request.motor_ready.struct_size = UInt32(MemoryLayout<mrnx_event_point_v1>.stride)
    request.motor_ready.shared_event = Unmanaged.passUnretained(
      ticket.motorReadyPoint.event as AnyObject
    ).toOpaque()
    request.motor_ready.value = ticket.motorReadyPoint.value
    request.motor_ready.device_registry_id = device.registryID
    let box = MetalNumanXBridgeV1RootBox(runtime: self, completion: completion)
    let opaque = Unmanaged.passRetained(box).toOpaque()
    guard symbols.runtimeBegin(
      runtime, &request, opaque, metalNumanXBridgeV1RootCallback
    ) != 0 else {
      Unmanaged<MetalNumanXBridgeV1RootBox>.fromOpaque(opaque).release()
      var current = mrnx_runtime_info_v1()
      current.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
      current.struct_size = UInt32(MemoryLayout<mrnx_runtime_info_v1>.stride)
      _ = symbols.runtimeCopyInfo(runtime, &current)
      throw MetalNumanXBridgeV1Error.runtime(
        current.status, current.request_failure_stage
      )
    }
  }

  private func makeRange(
    object: UnsafeMutableRawPointer,
    address: UInt64,
    byteCount: Int,
    elementType: UInt32,
    elementByteCount: UInt32
  ) throws -> mrnx_metal_range_v1 {
    let buffer = try MetalNumanXBridgeV1Convert.buffer(object)
    guard buffer.device.registryID == device.registryID,
      address >= buffer.gpuAddress,
      let count = UInt64(exactly: byteCount)
    else {
      throw MetalNumanXBridgeV1Error.rejected(
        "NumiBrain motor range is not resident on the bridge device"
      )
    }
    let offset = address - buffer.gpuAddress
    guard offset <= UInt64(buffer.length),
      count <= UInt64(buffer.length) - offset
    else {
      throw MetalNumanXBridgeV1Error.rejected(
        "NumiBrain motor range exceeds its retained MTLBuffer"
      )
    }
    var range = mrnx_metal_range_v1()
    range.abi_version = UInt32(MRNX_BRIDGE_ABI_V1)
    range.struct_size = UInt32(MemoryLayout<mrnx_metal_range_v1>.stride)
    range.metal_buffer = object
    range.gpu_address = address
    range.byte_offset = offset
    range.byte_count = count
    range.element_type = elementType
    range.element_byte_count = elementByteCount
    return range
  }

  private static func snapshotChannel(
    _ value: mrnx_candidate_channel_v1
  ) throws -> MetalNumanXHumanIOSensorCandidateChannel {
    guard value.abi_version == UInt32(MRNX_BRIDGE_ABI_V1),
      value.struct_size == MemoryLayout<mrnx_candidate_channel_v1>.stride,
      value.flags & UInt32(MRNX_CANDIDATE_CHANNEL_HAS_VALIDITY_V1) != 0,
      let modality = SensoryModality(rawValue: UInt16(value.modality)),
      modality == .proprioception || modality == .interoception
    else {
      throw MetalNumanXBridgeV1Error.invalidABI(
        "native aggregate sensor channel is malformed"
      )
    }
    return try MetalNumanXHumanIOSensorCandidateChannel(
      modality: modality,
      receptorTimestamp: BrainTimestamp(
        microseconds: value.receptor_timestamp_microseconds
      ),
      receptorCount: value.receptor_count,
      featureDimension: value.feature_dimension,
      values: MetalNumanXBridgeV1Convert.range(
        value.values,
        expectedType: UInt32(MRNX_ELEMENT_FLOAT32_V1.rawValue),
        expectedElementBytes: UInt32(MemoryLayout<Float>.stride)
      ),
      validity: MetalNumanXBridgeV1Convert.range(
        value.validity,
        expectedType: UInt32(MRNX_ELEMENT_UINT32_V1.rawValue),
        expectedElementBytes: UInt32(MemoryLayout<UInt32>.stride)
      )
    )
  }
}
