import Foundation

@frozen
public struct BrainParameterPayload: Codable, Equatable, Sendable {
  public let kind: BrainParameterComponentKind
  public let elementType: BrainParameterElementType
  public let data: Data
  public let contentFingerprint: UInt64

  public init(
    kind: BrainParameterComponentKind,
    elementType: BrainParameterElementType,
    data: Data
  ) throws {
    guard !data.isEmpty else {
      throw BrainRuntimeError.invalidParameterVersion("parameter payload is empty")
    }
    self.kind = kind
    self.elementType = elementType
    self.data = data
    self.contentFingerprint = Self.fingerprint(data)
  }

  public var component: BrainParameterComponent {
    get throws {
      let elementByteCount: UInt64
      switch elementType {
      case .fp16, .bf16: elementByteCount = 2
      case .fp32: elementByteCount = 4
      case .int8, .opaque: elementByteCount = 1
      }
      guard UInt64(data.count) % elementByteCount == 0 else {
        throw BrainRuntimeError.invalidParameterVersion(
          "parameter payload is not aligned to its element type"
        )
      }
      return try BrainParameterComponent(
        kind: kind,
        elementType: elementType,
        elementCount: UInt64(data.count) / elementByteCount,
        byteCount: UInt64(data.count),
        contentFingerprint: contentFingerprint
      )
    }
  }

  static func fingerprint(_ data: Data) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    data.withUnsafeBytes { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
    return hash
  }
}

