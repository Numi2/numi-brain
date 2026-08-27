import Foundation

@frozen
public struct BodyLoadEndpointRole: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let firstRouteEndpoint = Self(rawValue: 1 << 0)
  public static let terminalRouteEndpoint = Self(rawValue: 1 << 1)
}

/// Deterministic temporal policy for the accepted body-load field. Loads are
/// held at their accepted magnitude before linearly decaying to zero. This is
/// an initial runtime policy, not a calibrated tissue-damage model.
@frozen
public struct BodyLoadFieldDynamics: Codable, Equatable, Hashable, Sendable {
  public let persistenceMicroseconds: UInt32
  public let decayMicroseconds: UInt32

  public init(
    persistenceMicroseconds: UInt32,
    decayMicroseconds: UInt32
  ) throws {
    guard decayMicroseconds > 0 else {
      throw BrainRuntimeError.transaction("body-load decay duration must be positive")
    }
    self.persistenceMicroseconds = persistenceMicroseconds
    self.decayMicroseconds = decayMicroseconds
  }

  public static var runtimeFoundationV0: Self {
    get throws {
      try Self(
        persistenceMicroseconds: 40_000,
        decayMicroseconds: 160_000
      )
    }
  }

  public func retaining(
    _ cell: BodyLoadFieldCell,
    at targetTimestamp: BrainTimestamp
  ) throws -> BodyLoadFieldCell? {
    guard targetTimestamp >= cell.fieldStateTimestamp,
      targetTimestamp >= cell.fieldActivationTimestamp
    else {
      throw BrainRuntimeError.transaction("body-load field cannot move backward in time")
    }
    let age = targetTimestamp.rawValue - cell.fieldActivationTimestamp.rawValue
    let persistence = UInt64(persistenceMicroseconds)
    let decay = UInt64(decayMicroseconds)
    let (expiry, overflow) = persistence.addingReportingOverflow(decay)
    guard !overflow else {
      throw BrainRuntimeError.transaction("body-load field lifetime overflow")
    }
    let effectiveForce: Float
    if age <= persistence {
      effectiveForce = cell.maximumAbsoluteMuscleForce
    } else if age >= expiry {
      return nil
    } else {
      let remaining = Float(expiry - age) / Float(decay)
      effectiveForce = cell.maximumAbsoluteMuscleForce * remaining
    }
    return try BodyLoadFieldCell(
      bodyIdentifier: cell.bodyIdentifier,
      endpointRole: cell.endpointRole,
      sourceMuscleIdentifier: cell.sourceMuscleIdentifier,
      maximumAbsoluteMuscleForce: cell.maximumAbsoluteMuscleForce,
      acceptedTimestamp: cell.acceptedTimestamp,
      acceptedPhysicsStateFingerprint: cell.acceptedPhysicsStateFingerprint,
      effectiveAbsoluteMuscleForce: effectiveForce,
      fieldActivationTimestamp: cell.fieldActivationTimestamp,
      fieldStateTimestamp: targetTimestamp
    )
  }

  /// CPU oracle for the private Metal field update. Fresh updates are
  /// activated at `targetTimestamp`; retained cells preserve their original
  /// receptor and physical-state provenance.
  public func advance(
    previous: [BodyLoadFieldCell],
    updates: [BodyLoadFieldCell],
    bodyCount: UInt32,
    targetTimestamp: BrainTimestamp
  ) throws -> [BodyLoadFieldCell] {
    guard previous.allSatisfy({ $0.bodyIdentifier < bodyCount }),
      updates.allSatisfy({ $0.bodyIdentifier < bodyCount })
    else {
      throw BrainRuntimeError.transaction("body-load field body identifier is out of range")
    }
    var cells: [BodyLoadFieldCell] = []
    cells.reserveCapacity(previous.count + updates.count)
    for cell in previous {
      if let retained = try retaining(cell, at: targetTimestamp) {
        merge(retained, into: &cells)
      }
    }
    for update in updates {
      let activated = try BodyLoadFieldCell(
        bodyIdentifier: update.bodyIdentifier,
        endpointRole: update.endpointRole,
        sourceMuscleIdentifier: update.sourceMuscleIdentifier,
        maximumAbsoluteMuscleForce: update.maximumAbsoluteMuscleForce,
        acceptedTimestamp: update.acceptedTimestamp,
        acceptedPhysicsStateFingerprint: update.acceptedPhysicsStateFingerprint,
        effectiveAbsoluteMuscleForce: update.maximumAbsoluteMuscleForce,
        fieldActivationTimestamp: targetTimestamp,
        fieldStateTimestamp: targetTimestamp
      )
      merge(activated, into: &cells)
    }
    return cells.sorted { $0.bodyIdentifier < $1.bodyIdentifier }
  }

