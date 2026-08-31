import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Pointer-free mirror of the canonical MetalRobo HumanIO transaction key.
/// The six UInt64 fields and FNV domain are frozen by the ABI4 bridge; raw
/// HumanIO objects and candidate storage remain retained only by the lease.
@frozen
@available(macOS 26.0, *)
public struct MetalNumanXHumanIOCandidateKey: Equatable, Hashable, Sendable {
  private static let fnvOffset: UInt64 = 14_695_981_039_346_656_037
  private static let fnvPrime: UInt64 = 1_099_511_628_211
  private static let zeroHashSentinel: UInt64 = 0x9e37_79b9_7f4a_7c15
  private static let domain = Array(
    "metalrobo.numanx-human-io.candidate-key.v1".utf8
  )

  public let transactionFingerprint: UInt64
  public let programFingerprint: UInt64
  public let sensorFingerprint: UInt64
  public let transactionInstanceFingerprint: UInt64
  public let sensorGeneration: UInt64
  public let commandBufferIdentity: UInt64
  public let fingerprint: UInt64

  public init(
    transactionFingerprint: UInt64,
    programFingerprint: UInt64,
    sensorFingerprint: UInt64,
    transactionInstanceFingerprint: UInt64,
    sensorGeneration: UInt64,
    commandBufferIdentity: UInt64
  ) throws {
    guard transactionFingerprint > 0, programFingerprint > 0,
      sensorFingerprint > 0, transactionInstanceFingerprint > 0,
      sensorGeneration > 0, commandBufferIdentity > 0
    else {
      throw TissueError.transaction(
        "NumanX HumanIO candidate key identity is incomplete"
      )
    }
    self.transactionFingerprint = transactionFingerprint
    self.programFingerprint = programFingerprint
    self.sensorFingerprint = sensorFingerprint
    self.transactionInstanceFingerprint = transactionInstanceFingerprint
    self.sensorGeneration = sensorGeneration
    self.commandBufferIdentity = commandBufferIdentity
    var hash = Self.fnvOffset
    for byte in Self.domain {
      hash = (hash ^ UInt64(byte)) &* Self.fnvPrime
    }
    for shift in stride(from: 0, to: 64, by: 8) {
      hash = (hash ^ ((UInt64(Self.domain.count) >> UInt64(shift)) & 0xff))
        &* Self.fnvPrime
    }
    for value in [
      transactionFingerprint,
      programFingerprint,
      sensorFingerprint,
      transactionInstanceFingerprint,
      sensorGeneration,
      commandBufferIdentity,
    ] {
      for shift in stride(from: 0, to: 64, by: 8) {
        hash = (hash ^ ((value >> UInt64(shift)) & 0xff)) &* Self.fnvPrime
      }
    }
    fingerprint = hash == 0 ? Self.zeroHashSentinel : hash
  }
}

/// Exact retained Metal range imported from the versioned HumanIO C bridge.
/// The bridge supplies both the retained Objective-C handle and its canonical
/// scalar view. Construction rejects a same-shaped allocation substituted for
/// that handle, even when byte counts and tensor shape are identical.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalNumanXHumanIOCandidateRangeLease:
  @unchecked Sendable
{
  public static let float32ElementType: UInt32 = 1
  public static let uint32ElementType: UInt32 = 2

  let buffer: any MTLBuffer
  public let metalBufferObject: UnsafeMutableRawPointer
  public let gpuAddress: UInt64
  public let byteOffset: Int
  public let byteCount: Int
  public let elementType: UInt32
  public let elementByteCount: UInt32

  public init(
    buffer: any MTLBuffer,
    metalBufferObject: UnsafeMutableRawPointer,
    gpuAddress: UInt64,
    byteOffset: Int,
    byteCount: Int,
    elementType: UInt32,
    elementByteCount: UInt32
  ) throws {
    guard byteOffset >= 0 else {
      throw TissueError.transaction(
        "NumanX HumanIO candidate range offset is invalid"
      )
    }
    let exactObject = Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
    let (rangeAddress, addressOverflow) = buffer.gpuAddress
      .addingReportingOverflow(UInt64(byteOffset))
    let (end, lengthOverflow) = byteOffset.addingReportingOverflow(byteCount)
    guard metalBufferObject == exactObject,
      byteOffset == 0, byteCount > 0, !addressOverflow,
      !lengthOverflow, end == buffer.length,
      gpuAddress == rangeAddress, gpuAddress > 0,
      (elementType == Self.float32ElementType
        && elementByteCount == UInt32(MemoryLayout<Float>.stride))
        || (elementType == Self.uint32ElementType
          && elementByteCount == UInt32(MemoryLayout<UInt32>.stride))
    else {
      throw TissueError.transaction(
        "NumanX HumanIO candidate range does not match its retained Metal object"
      )
    }
    self.buffer = buffer
    self.metalBufferObject = metalBufferObject
    self.gpuAddress = gpuAddress
    self.byteOffset = byteOffset
    self.byteCount = byteCount
    self.elementType = elementType
    self.elementByteCount = elementByteCount
  }
}

