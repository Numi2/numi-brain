import CryptoKit
import Darwin
import Foundation

@frozen
public struct BrainPolicyDatasetMembershipEvidence: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let partitionIdentifier: String
  public let memberSHA256: [String]

  public init(partitionIdentifier: String, memberSHA256: [String]) throws {
    let canonicalMembers = memberSHA256.sorted()
    guard !partitionIdentifier.isEmpty, !canonicalMembers.isEmpty,
      Set(canonicalMembers).count == canonicalMembers.count,
      canonicalMembers.allSatisfy(BrainPolicyEvidenceArtifact.isSHA256)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy split membership evidence is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.partitionIdentifier = partitionIdentifier
    self.memberSHA256 = canonicalMembers
  }

  public func encoded() throws -> Data {
    try validate()
    return try BrainPolicyEvidenceArtifact.encodeCanonical(self)
  }

  public static func decode(_ data: Data) throws -> Self {
    let evidence = try JSONDecoder().decode(Self.self, from: data)
    try evidence.validate()
    return evidence
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion,
      try Self(
        partitionIdentifier: partitionIdentifier,
        memberSHA256: memberSHA256
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy split membership evidence is not canonical"
      )
    }
  }
}

@frozen
public enum BrainPolicyMetricReducer: String, Codable, CaseIterable, Sendable {
  case mean
  case minimum
  case maximum
  case percentile99
}

@frozen
public struct BrainPolicyMetricObservation: Codable, Equatable, Sendable {
  public let sampleSHA256: String
  public let value: Double

  public init(sampleSHA256: String, value: Double) throws {
    guard BrainPolicyEvidenceArtifact.isSHA256(sampleSHA256), value.isFinite else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy metric observation is invalid"
      )
    }
    self.sampleSHA256 = sampleSHA256
    self.value = value
  }
}

@frozen
public struct BrainPolicyQualificationMetricEvidence: Codable, Equatable, Sendable {
  public let identifier: String
  public let unit: String
  public let reducer: BrainPolicyMetricReducer
  public let threshold: Double
  public let direction: BrainPolicyMetricDirection
  public let observations: [BrainPolicyMetricObservation]

  public init(
    identifier: String,
    unit: String,
    reducer: BrainPolicyMetricReducer,
    threshold: Double,
    direction: BrainPolicyMetricDirection,
    observations: [BrainPolicyMetricObservation]
  ) throws {
    let canonicalObservations = observations.sorted {
      $0.sampleSHA256 < $1.sampleSHA256
    }
    guard !identifier.isEmpty, !unit.isEmpty, threshold.isFinite,
      !canonicalObservations.isEmpty,
      Set(canonicalObservations.map(\.sampleSHA256)).count
        == canonicalObservations.count
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy qualification metric evidence is invalid"
      )
    }
    self.identifier = identifier
    self.unit = unit
    self.reducer = reducer
    self.threshold = threshold
    self.direction = direction
    self.observations = canonicalObservations
  }

  public var reducedValue: Double {
    switch reducer {
    case .mean:
      return observations.reduce(0) { $0 + $1.value }
        / Double(observations.count)
    case .minimum:
      return observations.map(\.value).min()!
    case .maximum:
      return observations.map(\.value).max()!
    case .percentile99:
      let sorted = observations.map(\.value).sorted()
      let rank = Int(ceil(Double(sorted.count) * 0.99)) - 1
      return sorted[max(0, min(rank, sorted.count - 1))]
    }
  }

  fileprivate func metric() throws -> BrainPolicyQualificationMetric {
    try BrainPolicyQualificationMetric(
      identifier: identifier,
      unit: unit,
      value: reducedValue,
      threshold: threshold,
      direction: direction
    )
  }

  fileprivate func validate() throws {
    guard
      try Self(
        identifier: identifier,
        unit: unit,
        reducer: reducer,
        threshold: threshold,
        direction: direction,
        observations: observations
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy qualification metric evidence is not canonical"
      )
    }
  }
}

