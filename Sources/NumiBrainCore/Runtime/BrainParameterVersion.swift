import Foundation
import NumiBrainABI

@frozen
public enum BrainParameterComponentKind: UInt16, Codable, CaseIterable, Sendable {
  case sensory = 1
  case belief = 2
  case world = 3
  case route = 4
  case memory = 5
  case value = 6
  case policy = 7
  case motor = 8
  case cerebellar = 9
  case plasticity = 10
  case tissueDynamics = 11
  case regionalOperator = 12
  case regionalDense = 13
}

@frozen
public enum BrainParameterElementType: UInt16, Codable, CaseIterable, Sendable {
  case fp16 = 1
  case bf16 = 2
  case fp32 = 3
  case int8 = 4
  case opaque = 5
}

/// One canonical component of an immutable shared-parameter generation.
@frozen
public struct BrainParameterComponent: Codable, Equatable, Hashable, Sendable {
  public let kind: BrainParameterComponentKind
  public let elementType: BrainParameterElementType
  public let flags: UInt32
  public let elementCount: UInt64
  public let byteCount: UInt64
  public let contentFingerprint: UInt64

  public init(
    kind: BrainParameterComponentKind,
    elementType: BrainParameterElementType,
    flags: UInt32 = 0,
    elementCount: UInt64,
    byteCount: UInt64,
    contentFingerprint: UInt64
  ) throws {
    guard elementCount > 0, byteCount > 0, contentFingerprint > 0 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "component count, bytes, and fingerprint must be nonzero"
      )
    }
    self.kind = kind
    self.elementType = elementType
    self.flags = flags
    self.elementCount = elementCount
    self.byteCount = byteCount
    self.contentFingerprint = contentFingerprint
  }

  public var abiRecord: NBParameterComponent {
    var record = NBParameterComponent()
    record.component_kind = kind.rawValue
    record.element_type = elementType.rawValue
    record.flags = flags
    record.element_count = elementCount
    record.byte_count = byteCount
    record.content_fingerprint = contentFingerprint
    return record
  }
}

/// A content-addressed, immutable parameter generation. The binding separates
/// rollout-owned recurrent state from shared slow parameters and makes the
/// active version part of deterministic checkpoint/replay identity.
@frozen
public struct BrainParameterVersion: Codable, Equatable, Hashable, Sendable {
  public static let manifestVersion = UInt32(NB_PARAMETER_MANIFEST_VERSION)
  public static let componentByteCount = Int(NB_PARAMETER_COMPONENT_BYTE_COUNT)
  public static let bindingByteCount = Int(NB_PARAMETER_VERSION_BINDING_BYTE_COUNT)

  public let sequence: UInt64
  public let fingerprint: UInt64
  public let parentFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let regionalShapeFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let totalParameterBytes: UInt64
  public let components: [BrainParameterComponent]

  public init(
    sequence: UInt64,
    parentFingerprint: UInt64,
    scheduleFingerprint: UInt64,
    regionalShapeFingerprint: UInt64,
    regionalProgramFingerprint: UInt64,
    components: [BrainParameterComponent]
  ) throws {
    guard components.count <= Int(UInt32.max) else {
      throw BrainRuntimeError.invalidParameterVersion("component count exceeds the ABI limit")
    }
    let canonical = components.sorted { $0.kind.rawValue < $1.kind.rawValue }
    guard Set(canonical.map(\.kind)).count == canonical.count else {
      throw BrainRuntimeError.invalidParameterVersion("component kinds must be unique")
    }
    guard canonical.contains(where: { $0.kind == .regionalOperator }) else {
      throw BrainRuntimeError.invalidParameterVersion(
        "regional operator component is required by the runtime binding"
      )
    }
    var totalBytes: UInt64 = 0
    for component in canonical {
      let (next, overflow) = totalBytes.addingReportingOverflow(component.byteCount)
      guard !overflow else {
        throw BrainRuntimeError.invalidParameterVersion("parameter byte count overflows UInt64")
      }
      totalBytes = next
    }
    var binding = NBParameterVersionBinding()
    binding.format_version = Self.manifestVersion
    binding.component_count = UInt32(canonical.count)
    binding.version_sequence = sequence
    binding.version_fingerprint = 0
    binding.parent_version_fingerprint = parentFingerprint
    binding.schedule_fingerprint = scheduleFingerprint
    binding.regional_shape_fingerprint = regionalShapeFingerprint
    binding.regional_program_fingerprint = regionalProgramFingerprint
    binding.total_parameter_bytes = totalBytes
    let records = canonical.map(\.abiRecord)
    binding.version_fingerprint = records.withUnsafeBufferPointer { records in
      withUnsafePointer(to: &binding) { binding in
        nb_brain_abi_parameter_version_fingerprint(binding, records.baseAddress)
      }
    }
    let validation = records.withUnsafeBufferPointer { records in
      withUnsafePointer(to: &binding) { binding in
        nb_brain_abi_validate_parameter_version(binding, records.baseAddress)
      }
    }
    guard validation == UInt32(NB_PARAMETER_VERSION_VALID.rawValue) else {
      throw BrainRuntimeError.invalidParameterVersion(
        "compiled ABI validation failed with code \(validation)"
      )
    }
    self.sequence = sequence
    self.fingerprint = binding.version_fingerprint
    self.parentFingerprint = parentFingerprint
    self.scheduleFingerprint = scheduleFingerprint
    self.regionalShapeFingerprint = regionalShapeFingerprint
    self.regionalProgramFingerprint = regionalProgramFingerprint
    self.totalParameterBytes = totalBytes
    self.components = canonical
  }