/// One exact sensor channel inside the unpublished HumanIO candidate. These
/// fields are imported as one bridge view; Brain never accepts an unrelated
/// `rawSensors` array alongside candidate identity metadata.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalNumanXHumanIOSensorCandidateChannel:
  @unchecked Sendable
{
  public let modality: SensoryModality
  public let receptorTimestamp: BrainTimestamp
  public let deliveryTimestamp: BrainTimestamp
  public let latencyMicroseconds: UInt32
  public let sampleIntervalMicroseconds: UInt32
  public let receptorCount: UInt32
  public let featureDimension: UInt32
  public let values: MetalNumanXHumanIOCandidateRangeLease
  public let validity: MetalNumanXHumanIOCandidateRangeLease?
  let rawSensor: MetalRawSensorBufferLease

  public init(
    modality: SensoryModality,
    receptorTimestamp: BrainTimestamp,
    deliveryTimestamp: BrainTimestamp,
    latencyMicroseconds: UInt32,
    sampleIntervalMicroseconds: UInt32,
    receptorCount: UInt32,
    featureDimension: UInt32,
    values: MetalNumanXHumanIOCandidateRangeLease,
    validity: MetalNumanXHumanIOCandidateRangeLease? = nil
  ) throws {
    let (scalarCount, scalarOverflow) = Int(receptorCount)
      .multipliedReportingOverflow(by: Int(featureDimension))
    let (minimumValueBytes, valueOverflow) = scalarCount
      .multipliedReportingOverflow(by: MemoryLayout<Float>.stride)
    let (minimumValidityBytes, validityOverflow) = Int(receptorCount)
      .multipliedReportingOverflow(by: MemoryLayout<UInt32>.stride)
    guard receptorCount > 0, featureDimension > 0,
      receptorTimestamp <= deliveryTimestamp,
      latencyMicroseconds > 0,
      sampleIntervalMicroseconds > 0,
      deliveryTimestamp.rawValue - receptorTimestamp.rawValue
        == UInt64(latencyMicroseconds),
      !scalarOverflow, !valueOverflow, !validityOverflow,
      values.elementType
        == MetalNumanXHumanIOCandidateRangeLease.float32ElementType,
      values.elementByteCount == UInt32(MemoryLayout<Float>.stride),
      values.byteCount >= minimumValueBytes,
      validity == nil || (
        validity!.buffer.device.registryID == values.buffer.device.registryID
          && validity!.elementType
            == MetalNumanXHumanIOCandidateRangeLease.uint32ElementType
          && validity!.elementByteCount
            == UInt32(MemoryLayout<UInt32>.stride)
          && validity!.byteCount >= minimumValidityBytes
      )
    else {
      throw TissueError.transaction(
        "NumanX HumanIO sensor channel has invalid exact ranges or shape"
      )
    }
    self.modality = modality
    self.receptorTimestamp = receptorTimestamp
    self.deliveryTimestamp = deliveryTimestamp
    self.latencyMicroseconds = latencyMicroseconds
    self.sampleIntervalMicroseconds = sampleIntervalMicroseconds
    self.receptorCount = receptorCount
    self.featureDimension = featureDimension
    self.values = values
    self.validity = validity
    rawSensor = try MetalRawSensorBufferLease(
      buffer: values.buffer,
      modality: modality,
      receptorTimestamp: receptorTimestamp,
      receptorCount: receptorCount,
      featureDimension: featureDimension,
      validityBuffer: validity?.buffer
    )
  }
}