@frozen
public struct BrainPolicyQualificationEvidence: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let axis: BrainPolicyQualificationAxis
  public let modelWeightsSHA256: String
  public let partitionIdentifiers: [String]
  public let metrics: [BrainPolicyQualificationMetricEvidence]

  public init(
    axis: BrainPolicyQualificationAxis,
    modelWeightsSHA256: String,
    partitionIdentifiers: [String],
    metrics: [BrainPolicyQualificationMetricEvidence]
  ) throws {
    let canonicalPartitions = partitionIdentifiers.sorted()
    let canonicalMetrics = metrics.sorted { $0.identifier < $1.identifier }
    let sampleSets = canonicalMetrics.map { Set($0.observations.map(\.sampleSHA256)) }
    guard BrainPolicyEvidenceArtifact.isSHA256(modelWeightsSHA256),
      !canonicalPartitions.isEmpty,
      Set(canonicalPartitions).count == canonicalPartitions.count,
      !canonicalMetrics.isEmpty,
      Set(canonicalMetrics.map(\.identifier)).count == canonicalMetrics.count,
      Set(sampleSets).count == 1
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy qualification evidence is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.axis = axis
    self.modelWeightsSHA256 = modelWeightsSHA256
    self.partitionIdentifiers = canonicalPartitions
    self.metrics = canonicalMetrics
  }

  public var sampleCount: UInt64 {
    UInt64(metrics.first?.observations.count ?? 0)
  }

  public func encoded() throws -> Data {
    try validate()
    return try BrainPolicyEvidenceArtifact.encodeCanonical(self)
  }

  public static func decode(_ data: Data) throws -> Self {
    let evidence = try JSONDecoder().decode(Self.self, from: data)
    try evidence.validate()
    return evidence
  }

  public func qualificationResult() throws -> BrainPolicyQualificationResult {
    let encoded = try encoded()
    return try BrainPolicyQualificationResult(
      axis: axis,
      evaluationArtifactSHA256: BrainPolicyEvidenceArtifact.sha256(encoded),
      sampleCount: sampleCount,
      metrics: try metrics.map { try $0.metric() }
    )
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy qualification evidence version is unsupported"
      )
    }
    for metric in metrics { try metric.validate() }
    guard
      try Self(
        axis: axis,
        modelWeightsSHA256: modelWeightsSHA256,
        partitionIdentifiers: partitionIdentifiers,
        metrics: metrics
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy qualification evidence is not canonical"
      )
    }
  }
}

@frozen
public struct BrainPolicySplitIntegrityBinding: Codable, Equatable, Sendable {
  public let partitionIdentifier: String
  public let membershipArtifactSHA256: String

  public init(
    partitionIdentifier: String,
    membershipArtifactSHA256: String
  ) throws {
    guard !partitionIdentifier.isEmpty,
      BrainPolicyEvidenceArtifact.isSHA256(membershipArtifactSHA256)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy split-integrity binding is invalid"
      )
    }
    self.partitionIdentifier = partitionIdentifier
    self.membershipArtifactSHA256 = membershipArtifactSHA256
  }
}

@frozen
public struct BrainPolicySplitIntegrityEvidence: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let bindings: [BrainPolicySplitIntegrityBinding]
  public let overlapCount: UInt64

  public init(bindings: [BrainPolicySplitIntegrityBinding]) throws {
    let canonical = bindings.sorted { $0.partitionIdentifier < $1.partitionIdentifier }
    guard !canonical.isEmpty,
      Set(canonical.map(\.partitionIdentifier)).count == canonical.count,
      Set(canonical.map(\.membershipArtifactSHA256)).count == canonical.count
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy split-integrity evidence is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.bindings = canonical
    self.overlapCount = 0
  }

  public func encoded() throws -> Data {
    try validate()
    return try BrainPolicyEvidenceArtifact.encodeCanonical(self)
  }

  public static func decode(_ data: Data) throws -> Self {
    let evidence = try JSONDecoder().decode(Self.self, from: data)
    try evidence.validate()
    return evidence
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion, overlapCount == 0,
      try Self(bindings: bindings) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy split-integrity evidence is not canonical"
      )
    }
  }
}

public enum BrainPolicyEvidenceArtifact {
  public static let fileExtension = "artifact"

  public static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  public static func isSHA256(_ value: String) -> Bool {
    value.count == 64
      && value.allSatisfy {
        $0.isNumber || ("a"..."f").contains(String($0))
      }
  }

