import Foundation
import NumiBrainABI
import NumiBrainCore

/// Stable transaction-local metadata for causal NumanX receptor buffers.
/// The values authenticate GPU addresses and timing only; buffer contents
/// remain NumanX-owned physical sensor output.
public struct NumanXSensorPacket: Equatable, Sendable {
  public static let formatVersion = UInt32(NB_NUMANX_SENSOR_PACKET_VERSION)
  public static let byteCount = Int(NB_NUMANX_SENSOR_PACKET_BYTE_COUNT)
  public static let channelByteCount = Int(NB_NUMANX_SENSOR_CHANNEL_BYTE_COUNT)

  public let transactionFingerprint: UInt64
  public let acceptedPhysicsTokenFingerprint: UInt64
  public let deliveryTimestamp: BrainTimestamp
  public let physicsGeneration: UInt64
  public let speciesTemplateFingerprint: UInt64
  public let sensoryProfileFingerprint: UInt64
  public let environmentIdentifier: UInt32
  public let rawSensorViews: [MetalRawSensorBufferView]
  public let fingerprint: UInt64

  public var isAcceptedState: Bool { acceptedPhysicsTokenFingerprint != 0 }

  public init(
    transaction: BrainJointTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken? = nil,
    species: SpeciesTemplate,
    profile: SensoryTransductionProfile,
    rawSensorViews: [MetalRawSensorBufferView]
  ) throws {
    let deliveryTimestamp = acceptedPhysicsState?.acceptedTimestamp
      ?? transaction.committedTimestamp
    let physicsGeneration = acceptedPhysicsState?.physicsGeneration
      ?? transaction.basePhysicsGeneration
    let acceptedFingerprint = acceptedPhysicsState?.fingerprint ?? 0
    let enabledSenses = species.senses.filter(\.enabled)
    let topologyByModality = Dictionary(
      uniqueKeysWithValues: enabledSenses.map { ($0.modality, $0) }
    )
    let sortedViews = rawSensorViews.sorted {
      $0.modality.rawValue < $1.modality.rawValue
    }
    guard profile.speciesTemplateFingerprint == species.fingerprint,
      acceptedPhysicsState == nil
        || (
          acceptedPhysicsState?.transactionFingerprint == transaction.fingerprint
            && acceptedPhysicsState?.acceptedTimestamp == transaction.targetTimestamp
            && acceptedPhysicsState?.environmentIdentifier
              == transaction.environmentIdentifier
        ),
      Set(sortedViews.map(\.modality)) == Set(enabledSenses.map(\.modality)),
      sortedViews.count <= 8
    else {
      throw TissueError.transaction(
        "NumanX sensor packet identity does not match the control root"
      )
    }
    for view in sortedViews {
      guard let topology = topologyByModality[view.modality],
        view.receptorCount == topology.receptorCount,
        view.featureDimension == topology.observationDimension,
        deliveryTimestamp.rawValue >= UInt64(topology.latencyMicroseconds),
        view.receptorTimestamp.rawValue
          == deliveryTimestamp.rawValue - UInt64(topology.latencyMicroseconds)
      else {
        throw TissueError.transaction(
          "NumanX receptor channel violates species latency or shape"
        )
      }
    }
    var root = transaction.abiRecord
    let accepted = acceptedPhysicsState?.abiRecord
    var record = NBNumanXSensorPacket()
    record.format_version = Self.formatVersion
    record.flags = UInt32(NB_NUMANX_SENSOR_PACKET_FLAG_VALID)
      | (acceptedPhysicsState == nil
        ? 0 : UInt32(NB_NUMANX_SENSOR_PACKET_FLAG_ACCEPTED_STATE))
    record.transaction_fingerprint = transaction.fingerprint
    record.accepted_physics_token_fingerprint = acceptedFingerprint
    record.delivery_timestamp_microseconds = deliveryTimestamp.rawValue
    record.physics_generation = physicsGeneration
    record.species_template_fingerprint = species.fingerprint
    record.sensory_profile_fingerprint = profile.fingerprint
    record.environment_identifier = transaction.environmentIdentifier
    record.channel_count = UInt32(sortedViews.count)
    let channels = try Self.makeChannelRecords(
      views: sortedViews,
      topologyByModality: topologyByModality,
      deliveryTimestamp: deliveryTimestamp
    )
    record.packet_fingerprint = channels.withUnsafeBufferPointer { channels in
      withUnsafePointer(to: &record) {
        nb_brain_abi_numanx_sensor_packet_fingerprint($0, channels.baseAddress)
      }
    }
    let validation = channels.withUnsafeBufferPointer { channels in
      withUnsafePointer(to: &root) { root in
        withUnsafePointer(to: &record) { packet in
          if var accepted {
            return withUnsafePointer(to: &accepted) {
              nb_brain_abi_validate_numanx_sensor_packet(
                root, $0, packet, channels.baseAddress
              )
            }
          }
          return nb_brain_abi_validate_numanx_sensor_packet(
            root, nil, packet, channels.baseAddress
          )
        }
      }
    }
    guard validation == UInt32(NB_NUMANX_SENSOR_PACKET_VALID.rawValue) else {
      throw TissueError.transaction(
        "compiled NumanX sensor packet validation failed with code \(validation)"
      )
    }
    transactionFingerprint = transaction.fingerprint
    acceptedPhysicsTokenFingerprint = acceptedFingerprint
    self.deliveryTimestamp = deliveryTimestamp
    self.physicsGeneration = physicsGeneration
    speciesTemplateFingerprint = species.fingerprint
    sensoryProfileFingerprint = profile.fingerprint
    environmentIdentifier = transaction.environmentIdentifier
    self.rawSensorViews = sortedViews
    fingerprint = record.packet_fingerprint
  }