  private func merge(
    _ candidate: BodyLoadFieldCell,
    into cells: inout [BodyLoadFieldCell]
  ) {
    guard let index = cells.firstIndex(where: {
      $0.bodyIdentifier == candidate.bodyIdentifier
    }) else {
      cells.append(candidate)
      return
    }
    let current = cells[index]
    if Self.sameSource(candidate, current) {
      let freshest = candidate.fieldActivationTimestamp >= current.fieldActivationTimestamp
        ? candidate : current
      cells[index] = BodyLoadFieldCell(
        mergingEndpointRole: current.endpointRole.union(candidate.endpointRole),
        from: freshest
      )
    } else if Self.stronger(candidate, than: current) {
      cells[index] = candidate
    }
  }

  private static func sameSource(
    _ lhs: BodyLoadFieldCell,
    _ rhs: BodyLoadFieldCell
  ) -> Bool {
    lhs.bodyIdentifier == rhs.bodyIdentifier
      && lhs.sourceMuscleIdentifier == rhs.sourceMuscleIdentifier
      && lhs.maximumAbsoluteMuscleForce == rhs.maximumAbsoluteMuscleForce
      && lhs.acceptedTimestamp == rhs.acceptedTimestamp
      && lhs.acceptedPhysicsStateFingerprint == rhs.acceptedPhysicsStateFingerprint
  }

  private static func stronger(
    _ lhs: BodyLoadFieldCell,
    than rhs: BodyLoadFieldCell
  ) -> Bool {
    if lhs.effectiveAbsoluteMuscleForce != rhs.effectiveAbsoluteMuscleForce {
      return lhs.effectiveAbsoluteMuscleForce > rhs.effectiveAbsoluteMuscleForce
    }
    if lhs.acceptedTimestamp != rhs.acceptedTimestamp {
      return lhs.acceptedTimestamp > rhs.acceptedTimestamp
    }
    if lhs.sourceMuscleIdentifier != rhs.sourceMuscleIdentifier {
      return lhs.sourceMuscleIdentifier < rhs.sourceMuscleIdentifier
    }
    return lhs.acceptedPhysicsStateFingerprint < rhs.acceptedPhysicsStateFingerprint
  }
}

@frozen
public struct CommittedBodyLoadSample: Codable, Equatable, Hashable, Sendable {
  public let bodyIdentifier: UInt32
  public let endpointRole: BodyLoadEndpointRole
  public let sourceMuscleIdentifier: UInt32
  public let maximumAbsoluteMuscleForce: Float
  public let acceptedTimestamp: BrainTimestamp
  public let acceptedPhysicsStateFingerprint: UInt64

  fileprivate init(
    bodyIdentifier: UInt32,
    endpointRole: BodyLoadEndpointRole,
    observation: LocalizedMuscleLoadReceptorObservation
  ) {
    self.bodyIdentifier = bodyIdentifier
    self.endpointRole = endpointRole
    sourceMuscleIdentifier = observation.attachment.muscleIdentifier
    maximumAbsoluteMuscleForce = observation.maximumAbsoluteMuscleForce
    acceptedTimestamp = observation.event.timestamp
    acceptedPhysicsStateFingerprint = observation.acceptedPhysicsStateFingerprint
  }
}