  private enum CodingKeys: String, CodingKey {
    case sequence
    case fingerprint
    case parentFingerprint
    case scheduleFingerprint
    case regionalShapeFingerprint
    case regionalProgramFingerprint
    case totalParameterBytes
    case components
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let decoded = try BrainParameterVersion(
      sequence: values.decode(UInt64.self, forKey: .sequence),
      parentFingerprint: values.decode(UInt64.self, forKey: .parentFingerprint),
      scheduleFingerprint: values.decode(UInt64.self, forKey: .scheduleFingerprint),
      regionalShapeFingerprint: values.decode(UInt64.self, forKey: .regionalShapeFingerprint),
      regionalProgramFingerprint: values.decode(
        UInt64.self,
        forKey: .regionalProgramFingerprint
      ),
      components: values.decode([BrainParameterComponent].self, forKey: .components)
    )
    let encodedFingerprint = try values.decode(UInt64.self, forKey: .fingerprint)
    let encodedTotalBytes = try values.decode(UInt64.self, forKey: .totalParameterBytes)
    guard decoded.fingerprint == encodedFingerprint,
      decoded.totalParameterBytes == encodedTotalBytes
    else {
      throw BrainRuntimeError.invalidParameterVersion("encoded parameter identity mismatch")
    }
    self = decoded
  }

  public var abiBinding: NBParameterVersionBinding {
    var record = NBParameterVersionBinding()
    record.format_version = Self.manifestVersion
    record.component_count = UInt32(components.count)
    record.version_sequence = sequence
    record.version_fingerprint = fingerprint
    record.parent_version_fingerprint = parentFingerprint
    record.schedule_fingerprint = scheduleFingerprint
    record.regional_shape_fingerprint = regionalShapeFingerprint
    record.regional_program_fingerprint = regionalProgramFingerprint
    record.total_parameter_bytes = totalParameterBytes
    return record
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }
  public var parentFingerprintHex: String { String(format: "%016llx", parentFingerprint) }

  public func successor(
    regionalProgramFingerprint: UInt64,
    components: [BrainParameterComponent]
  ) throws -> BrainParameterVersion {
    let (nextSequence, overflow) = sequence.addingReportingOverflow(1)
    guard !overflow else {
      throw BrainRuntimeError.invalidParameterVersion("parameter sequence overflows UInt64")
    }
    return try BrainParameterVersion(
      sequence: nextSequence,
      parentFingerprint: fingerprint,
      scheduleFingerprint: scheduleFingerprint,
      regionalShapeFingerprint: regionalShapeFingerprint,
      regionalProgramFingerprint: regionalProgramFingerprint,
      components: components
    )
  }

