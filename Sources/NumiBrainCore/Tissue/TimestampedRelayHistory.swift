import Foundation

/// Physical-time axonal relay history for variable-duration accepted substeps.
/// The immutable origin sample supplies the pre-simulation boundary condition;
/// later samples live in a bounded chronological ring.
public struct TimestampedRelayHistory: Equatable, Sendable {
  public let siteCount: Int
  public let capacity: Int
  public let originTimestamp: BrainTimestamp

  private let originValues: [Float]
  private var timestamps: [UInt64]
  private var values: [Float]
  private var startIndex: Int
  public private(set) var sampleCount: Int

  public init(
    originTimestamp: BrainTimestamp,
    values originValues: [Float],
    capacity: Int = TissueDelayField.historyCapacity
  ) throws {
    guard !originValues.isEmpty, originValues.allSatisfy(\.isFinite) else {
      throw TissueError.invalidConduction(
        "timestamped relay history requires finite nonempty origin values"
      )
    }
    guard capacity > 0 else {
      throw TissueError.invalidConduction("timestamped relay history capacity must be positive")
    }
    let (valueCount, overflow) = capacity.multipliedReportingOverflow(
      by: originValues.count
    )
    guard !overflow else {
      throw TissueError.invalidConduction("timestamped relay history storage overflows Int")
    }
    siteCount = originValues.count
    self.capacity = capacity
    self.originTimestamp = originTimestamp
    self.originValues = originValues
    timestamps = Array(repeating: 0, count: capacity)
    values = Array(repeating: 0, count: valueCount)
    startIndex = 0
    sampleCount = 1
    timestamps[0] = originTimestamp.rawValue
    values.replaceSubrange(0..<siteCount, with: originValues)
  }

  public var oldestTimestamp: BrainTimestamp {
    BrainTimestamp(microseconds: timestamps[startIndex])
  }

  public var newestTimestamp: BrainTimestamp {
    BrainTimestamp(microseconds: timestamps[physicalIndex(forLogicalIndex: sampleCount - 1)])
  }

  /// Appends one accepted population state. Candidate or rejected states must
  /// never call this method.
  public mutating func append(
    timestamp: BrainTimestamp,
    values newValues: [Float]
  ) throws {
    guard newValues.count == siteCount, newValues.allSatisfy(\.isFinite) else {
      throw TissueError.invalidConduction(
        "timestamped relay sample does not match the finite population shape"
      )
    }
    guard timestamp > newestTimestamp else {
      throw TissueError.invalidConduction(
        "timestamped relay samples must advance physical time strictly"
      )
    }

    let destination: Int
    if sampleCount < capacity {
      destination = physicalIndex(forLogicalIndex: sampleCount)
      sampleCount += 1
    } else {
      destination = startIndex
      startIndex = (startIndex + 1) % capacity
    }
    timestamps[destination] = timestamp.rawValue
    let valueStart = destination * siteCount
    values.replaceSubrange(valueStart..<(valueStart + siteCount), with: newValues)
  }

  /// Samples the population at `currentTimestamp - delayMicroseconds` using
  /// deterministic linear interpolation. A target at or before the immutable
  /// origin uses the origin boundary value. Losing a later bracket is an
  /// explicit capacity error rather than a silent, temporally wrong fallback.
  public func sample(
    at currentTimestamp: BrainTimestamp,
    delayMicroseconds: UInt64
  ) throws -> [Float] {
    switch try sampleLocation(
      at: currentTimestamp,
      delayMicroseconds: delayMicroseconds
    ) {
    case .origin:
      return originValues
    case .exact(let physicalIndex):
      return sampleValues(atPhysicalIndex: physicalIndex)
    case .interpolated(let lowerIndex, let upperIndex, let fraction):
      let lowerStart = lowerIndex * siteCount
      let upperStart = upperIndex * siteCount
      return (0..<siteCount).map { siteIndex in
        let lower = values[lowerStart + siteIndex]
        return lower + fraction * (values[upperStart + siteIndex] - lower)
      }
    }
  }