@frozen
public struct BodyLoadFieldCell: Codable, Equatable, Hashable, Sendable {
  public let bodyIdentifier: UInt32
  public let endpointRole: BodyLoadEndpointRole
  public let sourceMuscleIdentifier: UInt32
  public let maximumAbsoluteMuscleForce: Float
  public let acceptedTimestamp: BrainTimestamp
  public let acceptedPhysicsStateFingerprint: UInt64
  public let effectiveAbsoluteMuscleForce: Float
  public let fieldActivationTimestamp: BrainTimestamp
  public let fieldStateTimestamp: BrainTimestamp

  public init(
    bodyIdentifier: UInt32,
    endpointRole: BodyLoadEndpointRole,
    sourceMuscleIdentifier: UInt32,
    maximumAbsoluteMuscleForce: Float,
    acceptedTimestamp: BrainTimestamp,
    acceptedPhysicsStateFingerprint: UInt64,
    effectiveAbsoluteMuscleForce: Float? = nil,
    fieldActivationTimestamp: BrainTimestamp? = nil,
    fieldStateTimestamp: BrainTimestamp? = nil
  ) throws {
    let effectiveAbsoluteMuscleForce =
      effectiveAbsoluteMuscleForce ?? maximumAbsoluteMuscleForce
    let fieldActivationTimestamp = fieldActivationTimestamp ?? acceptedTimestamp
    let fieldStateTimestamp = fieldStateTimestamp ?? fieldActivationTimestamp
    guard !endpointRole.isEmpty, maximumAbsoluteMuscleForce.isFinite,
      maximumAbsoluteMuscleForce >= 0, effectiveAbsoluteMuscleForce.isFinite,
      effectiveAbsoluteMuscleForce > 0,
      effectiveAbsoluteMuscleForce <= maximumAbsoluteMuscleForce,
      acceptedPhysicsStateFingerprint != 0,
      acceptedTimestamp <= fieldActivationTimestamp,
      fieldActivationTimestamp <= fieldStateTimestamp
    else {
      throw BrainRuntimeError.transaction("body-load field cell is invalid")
    }
    self.bodyIdentifier = bodyIdentifier
    self.endpointRole = endpointRole
    self.sourceMuscleIdentifier = sourceMuscleIdentifier
    self.maximumAbsoluteMuscleForce = maximumAbsoluteMuscleForce
    self.acceptedTimestamp = acceptedTimestamp
    self.acceptedPhysicsStateFingerprint = acceptedPhysicsStateFingerprint
    self.effectiveAbsoluteMuscleForce = effectiveAbsoluteMuscleForce
    self.fieldActivationTimestamp = fieldActivationTimestamp
    self.fieldStateTimestamp = fieldStateTimestamp
  }

  fileprivate init(
    sample: CommittedBodyLoadSample,
    fieldTimestamp: BrainTimestamp
  ) {
    bodyIdentifier = sample.bodyIdentifier
    endpointRole = sample.endpointRole
    sourceMuscleIdentifier = sample.sourceMuscleIdentifier
    maximumAbsoluteMuscleForce = sample.maximumAbsoluteMuscleForce
    acceptedTimestamp = sample.acceptedTimestamp
    acceptedPhysicsStateFingerprint = sample.acceptedPhysicsStateFingerprint
    effectiveAbsoluteMuscleForce = sample.maximumAbsoluteMuscleForce
    fieldActivationTimestamp = fieldTimestamp
    fieldStateTimestamp = fieldTimestamp
  }

