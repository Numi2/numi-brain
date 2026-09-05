import Foundation

@frozen
public enum PromotionGate: String, Codable, CaseIterable, Sendable {
  case A, B, C, D, E, F
}

@frozen
public enum GateEvidenceStatus: String, Codable, Sendable {
  case implemented
  case buildQualified
  case executableQualified
  case physicallyValidated
  case performanceQualified
  case promotionReady
  case open
}

@frozen
public struct GateEvidenceEntry: Codable, Equatable, Sendable {
  public let gate: PromotionGate
  public let status: GateEvidenceStatus
  public let sourceRevision: String
  public let evidenceSHA256: [String]
  public let limitations: [String]

  public init(gate: PromotionGate, status: GateEvidenceStatus, sourceRevision: String,
    evidenceSHA256: [String], limitations: [String]) throws {
    guard !sourceRevision.isEmpty, evidenceSHA256.count <= 100_000,
      evidenceSHA256.allSatisfy(PerformanceRunArtifact.isSHA256), Set(evidenceSHA256).count == evidenceSHA256.count,
      limitations.count <= 10_000 else { throw QualificationError.invalid("gate evidence entry is invalid") }
    self.gate = gate; self.status = status; self.sourceRevision = sourceRevision
    self.evidenceSHA256 = evidenceSHA256.sorted(); self.limitations = limitations
  }
}

@frozen
public struct NumanXQualificationManifest: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let sourceRevision: String
  public let entries: [GateEvidenceEntry]

  public init(sourceRevision: String, entries: [GateEvidenceEntry]) throws {
    let canonical = entries.sorted { $0.gate.rawValue < $1.gate.rawValue }
    guard !sourceRevision.isEmpty, canonical.count == PromotionGate.allCases.count,
      Set(canonical.map(\.gate)).count == canonical.count,
      canonical.allSatisfy({$0.sourceRevision == sourceRevision}) else {
      throw QualificationError.invalid("qualification manifest must contain A...F for one exact revision")
    }
    formatVersion = Self.formatVersion; self.sourceRevision = sourceRevision; self.entries = canonical
  }

  public var promotionReady: Bool {
    entries.allSatisfy { entry in
      switch entry.gate {
      case .A, .B: return entry.status == .promotionReady || entry.status == .executableQualified
      case .C: return entry.status == .promotionReady
      case .D: return entry.status == .promotionReady || entry.status == .physicallyValidated
      case .E: return entry.status == .promotionReady || entry.status == .performanceQualified
      case .F: return entry.status == .promotionReady
      }
    }
  }
}