/// Versioned, retained HumanIO candidate view imported atomically from the C
/// bridge completion callback. It binds the canonical key/program identities
/// and exact Metal objects before Brain can construct a pending candidate.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalNumanXHumanIOPendingCandidateView:
  @unchecked Sendable
{
  public static let abiVersion: UInt32 = 1

  public let transactionFingerprint: UInt64
  public let acceptedBrainGeneration: UInt64
  public let sensorGeneration: UInt64
  public let humanIOProgramFingerprint: UInt64
  public let sensorFingerprint: UInt64
  public let transactionInstanceFingerprint: UInt64
  public let candidateKey: MetalNumanXHumanIOCandidateKey
  public let candidatePublicationFingerprint: UInt64
  public let candidateIdentityFingerprint: UInt64
  public let deviceRegistryID: UInt64
  let rawSensors: [MetalRawSensorBufferLease]
  fileprivate let channels: [MetalNumanXHumanIOSensorCandidateChannel]
  fileprivate let retainedOwner: AnyObject

  public init(
    abiVersion: UInt32,
    transactionFingerprint: UInt64,
    acceptedBrainGeneration: UInt64,
    sensorGeneration: UInt64,
    humanIOProgramFingerprint: UInt64,
    sensorFingerprint: UInt64,
    transactionInstanceFingerprint: UInt64,
    candidateKey: MetalNumanXHumanIOCandidateKey,
    candidateKeyFingerprint: UInt64,
    candidatePublicationFingerprint: UInt64,
    candidateIdentityFingerprint: UInt64,
    deviceRegistryID: UInt64,
    channels: [MetalNumanXHumanIOSensorCandidateChannel],
    retainedOwner: AnyObject
  ) throws {
    let sorted = channels.sorted { $0.modality.rawValue < $1.modality.rawValue }
    guard abiVersion == Self.abiVersion,
      transactionFingerprint > 0, acceptedBrainGeneration > 0,
      sensorGeneration > 0, humanIOProgramFingerprint > 0,
      sensorFingerprint > 0, transactionInstanceFingerprint > 0,
      candidateKeyFingerprint == candidateKey.fingerprint,
      candidatePublicationFingerprint > 0, candidateIdentityFingerprint > 0,
      candidateKey.transactionFingerprint == transactionFingerprint,
      candidateKey.programFingerprint == humanIOProgramFingerprint,
      candidateKey.sensorFingerprint == sensorFingerprint,
      candidateKey.transactionInstanceFingerprint
        == transactionInstanceFingerprint,
      candidateKey.sensorGeneration == sensorGeneration,
      deviceRegistryID > 0, !sorted.isEmpty,
      zip(sorted, sorted.dropFirst()).allSatisfy({
        $0.modality != $1.modality
      }),
      sorted.allSatisfy({ channel in
        channel.values.buffer.device.registryID == deviceRegistryID
          && (channel.validity == nil
            || channel.validity!.buffer.device.registryID == deviceRegistryID)
      })
    else {
      throw TissueError.transaction(
        "NumanX HumanIO pending candidate bridge identity is incomplete"
      )
    }
    self.transactionFingerprint = transactionFingerprint
    self.acceptedBrainGeneration = acceptedBrainGeneration
    self.sensorGeneration = sensorGeneration
    self.humanIOProgramFingerprint = humanIOProgramFingerprint
    self.sensorFingerprint = sensorFingerprint
    self.transactionInstanceFingerprint = transactionInstanceFingerprint
    self.candidateKey = candidateKey
    self.candidatePublicationFingerprint = candidatePublicationFingerprint
    self.candidateIdentityFingerprint = candidateIdentityFingerprint
    self.deviceRegistryID = deviceRegistryID
    rawSensors = sorted.map(\.rawSensor)
    self.channels = sorted
    self.retainedOwner = retainedOwner
  }
}