  public static func url(forSHA256 sha256: String, in directory: URL) throws -> URL {
    guard isSHA256(sha256) else {
      throw BrainRuntimeError.invalidParameterVersion("policy evidence SHA-256 is invalid")
    }
    return directory.appending(path: "\(sha256).\(fileExtension)")
  }

  @discardableResult
  public static func write(_ data: Data, to directory: URL) throws -> String {
    let hash = sha256(data)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    try data.write(to: url(forSHA256: hash, in: directory), options: [.atomic])
    return hash
  }

  fileprivate static func encodeCanonical<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }
}

/// In-process proof that every content-addressed artifact required by one
/// policy package was present, hash-exact, semantically decoded, split-disjoint,
/// and metric-recomputed. The initializer is intentionally internal so callers
/// cannot manufacture a receipt from package declarations alone.
public final class BrainFoundationPolicyEvidenceReceipt: @unchecked Sendable {
  public let packageContentSHA256: String
  public let evidenceRootSHA256: String

  fileprivate init(
    packageContentSHA256: String,
    evidenceRootSHA256: String
  ) {
    self.packageContentSHA256 = packageContentSHA256
    self.evidenceRootSHA256 = evidenceRootSHA256
  }

  public func validate(package: BrainFoundationPolicyPackage) throws {
    guard packageContentSHA256 == package.packageContentSHA256,
      BrainPolicyEvidenceArtifact.isSHA256(evidenceRootSHA256)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy evidence receipt does not identify this package"
      )
    }
  }
}

public enum BrainFoundationPolicyEvidenceVerifier {
  private static let maximumDecodedEvidenceBytes = 256 * 1024 * 1024