  public init(
    validating record: NBNumanXSensorPacket,
    channels: [NBNumanXSensorChannel],
    transaction: BrainJointTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken? = nil
  ) throws {
    guard channels.count == Int(record.channel_count) else {
      throw TissueError.transaction("NumanX sensor channel count is inconsistent")
    }
    var root = transaction.abiRecord
    let accepted = acceptedPhysicsState?.abiRecord
    var record = record
    let channels = channels
    let validation = channels.withUnsafeBufferPointer { channels in
      withUnsafePointer(to: &root) { root in
        withUnsafePointer(to: &record) { packet in
          if var accepted {
            return withUnsafePointer(to: &accepted) {
              nb_brain_abi_validate_numanx_sensor_packet(
                root, $0, packet, channels.baseAddress
              )
            }
          }
          return nb_brain_abi_validate_numanx_sensor_packet(
            root, nil, packet, channels.baseAddress
          )
        }
      }
    }
    guard validation == UInt32(NB_NUMANX_SENSOR_PACKET_VALID.rawValue) else {
      throw TissueError.transaction(
        "compiled NumanX sensor packet validation failed with code \(validation)"
      )
    }
    let views = try channels.map { channel -> MetalRawSensorBufferView in
      guard let modality = SensoryModality(
        rawValue: UInt16(channel.modality)
      ) else {
        throw TissueError.transaction("NumanX sensor modality is unknown")
      }
      return try MetalRawSensorBufferView(
        modality: modality,
        gpuAddress: channel.gpu_address,
        byteCount: Int(channel.byte_count),
        receptorTimestamp: BrainTimestamp(
          microseconds: channel.receptor_timestamp_microseconds
        ),
        receptorCount: channel.receptor_count,
        featureDimension: channel.feature_dimension,
        validityGPUAddress: channel.validity_gpu_address,
        validityByteCount: Int(channel.validity_byte_count)
      )
    }
    transactionFingerprint = record.transaction_fingerprint
    acceptedPhysicsTokenFingerprint =
      record.accepted_physics_token_fingerprint
    deliveryTimestamp = BrainTimestamp(
      microseconds: record.delivery_timestamp_microseconds
    )
    physicsGeneration = record.physics_generation
    speciesTemplateFingerprint = record.species_template_fingerprint
    sensoryProfileFingerprint = record.sensory_profile_fingerprint
    environmentIdentifier = record.environment_identifier
    rawSensorViews = views
    fingerprint = record.packet_fingerprint
  }

  public var abiRecord: NBNumanXSensorPacket {
    var record = NBNumanXSensorPacket()
    record.format_version = Self.formatVersion
    record.flags = UInt32(NB_NUMANX_SENSOR_PACKET_FLAG_VALID)
      | (isAcceptedState
        ? UInt32(NB_NUMANX_SENSOR_PACKET_FLAG_ACCEPTED_STATE) : 0)
    record.transaction_fingerprint = transactionFingerprint
    record.accepted_physics_token_fingerprint =
      acceptedPhysicsTokenFingerprint
    record.delivery_timestamp_microseconds = deliveryTimestamp.rawValue
    record.physics_generation = physicsGeneration
    record.species_template_fingerprint = speciesTemplateFingerprint
    record.sensory_profile_fingerprint = sensoryProfileFingerprint
    record.environment_identifier = environmentIdentifier
    record.channel_count = UInt32(rawSensorViews.count)
    record.packet_fingerprint = fingerprint
    return record
  }

