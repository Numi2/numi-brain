import Foundation

/// Exact little-endian FP32 field decoding with an explicit owning validity
/// mask. A channel's bit zero must never be assumed to validate every feature.
/// Units/frames and the meaning of each bit remain the owner schema's contract.
public enum PhysicalSensorField {
  public static func decode(values: Data, validity: Data, receptorCount: UInt32,
    featureDimension: UInt32, receptorIndex: UInt32, featureIndex: UInt32,
    requiredValidityMask: UInt32) throws -> (value: Double, valid: Bool) {
    let scalars = UInt64(receptorCount) * UInt64(featureDimension)
    guard receptorCount > 0, featureDimension > 0, scalars <= 1_048_576,
      receptorIndex < receptorCount, featureIndex < featureDimension, requiredValidityMask != 0,
      values.count == Int(scalars) * 4, validity.count == Int(receptorCount) * 4 else {
      throw PhysicalValidationError.invalid("invalid scalar sensor shape, selection or validity mask")
    }
    let index = Int(UInt64(receptorIndex) * UInt64(featureDimension) + UInt64(featureIndex))
    let scalar = values.withUnsafeBytes {
      Float(bitPattern: UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: index * 4, as: UInt32.self)))
    }
    let bits = validity.withUnsafeBytes {
      UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: Int(receptorIndex) * 4, as: UInt32.self))
    }
    guard scalar.isFinite else { throw PhysicalValidationError.invalid("non-finite retained physical field") }
    return (Double(scalar), bits & requiredValidityMask == requiredValidityMask)
  }
}