  public static func runtimeFoundationV0(
    schedule: BrainModuleSchedule,
    regionalProgram: RegionalTokenProgram,
    tissueParameters: TissueParameters
  ) throws -> BrainParameterVersion {
    guard regionalProgram.scheduleFingerprint == schedule.fingerprint else {
      throw BrainRuntimeError.invalidParameterVersion(
        "regional program does not match the schedule"
      )
    }
    try tissueParameters.validate()
    let tissueComponent = try BrainParameterComponent(
      kind: .tissueDynamics,
      elementType: .fp32,
      elementCount: UInt64(tissueParameters.canonicalValues.count),
      byteCount: UInt64(tissueParameters.canonicalValues.count * MemoryLayout<Float>.stride),
      contentFingerprint: tissueParameters.parameterFingerprint
    )
    let regionalBytes =
      regionalProgram.parameters.count * MemoryLayout<NBRegionalTokenParameters>.stride
      + regionalProgram.routes.count * MemoryLayout<NBRegionalRoute>.stride
    let regionalComponent = try BrainParameterComponent(
      kind: .regionalOperator,
      elementType: .opaque,
      elementCount: UInt64(regionalProgram.parameters.count + regionalProgram.routes.count),
      byteCount: UInt64(regionalBytes),
      contentFingerprint: regionalProgram.fingerprint
    )
    let sharedComponents = try BrainSharedParameterArtifact.foundationPayloads(
      regionalDenseElementCount: regionalProgram.denseParameterCount
    ).map {
      try $0.component
    }
    return try BrainParameterVersion(
      sequence: 0,
      parentFingerprint: 0,
      scheduleFingerprint: schedule.fingerprint,
      regionalShapeFingerprint: regionalProgram.shapeFingerprint,
      regionalProgramFingerprint: regionalProgram.fingerprint,
      components: sharedComponents + [tissueComponent, regionalComponent]
    )
  }
}

@frozen
public struct BrainRolloutCohortLease: Equatable, Hashable, Sendable {
  public let identifier: UUID
  public let parameterFingerprint: UInt64

  fileprivate init(identifier: UUID, parameterFingerprint: UInt64) {
    self.identifier = identifier
    self.parameterFingerprint = parameterFingerprint
  }
}

/// Atomic slow-parameter publication consumed by a new rollout runtime. The
/// manifest and its exact shared bytes can never be observed from different
/// registry generations.
@frozen
public struct BrainParameterPublication: Equatable, Sendable {
  public let version: BrainParameterVersion
  public let sharedArtifact: BrainSharedParameterArtifact
  public let learnerUpdateFingerprint: UInt64
  public let sourceBatchFingerprint: UInt64
  public let sourceMindCount: UInt32
  public let minimumSourceGeneration: UInt64
  public let sourceGeneration: UInt64

  public init(
    version: BrainParameterVersion,
    sharedArtifact: BrainSharedParameterArtifact,
    learnerUpdateFingerprint: UInt64 = 0,
    sourceBatchFingerprint: UInt64 = 0,
    sourceMindCount: UInt32 = 0,
    minimumSourceGeneration: UInt64 = 0,
    sourceGeneration: UInt64 = 0
  ) throws {
    try sharedArtifact.validate(parameterVersion: version)
    let hasLearnerProvenance =
      learnerUpdateFingerprint > 0
      || sourceBatchFingerprint > 0 || sourceMindCount > 0
      || minimumSourceGeneration > 0 || sourceGeneration > 0
    guard
      !hasLearnerProvenance
        || (learnerUpdateFingerprint > 0 && sourceBatchFingerprint > 0
          && sourceMindCount > 0 && minimumSourceGeneration > 0
          && minimumSourceGeneration <= sourceGeneration)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "learner publication provenance must be complete"
      )
    }
    self.version = version
    self.sharedArtifact = sharedArtifact
    self.learnerUpdateFingerprint = learnerUpdateFingerprint
    self.sourceBatchFingerprint = sourceBatchFingerprint
    self.sourceMindCount = sourceMindCount
    self.minimumSourceGeneration = minimumSourceGeneration
    self.sourceGeneration = sourceGeneration
  }

  public init(
    parentVersion: BrainParameterVersion,
    learnerUpdate: BrainLearnerUpdate
  ) throws {
    try learnerUpdate.validate(parentVersion: parentVersion)
    try self.init(
      version: learnerUpdate.candidateVersion,
      sharedArtifact: learnerUpdate.sharedArtifact,
      learnerUpdateFingerprint: learnerUpdate.updateFingerprint,
      sourceBatchFingerprint: learnerUpdate.sourceBatchFingerprint,
      sourceMindCount: learnerUpdate.sourceMindCount,
      minimumSourceGeneration: learnerUpdate.minimumSourceGeneration,
      sourceGeneration: learnerUpdate.sourceGeneration
    )
  }
}

/// One immutable parameter publication and the exact registry lease that owns
/// it. Keeping these values together prevents a runtime from accidentally
/// pairing current parameter bytes with a lease issued for an older version.
@frozen
public struct BrainRolloutCohortBinding: Equatable, Sendable {
  public let publication: BrainParameterPublication
  public let lease: BrainRolloutCohortLease

  fileprivate init(
    publication: BrainParameterPublication,
    lease: BrainRolloutCohortLease
  ) throws {
    guard publication.version.fingerprint == lease.parameterFingerprint else {
      throw BrainRuntimeError.invalidParameterVersion(
        "cohort lease does not identify its immutable publication"
      )
    }
    self.publication = publication
    self.lease = lease
  }
}

