import Foundation

@frozen
public struct BrainPolicyNumanXSupportContactVariantArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let sourceAssetSHA256: String
  public let variantAssetSHA256: String
  public let supportCount: UInt32
  public let tiltDegrees: Float
  public let sourceGroundPoint: [Float]
  public let sourceGroundNormal: [Float]
  public let variantGroundNormal: [Float]

  public init(
    sourceAssetSHA256: String,
    variantAssetSHA256: String,
    supportCount: UInt32,
    tiltDegrees: Float,
    sourceGroundPoint: [Float],
    sourceGroundNormal: [Float],
    variantGroundNormal: [Float]
  ) throws {
    guard BrainPolicyEvidenceArtifact.isSHA256(sourceAssetSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(variantAssetSHA256),
      sourceAssetSHA256 != variantAssetSHA256, supportCount > 0,
      tiltDegrees.isFinite, abs(tiltDegrees) > 0, abs(tiltDegrees) <= 15,
      sourceGroundPoint.count == 3, sourceGroundNormal.count == 3,
      variantGroundNormal.count == 3,
      (sourceGroundPoint + sourceGroundNormal + variantGroundNormal)
        .allSatisfy(\.isFinite),
      abs(Self.norm(sourceGroundNormal) - 1) <= 1.0e-4,
      abs(Self.norm(variantGroundNormal) - 1) <= 1.0e-4
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-contact variant artifact is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.sourceAssetSHA256 = sourceAssetSHA256
    self.variantAssetSHA256 = variantAssetSHA256
    self.supportCount = supportCount
    self.tiltDegrees = tiltDegrees
    self.sourceGroundPoint = sourceGroundPoint
    self.sourceGroundNormal = sourceGroundNormal
    self.variantGroundNormal = variantGroundNormal
  }

  public func encoded() throws -> Data {
    try validate()
    return try BrainPolicyEvidenceArtifact.encodeCanonical(self)
  }

  @discardableResult
  public func write(to artifactDirectory: URL) throws -> String {
    try BrainPolicyEvidenceArtifact.write(encoded(), to: artifactDirectory)
  }

  public static func decode(_ data: Data) throws -> Self {
    let artifact = try JSONDecoder().decode(Self.self, from: data)
    try artifact.validate()
    return artifact
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion,
      try Self(
        sourceAssetSHA256: sourceAssetSHA256,
        variantAssetSHA256: variantAssetSHA256,
        supportCount: supportCount,
        tiltDegrees: tiltDegrees,
        sourceGroundPoint: sourceGroundPoint,
        sourceGroundNormal: sourceGroundNormal,
        variantGroundNormal: variantGroundNormal
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-contact variant artifact is not canonical"
      )
    }
  }

  private static func norm(_ values: [Float]) -> Float {
    sqrt(values.reduce(0) { $0 + $1 * $1 })
  }
}

public struct BrainPolicyNumanXSupportContactVariantReceipt: Sendable {
  public let artifact: BrainPolicyNumanXSupportContactVariantArtifact
  public let artifactSHA256: String
  public let variantAssetURL: URL
}