/// Actual immutable byte payloads for shared slow components. The version
/// manifest remains the publication identity; this artifact proves the bytes
/// bound for inference are exactly the bytes named by that manifest.
@frozen
public struct BrainSharedParameterArtifact: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public static let requiredKinds: [BrainParameterComponentKind] = [
    .sensory, .belief, .world, .route, .memory, .value, .policy,
    .motor, .cerebellar, .plasticity, .regionalDense,
  ]

  public let formatVersion: UInt32
  public let parameterVersionFingerprint: UInt64
  public let payloads: [BrainParameterPayload]
  public let artifactFingerprint: UInt64

  public init(
    parameterVersion: BrainParameterVersion,
    payloads: [BrainParameterPayload]
  ) throws {
    let canonical = payloads.sorted { $0.kind.rawValue < $1.kind.rawValue }
    guard Set(canonical.map(\.kind)).count == canonical.count,
      Set(canonical.map(\.kind)) == Set(Self.requiredKinds)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "shared parameter artifact does not contain every required component"
      )
    }
    for payload in canonical {
      guard let component = parameterVersion.components.first(where: {
        $0.kind == payload.kind
      }), component.elementType == payload.elementType,
        component.byteCount == UInt64(payload.data.count),
        component.contentFingerprint == payload.contentFingerprint
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "shared parameter payload does not match the version manifest"
        )
      }
    }
    var hash: UInt64 = 14_695_981_039_346_656_037
    Self.mix(UInt64(Self.formatVersion), into: &hash)
    Self.mix(parameterVersion.fingerprint, into: &hash)
    for payload in canonical {
      Self.mix(UInt64(payload.kind.rawValue), into: &hash)
      Self.mix(payload.contentFingerprint, into: &hash)
      Self.mix(UInt64(payload.data.count), into: &hash)
    }
    self.formatVersion = Self.formatVersion
    self.parameterVersionFingerprint = parameterVersion.fingerprint
    self.payloads = canonical
    self.artifactFingerprint = hash
  }

  public func payload(_ kind: BrainParameterComponentKind) -> BrainParameterPayload {
    payloads.first(where: { $0.kind == kind })!
  }

  public func validate(parameterVersion: BrainParameterVersion) throws {
    guard formatVersion == Self.formatVersion,
      parameterVersionFingerprint == parameterVersion.fingerprint,
      Set(payloads.map(\.kind)) == Set(Self.requiredKinds),
      Set(payloads.map(\.kind)).count == payloads.count
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "shared parameter artifact identity is invalid"
      )
    }
    for payload in payloads {
      guard payload.contentFingerprint == BrainParameterPayload.fingerprint(payload.data),
        let component = parameterVersion.components.first(where: {
          $0.kind == payload.kind
        }), component.elementType == payload.elementType,
        component.byteCount == UInt64(payload.data.count),
        component.contentFingerprint == payload.contentFingerprint
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "shared parameter artifact payload validation failed"
        )
      }
    }
    var hash: UInt64 = 14_695_981_039_346_656_037
    Self.mix(UInt64(Self.formatVersion), into: &hash)
    Self.mix(parameterVersion.fingerprint, into: &hash)
    for payload in payloads.sorted(by: { $0.kind.rawValue < $1.kind.rawValue }) {
      Self.mix(UInt64(payload.kind.rawValue), into: &hash)
      Self.mix(payload.contentFingerprint, into: &hash)
      Self.mix(UInt64(payload.data.count), into: &hash)
    }
    guard artifactFingerprint == hash else {
      throw BrainRuntimeError.invalidParameterVersion(
        "shared parameter artifact fingerprint mismatch"
      )
    }
  }

  public func encoded(parameterVersion: BrainParameterVersion) throws -> Data {
    try validate(parameterVersion: parameterVersion)
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    return try encoder.encode(self)
  }

  public static func decode(
    _ data: Data,
    parameterVersion: BrainParameterVersion
  ) throws -> Self {
    let artifact = try PropertyListDecoder().decode(Self.self, from: data)
    try artifact.validate(parameterVersion: parameterVersion)
    return artifact
  }

  public func write(
    to url: URL,
    parameterVersion: BrainParameterVersion,
    options: Data.WritingOptions = [.atomic]
  ) throws {
    try encoded(parameterVersion: parameterVersion).write(to: url, options: options)
  }

  public static func foundationPayloads(
    regionalDenseElementCount: Int = 1
  ) throws -> [BrainParameterPayload] {
    guard regionalDenseElementCount > 0 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "regional dense parameter count must be positive"
      )
    }
    func payload(
      _ kind: BrainParameterComponentKind,
      _ values: [Float]
    ) throws -> BrainParameterPayload {
      let data = values.withUnsafeBytes { Data($0) }
      return try BrainParameterPayload(kind: kind, elementType: .fp32, data: data)
    }

    var sensory = [Float](repeating: 0, count: 64)
    sensory.replaceSubrange(0...7, with: [1, 0.05, 0.1, 1, 0.25, 0.5, 0.01, 0.99])
    var belief = [Float](repeating: 0, count: 64)
    belief.replaceSubrange(0...7, with: [0.2, 0.1, 0.05, 0.25, 0.1, 0.05, 0.01, 0.99])
    var world = [Float](repeating: 0, count: 192)
    for level in 0..<5 {
      for head in 0..<5 {
        let base = (level * 5 + head) * 6
        world[base] = 0.58 + (Float(head) - 2) * 0.035
        world[base + 1] = 0.24
        world[base + 2] = 0.10
        world[base + 3] = 0.05
        world[base + 4] = 0.03
        world[base + 5] = 0
      }
    }
    world.replaceSubrange(150...157, with: [0.15, 0.05, 0.1, 0.25, 0.1, 0.01, 0.99, 1])
    var route = [Float](repeating: 0, count: 64)
    route.replaceSubrange(0...7, with: [1, 1, 1, 1, 0.1, 0.25, 0.01, 0.99])
    var memory = [Float](repeating: 0, count: 64)
    memory.replaceSubrange(0...7, with: [1, 1, 1, 1, 0.2, 0.25, 0.1, 0.99])
    var value = [Float](repeating: 0, count: 64)
    value.replaceSubrange(0...7, with: [1, 1, 1, 1, 2, 1, 1, 1])
    var policy = [Float](repeating: 0, count: 128)
    policy.replaceSubrange(0...15, with: [
      1, 1, 1, 1, 2, 1, 1, 1,
      0.1, 0.25, 0.05, 0.55, 0.25, 0.20, 0.05, 0.99,
    ])
    var motor = [Float](repeating: 0, count: 64)
    motor.replaceSubrange(0...15, with: [
      1, 0.75, 0.5, 1, 1, 1, 1, 1,
      0.15, 0.1, 0.05, 0.25, 0.1, 0.01, 0.99, 1,
    ])
    var cerebellar = [Float](repeating: 0, count: 64)
    cerebellar.replaceSubrange(0...7, with: [0.25, 0.1, 0.05, 1, 0.1, 0.01, 0.99, 1])
    var plasticity = [Float](repeating: 0, count: 64)
    plasticity.replaceSubrange(0...7, with: [0.001, 0.95, 0.95, 1, 0.1, 0.01, 0.99, 1])
    // Small deterministic zero-mean weights activate a true dense local path
    // without overwhelming the explicit recurrent residual at initialization.
    var regionalDense = [Float](repeating: 0, count: regionalDenseElementCount)
    for index in regionalDense.indices {
      var bits = UInt64(index) &+ 0x9e37_79b9_7f4a_7c15
      bits = (bits ^ (bits >> 30)) &* 0xbf58_476d_1ce4_e5b9
      bits = (bits ^ (bits >> 27)) &* 0x94d0_49bb_1331_11eb
      bits ^= bits >> 31
      let centered = Float(Int(bits & 0xffff) - 32_768) / 32_768
      regionalDense[index] = centered * 0.025
    }
    return try [
      payload(.sensory, sensory), payload(.belief, belief),
      payload(.world, world), payload(.route, route),
      payload(.memory, memory), payload(.value, value),
      payload(.policy, policy), payload(.motor, motor),
      payload(.cerebellar, cerebellar), payload(.plasticity, plasticity),
      payload(.regionalDense, regionalDense),
    ]
  }

  public static func foundation(
    parameterVersion: BrainParameterVersion
  ) throws -> Self {
    guard let denseComponent = parameterVersion.components.first(where: {
      $0.kind == .regionalDense
    }), denseComponent.elementType == .fp32,
      denseComponent.elementCount <= UInt64(Int.max)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "parameter version is missing executable regional dense weights"
      )
    }
    return try Self(
      parameterVersion: parameterVersion,
      payloads: foundationPayloads(
        regionalDenseElementCount: Int(denseComponent.elementCount)
      )
    )
  }

  public static func successor(
    parentVersion: BrainParameterVersion,
    updatedPayloads: [BrainParameterPayload]
  ) throws -> (version: BrainParameterVersion, artifact: Self) {
    let updatedKinds = Set(updatedPayloads.map(\.kind))
    guard updatedKinds == Set(requiredKinds),
      updatedPayloads.count == requiredKinds.count
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "successor must replace every shared slow component atomically"
      )
    }
    let retainedComponents = parentVersion.components.filter {
      !updatedKinds.contains($0.kind)
    }
    let updatedComponents = try updatedPayloads.map { try $0.component }
    let version = try parentVersion.successor(
      regionalProgramFingerprint: parentVersion.regionalProgramFingerprint,
      components: retainedComponents + updatedComponents
    )
    let artifact = try Self(
      parameterVersion: version,
      payloads: updatedPayloads
    )
    return (version, artifact)
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    var value = value.littleEndian
    withUnsafeBytes(of: &value) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}