  public static func verify(
    package: BrainFoundationPolicyPackage,
    artifactDirectory: URL
  ) throws -> BrainFoundationPolicyEvidenceReceipt {
    try package.validateGateCEvidenceManifest()
    var verifiedHashes: [String] = []

    for source in package.datasetSources {
      try verifyStreamedArtifact(
        sha256: source.contentSHA256,
        directory: artifactDirectory
      )
      verifiedHashes.append(source.contentSHA256)
    }

    var memberships: [String: BrainPolicyDatasetMembershipEvidence] = [:]
    var allMembers: Set<String> = []
    for partition in package.datasetPartitions {
      let data = try verifiedData(
        sha256: partition.membershipArtifactSHA256,
        directory: artifactDirectory
      )
      let evidence = try BrainPolicyDatasetMembershipEvidence.decode(data)
      guard evidence.partitionIdentifier == partition.identifier,
        UInt64(evidence.memberSHA256.count) == partition.sampleCount
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "policy split membership does not match its package partition"
        )
      }
      for member in evidence.memberSHA256 {
        guard allMembers.insert(member).inserted else {
          throw BrainRuntimeError.invalidParameterVersion(
            "policy dataset partitions overlap"
          )
        }
      }
      memberships[partition.identifier] = evidence
      verifiedHashes.append(partition.membershipArtifactSHA256)
    }

    let expectedSplitEvidence = try BrainPolicySplitIntegrityEvidence(
      bindings: try package.datasetPartitions.map {
        try BrainPolicySplitIntegrityBinding(
          partitionIdentifier: $0.identifier,
          membershipArtifactSHA256: $0.membershipArtifactSHA256
        )
      }
    )
    let splitData = try verifiedData(
      sha256: package.splitIntegrityReportSHA256,
      directory: artifactDirectory
    )
    guard
      try BrainPolicySplitIntegrityEvidence.decode(splitData)
        == expectedSplitEvidence
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy split-integrity report does not match verified memberships"
      )
    }
    verifiedHashes.append(package.splitIntegrityReportSHA256)

    let partitionsByIdentifier = Dictionary(
      uniqueKeysWithValues: package.datasetPartitions.map { ($0.identifier, $0) }
    )
    for result in package.qualificationResults {
      let data = try verifiedData(
        sha256: result.evaluationArtifactSHA256,
        directory: artifactDirectory
      )
      let evidence = try BrainPolicyQualificationEvidence.decode(data)
      let allowedSamples = evidence.partitionIdentifiers.reduce(into: Set<String>()) {
        result, identifier in
        if let membership = memberships[identifier] {
          result.formUnion(membership.memberSHA256)
        }
      }
      let observedSamples = Set(
        evidence.metrics.first?.observations.map(\.sampleSHA256) ?? []
      )
      guard evidence.axis == result.axis,
        evidence.modelWeightsSHA256 == package.architecture.modelWeightsSHA256,
        try evidence.qualificationResult() == result,
        evidence.partitionIdentifiers.allSatisfy({
          partitionsByIdentifier[$0] != nil
        }),
        evidence.partitionIdentifiers.contains(where: {
          partitionsByIdentifier[$0]?.split == requiredSplit(for: result.axis)
        }), !observedSamples.isEmpty,
        observedSamples.isSubset(of: allowedSamples)
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "policy qualification evidence does not reproduce its package result"
        )
      }
      verifiedHashes.append(result.evaluationArtifactSHA256)
    }

    var rootBytes = Data(package.packageContentSHA256.utf8)
    for hash in verifiedHashes.sorted() { rootBytes.append(Data(hash.utf8)) }
    return BrainFoundationPolicyEvidenceReceipt(
      packageContentSHA256: package.packageContentSHA256,
      evidenceRootSHA256: BrainPolicyEvidenceArtifact.sha256(rootBytes)
    )
  }

  private static func requiredSplit(
    for axis: BrainPolicyQualificationAxis
  ) -> BrainPolicyDatasetSplit {
    switch axis {
    case .actionGenerationLatency: .validation
    case .crossTask: .heldOutTask
    case .crossScene: .heldOutScene
    case .crossObject: .heldOutObject
    case .crossEmbodiment: .heldOutEmbodiment
    case .fewShotAdaptation: .adaptation
    case .delayedConsequences, .interruptedTasks, .stateAliasing: .heldOutTask
    case .uncertaintyAndOOD, .hardSafetyRetention: .safety
    }
  }

  private static func verifiedData(
    sha256: String,
    directory: URL
  ) throws -> Data {
    let descriptor = try openArtifact(sha256: sha256, directory: directory)
    defer { Darwin.close(descriptor) }
    var metadata = stat()
    guard fstat(descriptor, &metadata) == 0,
      metadata.st_size >= 0,
      metadata.st_size <= maximumDecodedEvidenceBytes
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "decoded policy evidence artifact exceeds the safety limit"
      )
    }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
    var data = Data()
    data.reserveCapacity(Int(metadata.st_size))
    var hasher = SHA256()
    while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
      guard data.count <= maximumDecodedEvidenceBytes - chunk.count else {
        throw BrainRuntimeError.invalidParameterVersion(
          "decoded policy evidence artifact exceeds the safety limit"
        )
      }
      hasher.update(data: chunk)
      data.append(chunk)
    }
    guard hex(hasher.finalize()) == sha256 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy evidence artifact is hash-mismatched"
      )
    }
    return data
  }

  private static func verifyStreamedArtifact(
    sha256: String,
    directory: URL
  ) throws {
    let descriptor = try openArtifact(sha256: sha256, directory: directory)
    defer { Darwin.close(descriptor) }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
    var hasher = SHA256()
    while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
      hasher.update(data: data)
    }
    guard hex(hasher.finalize()) == sha256 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy evidence artifact is hash-mismatched"
      )
    }
  }

  private static func openArtifact(
    sha256: String,
    directory: URL
  ) throws -> Int32 {
    let url = try BrainPolicyEvidenceArtifact.url(
      forSHA256: sha256,
      in: directory
    )
    let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    guard descriptor >= 0 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "policy evidence artifact is missing or unsafe"
      )
    }
    var metadata = stat()
    guard fstat(descriptor, &metadata) == 0,
      metadata.st_mode & S_IFMT == S_IFREG
    else {
      Darwin.close(descriptor)
      throw BrainRuntimeError.invalidParameterVersion(
        "policy evidence artifact is not a regular file"
      )
    }
    return descriptor
  }

  private static func hex(_ digest: SHA256.Digest) -> String {
    digest.map { String(format: "%02x", $0) }.joined()
  }
}