/// Thread-safe publication boundary. A learner can construct a successor at
/// any time, but publication fails while a rollout cohort owns the current
/// immutable version.
public final class BrainParameterRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private var activeCohorts: [UUID: UInt64] = [:]
  private var storedVersion: BrainParameterVersion
  private var storedArtifact: BrainSharedParameterArtifact?
  private var storedLearnerUpdateFingerprint: UInt64 = 0
  private var storedSourceBatchFingerprint: UInt64 = 0
  private var storedSourceMindCount: UInt32 = 0
  private var storedMinimumSourceGeneration: UInt64 = 0
  private var storedSourceGeneration: UInt64 = 0

  public init(initialVersion: BrainParameterVersion) {
    storedVersion = initialVersion
    storedArtifact = try? BrainSharedParameterArtifact.foundation(
      parameterVersion: initialVersion
    )
  }

  public init(initialPublication: BrainParameterPublication) {
    storedVersion = initialPublication.version
    storedArtifact = initialPublication.sharedArtifact
    storedLearnerUpdateFingerprint = initialPublication.learnerUpdateFingerprint
    storedSourceBatchFingerprint = initialPublication.sourceBatchFingerprint
    storedSourceMindCount = initialPublication.sourceMindCount
    storedMinimumSourceGeneration = initialPublication.minimumSourceGeneration
    storedSourceGeneration = initialPublication.sourceGeneration
  }

  public var currentVersion: BrainParameterVersion {
    lock.withLock { storedVersion }
  }

  public var activeCohortCount: Int {
    lock.withLock { activeCohorts.count }
  }

  public func currentPublication() throws -> BrainParameterPublication {
    try lock.withLock {
      guard let storedArtifact else {
        throw BrainRuntimeError.invalidParameterVersion(
          "current parameter version has no exact shared artifact"
        )
      }
      return try BrainParameterPublication(
        version: storedVersion,
        sharedArtifact: storedArtifact,
        learnerUpdateFingerprint: storedLearnerUpdateFingerprint,
        sourceBatchFingerprint: storedSourceBatchFingerprint,
        sourceMindCount: storedSourceMindCount,
        minimumSourceGeneration: storedMinimumSourceGeneration,
        sourceGeneration: storedSourceGeneration
      )
    }
  }

  /// Acquires the exact current publication and its rollout lease while holding
  /// one registry lock. A caller can therefore never observe a publication and
  /// lease from different generations.
  public func beginPublishedCohort(
    identifier: UUID = UUID(),
    expectedVersionFingerprint: UInt64? = nil
  ) throws -> BrainRolloutCohortBinding {
    try lock.withLock {
      let publication = try storedPublicationLocked()
      let lease = try beginCohortLocked(
        identifier: identifier,
        expectedVersionFingerprint: expectedVersionFingerprint
      )
      return try BrainRolloutCohortBinding(
        publication: publication,
        lease: lease
      )
    }
  }

  public func beginCohort(
    identifier: UUID = UUID(),
    expectedVersionFingerprint: UInt64? = nil
  ) throws -> BrainRolloutCohortLease {
    try lock.withLock {
      try beginCohortLocked(
        identifier: identifier,
        expectedVersionFingerprint: expectedVersionFingerprint
      )
    }
  }

  public func endCohort(_ lease: BrainRolloutCohortLease) throws {
    try lock.withLock {
      guard activeCohorts[lease.identifier] == lease.parameterFingerprint else {
        throw BrainRuntimeError.invalidParameterVersion("cohort lease is stale or unknown")
      }
      activeCohorts.removeValue(forKey: lease.identifier)
    }
  }

  public func publish(_ candidate: BrainParameterVersion) throws {
    try lock.withLock {
      guard activeCohorts.isEmpty else {
        throw BrainRuntimeError.invalidParameterVersion(
          "cannot publish while a rollout cohort is active"
        )
      }
      let (expectedSequence, overflow) = storedVersion.sequence.addingReportingOverflow(1)
      guard !overflow,
        candidate.sequence == expectedSequence,
        candidate.parentFingerprint == storedVersion.fingerprint
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "candidate is not the direct successor of the current version"
        )
      }
      guard candidate.scheduleFingerprint == storedVersion.scheduleFingerprint,
        candidate.regionalShapeFingerprint == storedVersion.regionalShapeFingerprint
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "candidate changes rollout ABI shape or schedule"
        )
      }
      storedVersion = candidate
      storedArtifact = nil
      storedLearnerUpdateFingerprint = 0
      storedSourceBatchFingerprint = 0
      storedSourceMindCount = 0
      storedMinimumSourceGeneration = 0
      storedSourceGeneration = 0
    }
  }

  public func publish(_ update: BrainLearnerUpdate) throws {
    try lock.withLock {
      guard activeCohorts.isEmpty else {
        throw BrainRuntimeError.invalidParameterVersion(
          "cannot publish while a rollout cohort is active"
        )
      }
      try update.validate(parentVersion: storedVersion)
      let candidate = update.candidateVersion
      let (expectedSequence, overflow) = storedVersion.sequence.addingReportingOverflow(1)
      guard !overflow,
        candidate.sequence == expectedSequence,
        candidate.parentFingerprint == storedVersion.fingerprint,
        candidate.scheduleFingerprint == storedVersion.scheduleFingerprint,
        candidate.regionalShapeFingerprint == storedVersion.regionalShapeFingerprint
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "learner publication is not a shape-compatible direct successor"
        )
      }
      storedVersion = candidate
      storedArtifact = update.sharedArtifact
      storedLearnerUpdateFingerprint = update.updateFingerprint
      storedSourceBatchFingerprint = update.sourceBatchFingerprint
      storedSourceMindCount = update.sourceMindCount
      storedMinimumSourceGeneration = update.minimumSourceGeneration
      storedSourceGeneration = update.sourceGeneration
    }
  }

  /// Atomically closes the sole active cohort, publishes its learner update,
  /// and issues the direct-successor lease. There is no unlocked interval in
  /// which another cohort can acquire either the parent or successor version.
  /// The old lease becomes stale even though ownership retains its UUID.
  public func rotateCohort(
    _ lease: BrainRolloutCohortLease,
    publishing update: BrainLearnerUpdate
  ) throws -> BrainRolloutCohortBinding {
    try lock.withLock {
      guard activeCohorts.count == 1,
        activeCohorts[lease.identifier] == lease.parameterFingerprint,
        lease.parameterFingerprint == storedVersion.fingerprint
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "parameter rotation requires the sole current cohort lease"
        )
      }
      try update.validate(parentVersion: storedVersion)
      let publication = try BrainParameterPublication(
        parentVersion: storedVersion,
        learnerUpdate: update
      )
      guard publication.version.scheduleFingerprint == storedVersion.scheduleFingerprint,
        publication.version.regionalShapeFingerprint
          == storedVersion.regionalShapeFingerprint
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "learner rotation changes rollout ABI shape or schedule"
        )
      }

      activeCohorts.removeValue(forKey: lease.identifier)
      storedVersion = publication.version
      storedArtifact = publication.sharedArtifact
      storedLearnerUpdateFingerprint = publication.learnerUpdateFingerprint
      storedSourceBatchFingerprint = publication.sourceBatchFingerprint
      storedSourceMindCount = publication.sourceMindCount
      storedMinimumSourceGeneration = publication.minimumSourceGeneration
      storedSourceGeneration = publication.sourceGeneration

      let successorLease = BrainRolloutCohortLease(
        identifier: lease.identifier,
        parameterFingerprint: publication.version.fingerprint
      )
      activeCohorts[successorLease.identifier] = successorLease.parameterFingerprint
      return try BrainRolloutCohortBinding(
        publication: publication,
        lease: successorLease
      )
    }
  }

  private func storedPublicationLocked() throws -> BrainParameterPublication {
    guard let storedArtifact else {
      throw BrainRuntimeError.invalidParameterVersion(
        "current parameter version has no exact shared artifact"
      )
    }
    return try BrainParameterPublication(
      version: storedVersion,
      sharedArtifact: storedArtifact,
      learnerUpdateFingerprint: storedLearnerUpdateFingerprint,
      sourceBatchFingerprint: storedSourceBatchFingerprint,
      sourceMindCount: storedSourceMindCount,
      minimumSourceGeneration: storedMinimumSourceGeneration,
      sourceGeneration: storedSourceGeneration
    )
  }

  private func beginCohortLocked(
    identifier: UUID,
    expectedVersionFingerprint: UInt64?
  ) throws -> BrainRolloutCohortLease {
    guard activeCohorts[identifier] == nil else {
      throw BrainRuntimeError.invalidParameterVersion("cohort identifier is already active")
    }
    if let expectedVersionFingerprint,
      expectedVersionFingerprint != storedVersion.fingerprint
    {
      throw BrainRuntimeError.invalidParameterVersion("requested parameter version is stale")
    }
    activeCohorts[identifier] = storedVersion.fingerprint
    return BrainRolloutCohortLease(
      identifier: identifier,
      parameterFingerprint: storedVersion.fingerprint
    )
  }
}