/// Provenance-preserving transformation of the native `NHCNT1` support plane.
/// It retains both the exact source bytes and transformed bytes as immutable
/// artifacts and updates every support witness so the variant remains an exact
/// physical input rather than an untracked test fixture.
public enum BrainPolicyNumanXSupportContactVariant {
  public static func verify(
    artifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXSupportContactVariantArtifact {
    let stored = try BrainPolicyNumanXSupportContactVariantArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: artifactSHA256,
        directory: artifactDirectory
      )
    )
    let source = try BrainPolicyNumanXCaptureVerifier.verifiedData(
      sha256: stored.sourceAssetSHA256,
      directory: artifactDirectory
    )
    let retainedVariant = try BrainPolicyNumanXCaptureVerifier.verifiedData(
      sha256: stored.variantAssetSHA256,
      directory: artifactDirectory
    )
    let temporary = FileManager.default.temporaryDirectory.appending(
      path: "numanx-support-verify-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
      at: temporary,
      withIntermediateDirectories: false
    )
    defer { try? FileManager.default.removeItem(at: temporary) }
    let sourceURL = temporary.appending(path: "source.nhcnt")
    try source.write(to: sourceURL, options: .atomic)
    let recomputed = try create(
      sourceURL: sourceURL,
      tiltDegrees: stored.tiltDegrees,
      artifactDirectory: temporary
    )
    let recomputedVariant = try BrainPolicyNumanXCaptureVerifier.verifiedData(
      sha256: recomputed.artifact.variantAssetSHA256,
      directory: temporary
    )
    guard recomputed.artifactSHA256 == artifactSHA256,
      recomputed.artifact == stored,
      recomputedVariant == retainedVariant
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-contact retained variant does not recompute exactly"
      )
    }
    return stored
  }

  public static func create(
    sourceURL: URL,
    tiltDegrees: Float,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXSupportContactVariantReceipt {
    guard tiltDegrees.isFinite, abs(tiltDegrees) > 0,
      abs(tiltDegrees) <= 15
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-contact tilt is outside its declared range"
      )
    }
    var bytes = [UInt8](try Data(contentsOf: sourceURL))
    guard bytes.count >= 84 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-contact source is truncated"
      )
    }
    func loadUInt32(_ offset: Int) -> UInt32 {
      UInt32(bytes[offset])
        | UInt32(bytes[offset + 1]) << 8
        | UInt32(bytes[offset + 2]) << 16
        | UInt32(bytes[offset + 3]) << 24
    }
    func loadFloat(_ offset: Int) -> Float {
      Float(bitPattern: loadUInt32(offset))
    }
    func storeUInt32(_ value: UInt32, _ offset: Int) {
      bytes[offset] = UInt8(truncatingIfNeeded: value)
      bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
      bytes[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
      bytes[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
    }
    func storeFloat(_ value: Float, _ offset: Int) {
      storeUInt32(value.bitPattern, offset)
    }
    let supportCount = loadUInt32(16)
    let (recordsBytes, recordsOverflow) = Int(supportCount)
      .multipliedReportingOverflow(by: 48)
    guard Array(bytes[0..<8]) == Array("NHCNT1\0\0".utf8),
      loadUInt32(8) == 1, supportCount > 0, loadUInt32(20) == 0,
      !recordsOverflow, bytes.count == 84 + recordsBytes
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-contact source has unexpected provenance"
      )
    }
    let point = (0..<3).map { loadFloat(56 + $0 * 4) }
    let sourceNormal = (0..<3).map { loadFloat(68 + $0 * 4) }
    guard (point + sourceNormal).allSatisfy(\.isFinite),
      abs(sqrt(sourceNormal.reduce(0) { $0 + $1 * $1 }) - 1) <= 1.0e-4
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-contact source plane is invalid"
      )
    }
    let radians = tiltDegrees * .pi / 180
    let variantNormal: [Float] = [sin(radians), 0, cos(radians)]
    for index in 0..<Int(supportCount) {
      let record = 84 + index * 48
      let witness = (0..<3).map { loadFloat(record + 20 + $0 * 4) }
      let oldDistance = loadFloat(record + 36)
      guard witness.allSatisfy(\.isFinite), oldDistance.isFinite else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX support-contact witness is invalid"
        )
      }
      let sourceWorld = (0..<3).map {
        witness[$0] + oldDistance * sourceNormal[$0]
      }
      let newDistance = (0..<3).reduce(Float(0)) {
        $0 + (sourceWorld[$1] - point[$1]) * variantNormal[$1]
      }
      storeFloat(newDistance, record + 36)
      for axis in 0..<3 {
        storeFloat(
          sourceWorld[axis] - newDistance * variantNormal[axis],
          record + 20 + axis * 4
        )
      }
    }
    for axis in 0..<3 { storeFloat(variantNormal[axis], 68 + axis * 4) }

    let sourceData = try Data(contentsOf: sourceURL)
    let variantData = Data(bytes)
    let sourceHash = try BrainPolicyEvidenceArtifact.write(
      sourceData,
      to: artifactDirectory
    )
    let variantHash = try BrainPolicyEvidenceArtifact.write(
      variantData,
      to: artifactDirectory
    )
    let artifact = try BrainPolicyNumanXSupportContactVariantArtifact(
      sourceAssetSHA256: sourceHash,
      variantAssetSHA256: variantHash,
      supportCount: supportCount,
      tiltDegrees: tiltDegrees,
      sourceGroundPoint: point,
      sourceGroundNormal: sourceNormal,
      variantGroundNormal: variantNormal
    )
    return try BrainPolicyNumanXSupportContactVariantReceipt(
      artifact: artifact,
      artifactSHA256: artifact.write(to: artifactDirectory),
      variantAssetURL: BrainPolicyEvidenceArtifact.url(
        forSHA256: variantHash,
        in: artifactDirectory
      )
    )
  }
}