  public var abiChannels: [NBNumanXSensorChannel] {
    rawSensorViews.map { view in
      var channel = NBNumanXSensorChannel()
      channel.modality = UInt32(view.modality.rawValue)
      channel.flags = UInt32(NB_NUMANX_SENSOR_CHANNEL_FLAG_VALID)
        | (view.hasValidity
          ? UInt32(NB_NUMANX_SENSOR_CHANNEL_FLAG_HAS_VALIDITY) : 0)
      channel.gpu_address = view.gpuAddress
      channel.receptor_timestamp_microseconds = view.receptorTimestamp.rawValue
      channel.byte_count = UInt32(
        Int(view.receptorCount) * Int(view.featureDimension)
          * MemoryLayout<Float>.stride
      )
      channel.receptor_count = view.receptorCount
      channel.feature_dimension = view.featureDimension
      channel.latency_microseconds = UInt32(
        deliveryTimestamp.rawValue - view.receptorTimestamp.rawValue
      )
      channel.validity_gpu_address = view.validityGPUAddress
      channel.validity_byte_count = UInt32(view.hasValidity
        ? Int(view.receptorCount) * MemoryLayout<UInt32>.stride : 0)
      channel.reserved = 0
      return channel
    }
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }

  private static func makeChannelRecords(
    views: [MetalRawSensorBufferView],
    topologyByModality: [SensoryModality: SensoryTopology],
    deliveryTimestamp: BrainTimestamp
  ) throws -> [NBNumanXSensorChannel] {
    try views.map { view in
      guard let topology = topologyByModality[view.modality] else {
        throw TissueError.transaction("NumanX sensor topology is absent")
      }
      let scalarCount = UInt64(view.receptorCount)
        * UInt64(view.featureDimension)
      let byteCount = scalarCount * UInt64(MemoryLayout<Float>.stride)
      let validityByteCount = UInt64(view.receptorCount)
        * UInt64(MemoryLayout<UInt32>.stride)
      guard byteCount > 0, byteCount <= UInt64(UInt32.max),
        !view.hasValidity || validityByteCount <= UInt64(UInt32.max),
        UInt64(topology.latencyMicroseconds)
          == deliveryTimestamp.rawValue - view.receptorTimestamp.rawValue
      else {
        throw TissueError.transaction("NumanX sensor channel exceeds ABI capacity")
      }
      var channel = NBNumanXSensorChannel()
      channel.modality = UInt32(view.modality.rawValue)
      channel.flags = UInt32(NB_NUMANX_SENSOR_CHANNEL_FLAG_VALID)
        | (view.hasValidity
          ? UInt32(NB_NUMANX_SENSOR_CHANNEL_FLAG_HAS_VALIDITY) : 0)
      channel.gpu_address = view.gpuAddress
      channel.receptor_timestamp_microseconds = view.receptorTimestamp.rawValue
      channel.byte_count = UInt32(byteCount)
      channel.receptor_count = view.receptorCount
      channel.feature_dimension = view.featureDimension
      channel.latency_microseconds = topology.latencyMicroseconds
      channel.validity_gpu_address = view.validityGPUAddress
      channel.validity_byte_count = view.hasValidity
        ? UInt32(validityByteCount) : 0
      channel.reserved = 0
      return channel
    }
  }
}

/// Owns the Metal allocations referenced by one validated NumanX sensor
/// packet. Keeping this lease alive is the residency/lifetime contract for a
/// zero-copy brain control or accepted-consequence encode.
@available(macOS 26.0, *)
public final class NumanXSensorPacketLease: @unchecked Sendable {
  public let packet: NumanXSensorPacket
  public let rawSensors: [MetalRawSensorBufferLease]

  public init(
    transaction: BrainJointTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken? = nil,
    species: SpeciesTemplate,
    profile: SensoryTransductionProfile,
    rawSensors: [MetalRawSensorBufferLease]
  ) throws {
    packet = try NumanXSensorPacket(
      transaction: transaction,
      acceptedPhysicsState: acceptedPhysicsState,
      species: species,
      profile: profile,
      rawSensorViews: rawSensors.map(\.view)
    )
    self.rawSensors = rawSensors.sorted {
      $0.view.modality.rawValue < $1.view.modality.rawValue
    }
  }

  /// Imports a packet emitted by an external same-process NumanX bridge and
  /// binds it to the Metal objects that keep every advertised GPU address
  /// resident. Metadata and actual allocation views must agree byte-for-byte.
  public init(
    validating record: NBNumanXSensorPacket,
    channels: [NBNumanXSensorChannel],
    transaction: BrainJointTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken? = nil,
    rawSensors: [MetalRawSensorBufferLease]
  ) throws {
    let packet = try NumanXSensorPacket(
      validating: record,
      channels: channels,
      transaction: transaction,
      acceptedPhysicsState: acceptedPhysicsState
    )
    let sortedSensors = rawSensors.sorted {
      $0.view.modality.rawValue < $1.view.modality.rawValue
    }
    guard packet.rawSensorViews == sortedSensors.map(\.view) else {
      throw TissueError.transaction(
        "NumanX sensor packet does not name the leased Metal allocations"
      )
    }
    self.packet = packet
    self.rawSensors = sortedSensors
  }
}