  fileprivate init(
    mergingEndpointRole endpointRole: BodyLoadEndpointRole,
    from cell: BodyLoadFieldCell
  ) {
    bodyIdentifier = cell.bodyIdentifier
    self.endpointRole = endpointRole
    sourceMuscleIdentifier = cell.sourceMuscleIdentifier
    maximumAbsoluteMuscleForce = cell.maximumAbsoluteMuscleForce
    acceptedTimestamp = cell.acceptedTimestamp
    acceptedPhysicsStateFingerprint = cell.acceptedPhysicsStateFingerprint
    effectiveAbsoluteMuscleForce = cell.effectiveAbsoluteMuscleForce
    fieldActivationTimestamp = cell.fieldActivationTimestamp
    fieldStateTimestamp = cell.fieldStateTimestamp
  }
}

/// Sparse accepted-load view over one immutable NumanX body catalog. It is a
/// transaction-owned precursor to the learned body schema, not authoritative
/// physical state. Every sample retains the causal receptor and physical-token
/// provenance from which it was constructed.
@frozen
public struct CommittedBodyLoadFrame: Codable, Equatable, Hashable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let jointCommitFingerprint: UInt64
  public let committedTimestamp: BrainTimestamp
  public let brainGeneration: UInt64
  public let attachmentCatalogFingerprint: UInt64
  public let bodyCount: UInt32
  public let samples: [CommittedBodyLoadSample]
  public let fingerprint: UInt64

  public init(
    commit: BrainJointCommitToken,
    attachmentCatalog: NumanXMuscleAttachmentCatalog,
    observations: [LocalizedMuscleLoadReceptorObservation]
  ) throws {
    for observation in observations {
      guard observation.attachmentCatalogFingerprint == attachmentCatalog.fingerprint,
        observation.event.timestamp <= commit.committedTimestamp,
        attachmentCatalog.attachment(
          forMuscleIdentifier: observation.attachment.muscleIdentifier
        ) == observation.attachment
      else {
        throw BrainRuntimeError.transaction(
          "committed body-load observation does not match its commit or attachment catalog"
        )
      }
    }

    var samples: [CommittedBodyLoadSample] = []
    samples.reserveCapacity(observations.count * 2)
    for observation in observations {
      let attachment = observation.attachment
      if attachment.firstBodyIdentifier == attachment.terminalBodyIdentifier {
        samples.append(
          CommittedBodyLoadSample(
            bodyIdentifier: attachment.firstBodyIdentifier,
            endpointRole: [.firstRouteEndpoint, .terminalRouteEndpoint],
            observation: observation
          )
        )
      } else {
        samples.append(
          CommittedBodyLoadSample(
            bodyIdentifier: attachment.firstBodyIdentifier,
            endpointRole: .firstRouteEndpoint,
            observation: observation
          )
        )
        samples.append(
          CommittedBodyLoadSample(
            bodyIdentifier: attachment.terminalBodyIdentifier,
            endpointRole: .terminalRouteEndpoint,
            observation: observation
          )
        )
      }
    }
    samples.sort(by: Self.precedes)
    try self.init(
      jointCommitFingerprint: commit.fingerprint,
      committedTimestamp: commit.committedTimestamp,
      brainGeneration: commit.brainGeneration,
      attachmentCatalogFingerprint: attachmentCatalog.fingerprint,
      bodyCount: attachmentCatalog.bodyCount,
      samples: samples,
      expectedFingerprint: nil
    )
  }

  public var affectedBodyIdentifiers: [UInt32] {
    var result: [UInt32] = []
    result.reserveCapacity(samples.count)
    for sample in samples where result.last != sample.bodyIdentifier {
      result.append(sample.bodyIdentifier)
    }
    return result
  }

  public var maximumAbsoluteMuscleForce: Float {
    samples.lazy.map(\.maximumAbsoluteMuscleForce).max() ?? 0
  }

  /// One deterministic peak accepted load per affected body. Equal observations
  /// merge endpoint roles; otherwise force, recency, and source identity define
  /// the canonical winner in that order.
  public var peakBodyLoadCells: [BodyLoadFieldCell] {
    var cells: [BodyLoadFieldCell] = []
    for sample in samples {
      let candidate = BodyLoadFieldCell(
        sample: sample,
        fieldTimestamp: committedTimestamp
      )
      guard let last = cells.last, last.bodyIdentifier == candidate.bodyIdentifier else {
        cells.append(candidate)
        continue
      }
      if Self.sameLoad(last, candidate) {
        cells[cells.count - 1] = BodyLoadFieldCell(
          mergingEndpointRole: last.endpointRole.union(candidate.endpointRole),
          from: last
        )
      } else if Self.stronger(candidate, than: last) {
        cells[cells.count - 1] = candidate
      }
    }
    return cells
  }

  public func samples(forBodyIdentifier bodyIdentifier: UInt32)
    -> ArraySlice<CommittedBodyLoadSample>
  {
    let start = samples.firstIndex { $0.bodyIdentifier >= bodyIdentifier } ?? samples.endIndex
    let end =
      samples[start...].firstIndex { $0.bodyIdentifier > bodyIdentifier }
      ?? samples.endIndex
    return samples[start..<end]
  }

  private enum CodingKeys: String, CodingKey {
    case jointCommitFingerprint
    case committedTimestamp
    case brainGeneration
    case attachmentCatalogFingerprint
    case bodyCount
    case samples
    case fingerprint
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      jointCommitFingerprint: values.decode(UInt64.self, forKey: .jointCommitFingerprint),
      committedTimestamp: values.decode(BrainTimestamp.self, forKey: .committedTimestamp),
      brainGeneration: values.decode(UInt64.self, forKey: .brainGeneration),
      attachmentCatalogFingerprint: values.decode(
        UInt64.self,
        forKey: .attachmentCatalogFingerprint
      ),
      bodyCount: values.decode(UInt32.self, forKey: .bodyCount),
      samples: values.decode([CommittedBodyLoadSample].self, forKey: .samples),
      expectedFingerprint: values.decode(UInt64.self, forKey: .fingerprint)
    )
  }

  private init(
    jointCommitFingerprint: UInt64,
    committedTimestamp: BrainTimestamp,
    brainGeneration: UInt64,
    attachmentCatalogFingerprint: UInt64,
    bodyCount: UInt32,
    samples: [CommittedBodyLoadSample],
    expectedFingerprint: UInt64?
  ) throws {
    guard jointCommitFingerprint != 0, attachmentCatalogFingerprint != 0, bodyCount > 0,
      samples.allSatisfy({ sample in
        sample.bodyIdentifier < bodyCount
          && !sample.endpointRole.isEmpty
          && sample.maximumAbsoluteMuscleForce.isFinite
          && sample.maximumAbsoluteMuscleForce >= 0
          && sample.acceptedTimestamp <= committedTimestamp
          && sample.acceptedPhysicsStateFingerprint != 0
      }),
      samples.elementsEqual(samples.sorted(by: Self.precedes))
    else {
      throw BrainRuntimeError.transaction("committed body-load frame is invalid")
    }
    let fingerprint = Self.computeFingerprint(
      jointCommitFingerprint: jointCommitFingerprint,
      committedTimestamp: committedTimestamp,
      brainGeneration: brainGeneration,
      attachmentCatalogFingerprint: attachmentCatalogFingerprint,
      bodyCount: bodyCount,
      samples: samples
    )
    guard fingerprint != 0, expectedFingerprint == nil || expectedFingerprint == fingerprint else {
      throw BrainRuntimeError.transaction("committed body-load frame fingerprint drift")
    }
    self.jointCommitFingerprint = jointCommitFingerprint
    self.committedTimestamp = committedTimestamp
    self.brainGeneration = brainGeneration
    self.attachmentCatalogFingerprint = attachmentCatalogFingerprint
    self.bodyCount = bodyCount
    self.samples = samples
    self.fingerprint = fingerprint
  }

  private static func precedes(
    _ lhs: CommittedBodyLoadSample,
    _ rhs: CommittedBodyLoadSample
  ) -> Bool {
    if lhs.bodyIdentifier != rhs.bodyIdentifier {
      return lhs.bodyIdentifier < rhs.bodyIdentifier
    }
    if lhs.acceptedTimestamp != rhs.acceptedTimestamp {
      return lhs.acceptedTimestamp < rhs.acceptedTimestamp
    }
    if lhs.sourceMuscleIdentifier != rhs.sourceMuscleIdentifier {
      return lhs.sourceMuscleIdentifier < rhs.sourceMuscleIdentifier
    }
    if lhs.endpointRole.rawValue != rhs.endpointRole.rawValue {
      return lhs.endpointRole.rawValue < rhs.endpointRole.rawValue
    }
    if lhs.acceptedPhysicsStateFingerprint != rhs.acceptedPhysicsStateFingerprint {
      return lhs.acceptedPhysicsStateFingerprint < rhs.acceptedPhysicsStateFingerprint
    }
    return lhs.maximumAbsoluteMuscleForce.bitPattern
      < rhs.maximumAbsoluteMuscleForce.bitPattern
  }

  private static func sameLoad(_ lhs: BodyLoadFieldCell, _ rhs: BodyLoadFieldCell) -> Bool {
    lhs.bodyIdentifier == rhs.bodyIdentifier
      && lhs.sourceMuscleIdentifier == rhs.sourceMuscleIdentifier
      && lhs.maximumAbsoluteMuscleForce == rhs.maximumAbsoluteMuscleForce
      && lhs.acceptedTimestamp == rhs.acceptedTimestamp
      && lhs.acceptedPhysicsStateFingerprint == rhs.acceptedPhysicsStateFingerprint
  }

  private static func stronger(
    _ lhs: BodyLoadFieldCell,
    than rhs: BodyLoadFieldCell
  ) -> Bool {
    if lhs.maximumAbsoluteMuscleForce != rhs.maximumAbsoluteMuscleForce {
      return lhs.maximumAbsoluteMuscleForce > rhs.maximumAbsoluteMuscleForce
    }
    if lhs.acceptedTimestamp != rhs.acceptedTimestamp {
      return lhs.acceptedTimestamp > rhs.acceptedTimestamp
    }
    if lhs.sourceMuscleIdentifier != rhs.sourceMuscleIdentifier {
      return lhs.sourceMuscleIdentifier < rhs.sourceMuscleIdentifier
    }
    return lhs.acceptedPhysicsStateFingerprint < rhs.acceptedPhysicsStateFingerprint
  }

  private static func computeFingerprint(
    jointCommitFingerprint: UInt64,
    committedTimestamp: BrainTimestamp,
    brainGeneration: UInt64,
    attachmentCatalogFingerprint: UInt64,
    bodyCount: UInt32,
    samples: [CommittedBodyLoadSample]
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    mix(formatVersion, into: &hash)
    mix(jointCommitFingerprint, into: &hash)
    mix(committedTimestamp.rawValue, into: &hash)
    mix(brainGeneration, into: &hash)
    mix(attachmentCatalogFingerprint, into: &hash)
    mix(bodyCount, into: &hash)
    mix(UInt32(samples.count), into: &hash)
    for sample in samples {
      mix(sample.bodyIdentifier, into: &hash)
      mix(sample.endpointRole.rawValue, into: &hash)
      mix(sample.sourceMuscleIdentifier, into: &hash)
      mix(sample.maximumAbsoluteMuscleForce.bitPattern, into: &hash)
      mix(sample.acceptedTimestamp.rawValue, into: &hash)
      mix(sample.acceptedPhysicsStateFingerprint, into: &hash)
    }
    return hash
  }

  private static func mix(_ value: UInt32, into hash: inout UInt64) {
    mix(UInt64(value), byteCount: 4, into: &hash)
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    mix(value, byteCount: 8, into: &hash)
  }

  private static func mix(_ value: UInt64, byteCount: Int, into hash: inout UInt64) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      for byte in bytes.prefix(byteCount) {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}
