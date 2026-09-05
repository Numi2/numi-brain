import Foundation

@frozen
public enum PromotionGate: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
  case A, B, C, D, E, F
}

@frozen
public enum GateEvidenceStatus: String, Codable, Equatable, Hashable, Sendable {
  case implemented, buildQualified, executableQualified, physicallyValidated
  case performanceQualified, promotionReady, open
}

/// A declaration of evidence, not a verification receipt or runtime capability.
@frozen
public struct GateEvidenceEntry: Codable, Equatable, Sendable {
  public let gate: PromotionGate
  public let status: GateEvidenceStatus
  public let sourceRevision: String
  public let evidenceSHA256: [String]
  public let limitations: [String]

  public init(gate: PromotionGate, status: GateEvidenceStatus, sourceRevision: String,
    evidenceSHA256: [String], limitations: [String]) throws {
    let needsEvidence = status != .open && status != .implemented
    guard !sourceRevision.isEmpty, sourceRevision.utf8.count <= 256,
      evidenceSHA256.count <= 100_000, !needsEvidence || !evidenceSHA256.isEmpty,
      evidenceSHA256.allSatisfy(PerformanceRunArtifact.isSHA256),
      Set(evidenceSHA256).count == evidenceSHA256.count,
      limitations.count <= 10_000,
      limitations.allSatisfy({ $0.utf8.count <= 4096 }) else {
      throw QualificationError.invalid("gate declaration is invalid or claims qualification without evidence")
    }
    self.gate = gate; self.status = status; self.sourceRevision = sourceRevision
    self.evidenceSHA256 = evidenceSHA256.sorted(); self.limitations = limitations
  }

  public func validate() throws {
    guard try Self(gate: gate, status: status, sourceRevision: sourceRevision,
      evidenceSHA256: evidenceSHA256, limitations: limitations) == self else {
      throw QualificationError.invalid("noncanonical gate declaration")
    }
  }
}

@frozen
public struct NumanXQualificationManifest: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let sourceRevision: String
  public let entries: [GateEvidenceEntry]

  public init(sourceRevision: String, entries: [GateEvidenceEntry]) throws {
    guard entries.count == PromotionGate.allCases.count else {
      throw QualificationError.invalid("qualification declaration requires exactly A...F")
    }
    for entry in entries { try entry.validate() }
    let canonical = entries.sorted { $0.gate.rawValue < $1.gate.rawValue }
    guard !sourceRevision.isEmpty, sourceRevision.utf8.count <= 256,
      Set(canonical.map(\.gate)) == Set(PromotionGate.allCases),
      canonical.allSatisfy({ $0.sourceRevision == sourceRevision }) else {
      throw QualificationError.invalid("qualification declaration mixes gates or source revisions")
    }
    formatVersion = Self.formatVersion; self.sourceRevision = sourceRevision; self.entries = canonical
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion,
      try Self(sourceRevision: sourceRevision, entries: entries) == self else {
      throw QualificationError.invalid("noncanonical qualification declaration")
    }
  }

  /// Reports only what the manifest CLAIMS. Even well-formed hashes can name
  /// missing, failed or unrelated artifacts. Never use this for admission.
  public var declaredPromotionReady: Bool {
    guard (try? validate()) != nil else { return false }
    return entries.allSatisfy { entry in
      switch entry.gate {
      case .A, .B: return entry.status == .promotionReady || entry.status == .executableQualified
      case .C, .F: return entry.status == .promotionReady
      case .D: return entry.status == .promotionReady || entry.status == .physicallyValidated
      case .E: return entry.status == .promotionReady || entry.status == .performanceQualified
      }
    }
  }

  /// Kept source-compatible, but declarations never mint verified authority.
  /// Actual policy admission continues to require the existing in-process
  /// BrainFoundationPolicyEvidenceVerifier receipt for the exact package.
  @available(*, deprecated, message: "A declaration cannot prove promotion. Use declaredPromotionReady for inspection, and gate-specific verified receipts for admission.")
  public var promotionReady: Bool { false }
}
