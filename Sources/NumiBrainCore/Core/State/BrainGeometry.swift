import Foundation

@frozen
public struct BrainVector3: Codable, Equatable, Hashable, Sendable {
  public let x: Float
  public let y: Float
  public let z: Float

  public init(x: Float = 0, y: Float = 0, z: Float = 0) throws {
    guard x.isFinite, y.isFinite, z.isFinite else {
      throw BrainRuntimeError.transaction("brain vector contains a non-finite value")
    }
    self.x = x
    self.y = y
    self.z = z
  }

  public static var zero: Self { get throws { try Self() } }
}

@frozen
public struct BrainQuaternion: Codable, Equatable, Hashable, Sendable {
  public let x: Float
  public let y: Float
  public let z: Float
  public let w: Float

  public init(x: Float = 0, y: Float = 0, z: Float = 0, w: Float = 1) throws {
    guard x.isFinite, y.isFinite, z.isFinite, w.isFinite else {
      throw BrainRuntimeError.transaction("brain quaternion contains a non-finite value")
    }
    let normSquared = x * x + y * y + z * z + w * w
    guard normSquared > 0 else {
      throw BrainRuntimeError.transaction("brain quaternion has zero norm")
    }
    let inverseNorm = 1 / Foundation.sqrt(normSquared)
    self.x = x * inverseNorm
    self.y = y * inverseNorm
    self.z = z * inverseNorm
    self.w = w * inverseNorm
  }

  public static var identity: Self { get throws { try Self() } }
}

@frozen
public struct BrainPoseEstimate: Codable, Equatable, Hashable, Sendable {
  public let position: BrainVector3
  public let orientation: BrainQuaternion
  public let linearVelocity: BrainVector3
  public let angularVelocity: BrainVector3
  public let positionVariance: BrainVector3
  public let orientationVariance: BrainVector3

  public init(
    position: BrainVector3,
    orientation: BrainQuaternion,
    linearVelocity: BrainVector3,
    angularVelocity: BrainVector3,
    positionVariance: BrainVector3,
    orientationVariance: BrainVector3
  ) throws {
    guard positionVariance.x >= 0, positionVariance.y >= 0, positionVariance.z >= 0,
      orientationVariance.x >= 0, orientationVariance.y >= 0,
      orientationVariance.z >= 0
    else {
      throw BrainRuntimeError.transaction("pose variance must be nonnegative")
    }
    self.position = position
    self.orientation = orientation
    self.linearVelocity = linearVelocity
    self.angularVelocity = angularVelocity
    self.positionVariance = positionVariance
    self.orientationVariance = orientationVariance
  }

  public static var origin: Self {
    get throws {
      try Self(
        position: .zero,
        orientation: .identity,
        linearVelocity: .zero,
        angularVelocity: .zero,
        positionVariance: BrainVector3(x: 1, y: 1, z: 1),
        orientationVariance: BrainVector3(x: 1, y: 1, z: 1)
      )
    }
  }
}

@frozen
public struct BrainLatentVector: Codable, Equatable, Hashable, Sendable {
  public let values: [Float]

  public init(values: [Float], expectedCount: Int? = nil) throws {
    guard !values.isEmpty, values.allSatisfy(\.isFinite) else {
      throw BrainRuntimeError.transaction("latent vector must be finite and nonempty")
    }
    if let expectedCount, values.count != expectedCount {
      throw BrainRuntimeError.capacity("latent vector has unexpected dimension")
    }
    self.values = values
  }

  public static func zeros(count: Int) throws -> Self {
    guard count > 0 else {
      throw BrainRuntimeError.capacity("latent vector dimension must be positive")
    }
    return try Self(values: Array(repeating: 0, count: count))
  }
}