  public func sample(
    siteIndex: Int,
    at currentTimestamp: BrainTimestamp,
    delayMicroseconds: UInt64
  ) throws -> Float {
    guard values.indices.contains(siteIndex), siteIndex < siteCount else {
      throw TissueError.invalidConduction("relay sample site index is out of bounds")
    }
    switch try sampleLocation(
      at: currentTimestamp,
      delayMicroseconds: delayMicroseconds
    ) {
    case .origin:
      return originValues[siteIndex]
    case .exact(let physicalIndex):
      return values[physicalIndex * siteCount + siteIndex]
    case .interpolated(let lowerIndex, let upperIndex, let fraction):
      let lower = values[lowerIndex * siteCount + siteIndex]
      let upper = values[upperIndex * siteCount + siteIndex]
      return lower + fraction * (upper - lower)
    }
  }

  private enum SampleLocation {
    case origin
    case exact(Int)
    case interpolated(Int, Int, Float)
  }

  private func sampleLocation(
    at currentTimestamp: BrainTimestamp,
    delayMicroseconds: UInt64
  ) throws -> SampleLocation {
    guard currentTimestamp >= originTimestamp else {
      throw TissueError.invalidConduction(
        "relay sampling time precedes the history origin"
      )
    }
    let targetValue: UInt64
    if delayMicroseconds >= currentTimestamp.rawValue - originTimestamp.rawValue {
      targetValue = originTimestamp.rawValue
    } else {
      targetValue = currentTimestamp.rawValue - delayMicroseconds
    }
    if targetValue <= originTimestamp.rawValue {
      return .origin
    }

    let oldest = timestamps[startIndex]
    guard targetValue >= oldest else {
      throw TissueError.invalidConduction(
        "relay history no longer covers target timestamp \(targetValue) us"
      )
    }
    let newestIndex = physicalIndex(forLogicalIndex: sampleCount - 1)
    let newest = timestamps[newestIndex]
    if targetValue >= newest {
      return .exact(newestIndex)
    }

    for upperLogicalIndex in 1..<sampleCount {
      let upperIndex = physicalIndex(forLogicalIndex: upperLogicalIndex)
      let upperTimestamp = timestamps[upperIndex]
      guard upperTimestamp >= targetValue else { continue }
      let lowerIndex = physicalIndex(forLogicalIndex: upperLogicalIndex - 1)
      let lowerTimestamp = timestamps[lowerIndex]
      if upperTimestamp == targetValue {
        return .exact(upperIndex)
      }
      let denominator = upperTimestamp - lowerTimestamp
      guard denominator > 0 else {
        throw TissueError.invalidConduction("relay history timestamp order is invalid")
      }
      let fraction = Float(
        Double(targetValue - lowerTimestamp) / Double(denominator)
      )
      return .interpolated(lowerIndex, upperIndex, fraction)
    }
    throw TissueError.invalidConduction("relay history could not bracket its target timestamp")
  }

  public func stableHash() -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    @inline(__always)
    func mix(_ byte: UInt8, into hash: inout UInt64) {
      hash ^= UInt64(byte)
      hash &*= 0x100_0000_01b3
    }
    func mixInteger<T: FixedWidthInteger>(_ value: T, into hash: inout UInt64) {
      var littleEndian = value.littleEndian
      withUnsafeBytes(of: &littleEndian) { bytes in
        for byte in bytes { mix(byte, into: &hash) }
      }
    }
    func mixFloat(_ value: Float, into hash: inout UInt64) {
      mixInteger(value.bitPattern, into: &hash)
    }

    mixInteger(UInt64(siteCount), into: &hash)
    mixInteger(UInt64(capacity), into: &hash)
    mixInteger(originTimestamp.rawValue, into: &hash)
    for value in originValues { mixFloat(value, into: &hash) }
    mixInteger(UInt64(sampleCount), into: &hash)
    for logicalIndex in 0..<sampleCount {
      let physicalIndex = physicalIndex(forLogicalIndex: logicalIndex)
      mixInteger(timestamps[physicalIndex], into: &hash)
      let valueStart = physicalIndex * siteCount
      for siteIndex in 0..<siteCount {
        mixFloat(values[valueStart + siteIndex], into: &hash)
      }
    }
    return String(format: "%016llx", hash)
  }

  private func physicalIndex(forLogicalIndex logicalIndex: Int) -> Int {
    (startIndex + logicalIndex) % capacity
  }

  private func sampleValues(atPhysicalIndex physicalIndex: Int) -> [Float] {
    let valueStart = physicalIndex * siteCount
    return Array(values[valueStart..<(valueStart + siteCount)])
  }
}