/// Retained capability for one unpublished HumanIO sensor candidate.
///
/// The public surface contains identity only. The exact Metal allocations and
/// the object that owns the HumanIO candidate stay internal so callers cannot
/// substitute a published sensor packet or expose candidate addresses as
/// accepted Brain authority. Construction consumes exactly one retained,
/// versioned HumanIO bridge view; there is no production initializer that can
/// pair arbitrary raw sensors with unrelated HumanIO scalar metadata.
@available(macOS 26.0, *)
public final class MetalNumanXPendingSensorCandidateLease:
  @unchecked Sendable
{
  private static let fingerprintDomain: UInt32 = 0x4e58_5343  // "NXSC"
  private static let fnvOffset: UInt64 = 14_695_981_039_346_656_037
  private static let fnvPrime: UInt64 = 1_099_511_628_211

  public let transactionFingerprint: UInt64
  public let acceptedBrainGeneration: UInt64
  public let sensorGeneration: UInt64
  public let humanIOProgramFingerprint: UInt64
  public let sensorFingerprint: UInt64
  public let transactionInstanceFingerprint: UInt64
  public let candidateKey: MetalNumanXHumanIOCandidateKey
  public let candidateKeyFingerprint: UInt64
  public let candidatePublicationFingerprint: UInt64
  public let candidateIdentityFingerprint: UInt64
  public let publicationFingerprint: UInt64
  let rawSensors: [MetalRawSensorBufferLease]
  private let sensorChannels: [MetalNumanXHumanIOSensorCandidateChannel]
  private let bridgeCandidate: MetalNumanXHumanIOPendingCandidateView
  let deviceRegistryID: UInt64
  private let rangeBindings: [SensorRangeBinding]

  private struct SensorRangeBinding: Equatable, Sendable {
    let modality: UInt32
    let valueObjectIdentity: UInt64
    let valueGPUAddress: UInt64
    let valueByteCount: UInt64
    let validityObjectIdentity: UInt64
    let validityGPUAddress: UInt64
    let validityByteCount: UInt64
  }

  @_spi(NumanXInterop)
  public init(
    bridgeCandidate: MetalNumanXHumanIOPendingCandidateView
  ) throws {
    let transactionFingerprint = bridgeCandidate.transactionFingerprint
    let acceptedBrainGeneration = bridgeCandidate.acceptedBrainGeneration
    let sensorGeneration = bridgeCandidate.sensorGeneration
    let humanIOProgramFingerprint = bridgeCandidate.humanIOProgramFingerprint
    let sensorFingerprint = bridgeCandidate.sensorFingerprint
    let transactionInstanceFingerprint =
      bridgeCandidate.transactionInstanceFingerprint
    let candidateKey = bridgeCandidate.candidateKey
    let candidatePublicationFingerprint =
      bridgeCandidate.candidatePublicationFingerprint
    let candidateIdentityFingerprint = bridgeCandidate.candidateIdentityFingerprint
    let rawSensors = bridgeCandidate.rawSensors
    let sorted = rawSensors.sorted {
      $0.view.modality.rawValue < $1.view.modality.rawValue
    }
    guard transactionFingerprint > 0, acceptedBrainGeneration > 0,
      sensorGeneration > 0, humanIOProgramFingerprint > 0,
      sensorFingerprint > 0, transactionInstanceFingerprint > 0,
      candidatePublicationFingerprint > 0, candidateIdentityFingerprint > 0,
      candidateKey.transactionFingerprint == transactionFingerprint,
      candidateKey.programFingerprint == humanIOProgramFingerprint,
      candidateKey.sensorFingerprint == sensorFingerprint,
      candidateKey.transactionInstanceFingerprint
        == transactionInstanceFingerprint,
      candidateKey.sensorGeneration == sensorGeneration,
      let first = sorted.first,
      zip(sorted, sorted.dropFirst()).allSatisfy({
        $0.view.modality != $1.view.modality
      })
    else {
      throw TissueError.transaction(
        "NumanX pending sensor candidate identity is incomplete"
      )
    }
    let registryID = first.buffer.device.registryID
    let bindings = sorted.map(Self.makeRangeBinding)
    guard sorted.allSatisfy({ lease in
      lease.buffer.device.registryID == registryID
        && (lease.validityBuffer == nil
          || lease.validityBuffer!.device.registryID == registryID)
        && lease.buffer.gpuAddress == lease.view.gpuAddress
        && lease.buffer.length == lease.view.byteCount
        && (lease.validityBuffer?.gpuAddress ?? 0)
          == lease.view.validityGPUAddress
        && (lease.validityBuffer?.length ?? 0)
          == lease.view.validityByteCount
    }), Self.rangesArePairwiseDisjoint(bindings) else {
      throw TissueError.transaction(
        "NumanX pending sensor candidate Metal residency is stale"
      )
    }

    self.transactionFingerprint = transactionFingerprint
    self.acceptedBrainGeneration = acceptedBrainGeneration
    self.sensorGeneration = sensorGeneration
    self.humanIOProgramFingerprint = humanIOProgramFingerprint
    self.sensorFingerprint = sensorFingerprint
    self.transactionInstanceFingerprint = transactionInstanceFingerprint
    self.candidateKey = candidateKey
    candidateKeyFingerprint = candidateKey.fingerprint
    self.candidatePublicationFingerprint = candidatePublicationFingerprint
    self.candidateIdentityFingerprint = candidateIdentityFingerprint
    self.rawSensors = sorted
    sensorChannels = bridgeCandidate.channels
    self.bridgeCandidate = bridgeCandidate
    deviceRegistryID = registryID
    rangeBindings = bindings
    publicationFingerprint = Self.makeFingerprint(
      transactionFingerprint: transactionFingerprint,
      acceptedBrainGeneration: acceptedBrainGeneration,
      sensorGeneration: sensorGeneration,
      humanIOProgramFingerprint: humanIOProgramFingerprint,
      sensorFingerprint: sensorFingerprint,
      transactionInstanceFingerprint: transactionInstanceFingerprint,
      candidateKeyFingerprint: candidateKey.fingerprint,
      candidatePublicationFingerprint: candidatePublicationFingerprint,
      candidateIdentityFingerprint: candidateIdentityFingerprint,
      deviceRegistryID: registryID,
      sensorChannels: sensorChannels,
      rawSensors: sorted,
      rangeBindings: bindings
    )
  }

  func validate(
    identity: MetalNumanXHumanMatterRootIdentity,
    provisional: BrainProvisionalPhysicsAcceptance,
    deviceRegistryID: UInt64
  ) throws {
    guard self.deviceRegistryID == deviceRegistryID,
      transactionFingerprint == identity.transactionFingerprint,
      transactionFingerprint == provisional.transactionFingerprint,
      acceptedBrainGeneration == provisional.shadowGeneration,
      publicationFingerprint > 0,
      candidateKeyFingerprint == candidateKey.fingerprint,
      candidatePublicationFingerprint > 0,
      candidateIdentityFingerprint > 0,
      sensorChannels.allSatisfy({
        $0.deliveryTimestamp == provisional.acceptedTimestamp
      }),
      zip(rawSensors, rangeBindings).allSatisfy({ lease, binding in
        Self.makeRangeBinding(lease) == binding
      }),
      identity.environment == provisional.environmentIdentifier,
      identity.controlStep == provisional.controlStep,
      identity.substepIndex == provisional.substepIndex,
      identity.physicsSubstepCount == 1
    else {
      throw TissueError.transaction(
        "NumanX pending sensor candidate does not match the prepared root"
      )
    }
  }

  static func jointCloseFingerprint(
    receiptFingerprint: UInt64,
    sensorCandidateFingerprint: UInt64
  ) -> UInt64 {
    precondition(receiptFingerprint > 0 && sensorCandidateFingerprint > 0)
    var hash = fnvOffset
    mix(UInt32(0x4e58_4a43), into: &hash)  // "NXJC"
    mix(receiptFingerprint, into: &hash)
    mix(sensorCandidateFingerprint, into: &hash)
    return hash == 0 ? fnvOffset : hash
  }

  private static func makeFingerprint(
    transactionFingerprint: UInt64,
    acceptedBrainGeneration: UInt64,
    sensorGeneration: UInt64,
    humanIOProgramFingerprint: UInt64,
    sensorFingerprint: UInt64,
    transactionInstanceFingerprint: UInt64,
    candidateKeyFingerprint: UInt64,
    candidatePublicationFingerprint: UInt64,
    candidateIdentityFingerprint: UInt64,
    deviceRegistryID: UInt64,
    sensorChannels: [MetalNumanXHumanIOSensorCandidateChannel],
    rawSensors: [MetalRawSensorBufferLease],
    rangeBindings: [SensorRangeBinding]
  ) -> UInt64 {
    var hash = fnvOffset
    mix(fingerprintDomain, into: &hash)
    mix(transactionFingerprint, into: &hash)
    mix(acceptedBrainGeneration, into: &hash)
    mix(sensorGeneration, into: &hash)
    mix(humanIOProgramFingerprint, into: &hash)
    mix(sensorFingerprint, into: &hash)
    mix(transactionInstanceFingerprint, into: &hash)
    mix(candidateKeyFingerprint, into: &hash)
    mix(candidatePublicationFingerprint, into: &hash)
    mix(candidateIdentityFingerprint, into: &hash)
    mix(deviceRegistryID, into: &hash)
    mix(UInt32(sensorChannels.count), into: &hash)
    for channel in sensorChannels {
      mix(UInt32(channel.modality.rawValue), into: &hash)
      mix(channel.receptorTimestamp.rawValue, into: &hash)
      mix(channel.deliveryTimestamp.rawValue, into: &hash)
      mix(channel.latencyMicroseconds, into: &hash)
      mix(channel.sampleIntervalMicroseconds, into: &hash)
    }
    mix(UInt32(rawSensors.count), into: &hash)
    for (lease, binding) in zip(rawSensors, rangeBindings) {
      let view = lease.view
      mix(UInt32(view.modality.rawValue), into: &hash)
      mix(view.receptorTimestamp.rawValue, into: &hash)
      mix(view.receptorCount, into: &hash)
      mix(view.featureDimension, into: &hash)
      mix(UInt64(view.byteCount), into: &hash)
      mix(UInt64(view.validityByteCount), into: &hash)
      mix(binding.valueObjectIdentity, into: &hash)
      mix(binding.valueGPUAddress, into: &hash)
      mix(binding.valueByteCount, into: &hash)
      mix(UInt32(1), into: &hash)  // canonical candidate value: float32
      mix(UInt32(MemoryLayout<Float>.stride), into: &hash)
      mix(binding.validityObjectIdentity, into: &hash)
      mix(binding.validityGPUAddress, into: &hash)
      mix(binding.validityByteCount, into: &hash)
      mix(UInt32(binding.validityByteCount == 0 ? 0 : 2), into: &hash)
      mix(
        UInt32(binding.validityByteCount == 0
          ? 0 : MemoryLayout<UInt32>.stride),
        into: &hash
      )
    }
    return hash == 0 ? fnvOffset : hash
  }

  private static func mix(_ value: UInt32, into hash: inout UInt64) {
    for shift in stride(from: 0, to: 32, by: 8) {
      hash = (hash ^ UInt64((value >> UInt32(shift)) & 0xff)) &* fnvPrime
    }
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    for shift in stride(from: 0, to: 64, by: 8) {
      hash = (hash ^ ((value >> UInt64(shift)) & 0xff)) &* fnvPrime
    }
  }

  private static func makeRangeBinding(
    _ lease: MetalRawSensorBufferLease
  ) -> SensorRangeBinding {
    SensorRangeBinding(
      modality: UInt32(lease.view.modality.rawValue),
      valueObjectIdentity: objectIdentity(lease.buffer as AnyObject),
      valueGPUAddress: lease.view.gpuAddress,
      valueByteCount: UInt64(lease.view.byteCount),
      validityObjectIdentity: lease.validityBuffer.map {
        objectIdentity($0 as AnyObject)
      } ?? 0,
      validityGPUAddress: lease.view.validityGPUAddress,
      validityByteCount: UInt64(lease.view.validityByteCount)
    )
  }

  private static func objectIdentity(_ object: AnyObject) -> UInt64 {
    UInt64(
      UInt(bitPattern: Unmanaged.passUnretained(object).toOpaque())
    )
  }

  private static func rangesArePairwiseDisjoint(
    _ bindings: [SensorRangeBinding]
  ) -> Bool {
    var intervals: [(UInt64, UInt64)] = []
    for binding in bindings {
      for (start, count) in [
        (binding.valueGPUAddress, binding.valueByteCount),
        (binding.validityGPUAddress, binding.validityByteCount),
      ] where count > 0 {
        let (end, overflow) = start.addingReportingOverflow(count)
        guard start > 0, !overflow, end > start,
          intervals.allSatisfy({ !(start < $0.1 && $0.0 < end) })
        else { return false }
        intervals.append((start, end))
      }
    }
    return true
  }
}
