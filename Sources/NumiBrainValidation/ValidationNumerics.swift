import Foundation

public enum PhysicalValidationError: Error, Equatable, Sendable {
  case invalid(String)
}

public enum PhysicalValidationStatus: String, Codable, Sendable {
  case passed, failed, inconclusive
}

/// A dimensionless residual, normalized by an explicitly supplied physical
/// scale. Thresholds are fixed in the experiment protocol, never fit to data.
public struct PhysicalValidationMetric: Codable, Equatable, Sendable {
  public let name: String
  public let residual: Double
  public let tolerance: Double
  public var passes: Bool { residual <= tolerance }

  public init(name: String, residual: Double, tolerance: Double) throws {
    guard !name.isEmpty, residual.isFinite, residual >= 0,
      tolerance.isFinite, tolerance >= 0
    else { throw PhysicalValidationError.invalid("invalid residual metric") }
    self.name = name; self.residual = residual; self.tolerance = tolerance
  }
}

public struct PhysicalValidationResult: Codable, Equatable, Sendable {
  public let status: PhysicalValidationStatus
  public let metrics: [PhysicalValidationMetric]
  public let notes: [String]

  public init(metrics: [PhysicalValidationMetric], notes: [String] = []) throws {
    guard !metrics.isEmpty, Set(metrics.map(\.name)).count == metrics.count,
      metrics.allSatisfy({ $0.residual.isFinite && $0.residual >= 0
        && $0.tolerance.isFinite && $0.tolerance >= 0 })
    else { throw PhysicalValidationError.invalid("invalid validation metrics") }
    self.metrics = metrics; self.notes = notes
    self.status = metrics.allSatisfy(\.passes) ? .passed : .failed
  }

  private init(reason: String) {
    status = .inconclusive; metrics = []; notes = [reason]
  }

  public static func inconclusive(_ reason: String) -> Self { Self(reason: reason) }
}

/// FP64 offline reference arithmetic. This never changes authoritative FP32
/// state, schedules a physical root, or participates in production inference.
enum ValidationNumerics {
  static let maximumElements = 1_048_576

  static func require(_ condition: Bool, _ message: String) throws {
    guard condition else { throw PhysicalValidationError.invalid(message) }
  }

  static func finite(_ values: [Double], count: Int? = nil) throws {
    try require(!values.isEmpty && values.count <= maximumElements
      && (count == nil || values.count == count) && values.allSatisfy(\.isFinite),
      "non-finite or incompatible vector")
  }

  static func positive(_ value: Double, _ name: String) throws {
    try require(value.isFinite && value > 0, "\(name) must be positive and finite")
  }

  static func nonnegative(_ value: Double, _ name: String) throws {
    try require(value.isFinite && value >= 0, "\(name) must be nonnegative and finite")
  }

  static func scales(_ values: [Double], count: Int) throws {
    try finite(values, count: count)
    try require(values.allSatisfy { $0 > 0 }, "physical scales must be positive")
  }

  /// Neumaier compensation; final finiteness is checked rather than silently
  /// allowing overflow to become a passing or unserializable result.
  static func sum(_ values: [Double]) throws -> Double {
    var sum = 0.0, correction = 0.0
    for value in values {
      let next = sum + value
      correction += abs(sum) >= abs(value) ? (sum - next) + value : (value - next) + sum
      sum = next
    }
    let result = sum + correction
    try require(result.isFinite, "reference arithmetic overflow")
    return result
  }

  static func dot(_ a: [Double], _ b: [Double]) throws -> Double {
    try finite(a); try finite(b, count: a.count)
    return try sum(zip(a, b).map(*))
  }

  static func error(_ actual: [Double], _ expected: [Double], scales: [Double]) throws -> Double {
    try finite(actual); try finite(expected, count: actual.count)
    try self.scales(scales, count: actual.count)
    let result = zip(zip(actual, expected), scales).map { abs($0.0.0 - $0.0.1) / $0.1 }.max()!
    try require(result.isFinite, "normalized residual overflow")
    return result
  }

  static func norm(_ values: [Double]) throws -> Double {
    try finite(values)
    let scale = values.map(abs).max()!
    guard scale > 0 else { return 0 }
    let result = scale * sqrt(try sum(values.map { ($0 / scale) * ($0 / scale) }))
    try require(result.isFinite, "norm overflow")
    return result
  }

  static func metric(_ name: String, _ value: Double, _ tolerance: Double) throws -> PhysicalValidationMetric {
    try PhysicalValidationMetric(name: name, residual: value, tolerance: tolerance)
  }
}
