import Foundation

public struct ReachHoldObjective: Codable, Equatable, Sendable {
  public let targetPositionMeters: [Double]
  public let durationMicroseconds: UInt64
  public let holdDurationMicroseconds: UInt64
  public let maximumSampleGapMicroseconds: UInt64
  public let positionScaleMeters: Double
  public let maximumHoldErrorMeters: Double
  public let maximumHoldSecantSpeedMetersPerSecond: Double
  public let maximumMeanSquaredExcitation: Double
  public let effortWeight: Double

  public init(targetPositionMeters: [Double], durationMicroseconds: UInt64,
    holdDurationMicroseconds: UInt64, maximumSampleGapMicroseconds: UInt64,
    positionScaleMeters: Double, maximumHoldErrorMeters: Double,
    maximumHoldSecantSpeedMetersPerSecond: Double,
    maximumMeanSquaredExcitation: Double, effortWeight: Double) throws {
    self.targetPositionMeters = targetPositionMeters; self.durationMicroseconds = durationMicroseconds
    self.holdDurationMicroseconds = holdDurationMicroseconds; self.maximumSampleGapMicroseconds = maximumSampleGapMicroseconds
    self.positionScaleMeters = positionScaleMeters; self.maximumHoldErrorMeters = maximumHoldErrorMeters
    self.maximumHoldSecantSpeedMetersPerSecond = maximumHoldSecantSpeedMetersPerSecond
    self.maximumMeanSquaredExcitation = maximumMeanSquaredExcitation; self.effortWeight = effortWeight
    try validate()
  }
  public func validate() throws {
    guard (1...3).contains(targetPositionMeters.count), targetPositionMeters.allSatisfy(\.isFinite),
      durationMicroseconds >= 1_000_000, holdDurationMicroseconds >= 250_000,
      holdDurationMicroseconds < durationMicroseconds,
      maximumSampleGapMicroseconds > 0, maximumSampleGapMicroseconds <= holdDurationMicroseconds / 4,
      [positionScaleMeters, maximumHoldErrorMeters, maximumHoldSecantSpeedMetersPerSecond]
        .allSatisfy({ $0.isFinite && $0 > 0 }),
      maximumMeanSquaredExcitation.isFinite, (0...1).contains(maximumMeanSquaredExcitation),
      effortWeight.isFinite, effortWeight >= 0 else {
      throw PhysicalValidationError.invalid("invalid reach/hold horizon, physical scales or effort contract")
    }
  }
}

/// Position is in the task's explicitly named physical frame, not a belief or
/// privileged observation silently exposed to the policy. Invalid samples are
/// rejected; they are never discarded to improve a task score.
public struct ReachHoldPositionSample: Codable, Equatable, Sendable {
  public let timestampMicroseconds: UInt64
  public let positionMeters: [Double]
  public init(timestampMicroseconds: UInt64, positionMeters: [Double]) {
    self.timestampMicroseconds = timestampMicroseconds; self.positionMeters = positionMeters
  }
}

/// Command effort uses its actual application interval, independently of the
/// delayed receptor acquisition clock. It is excitation squared, NOT measured
/// mechanical work, tendon force or metabolic energy.
public struct ReachHoldCommandInterval: Codable, Equatable, Sendable {
  public let startMicroseconds: UInt64
  public let endMicroseconds: UInt64
  public let meanSquaredExcitation: Double
  public init(startMicroseconds: UInt64, endMicroseconds: UInt64, meanSquaredExcitation: Double) {
    self.startMicroseconds = startMicroseconds; self.endMicroseconds = endMicroseconds
    self.meanSquaredExcitation = meanSquaredExcitation
  }
}

public struct ReachHoldResult: Codable, Equatable, Sendable {
  public let normalizedTrackingMSE: Double
  public let meanSquaredExcitation: Double
  public let terminalHoldPeakErrorMeters: Double
  public let terminalHoldPeakSecantSpeedMetersPerSecond: Double
  public let measuredDurationMicroseconds: UInt64
  public let objectiveLoss: Double
  public let failures: [String]
  public var succeeds: Bool { failures.isEmpty }
}

public enum ReachHoldEvaluator {
  /// Offline physical objective. Piecewise-linear integration weights elapsed
  /// physical time, not capture density. Secant speed cannot certify unresolved
  /// between-sample transients; capture-rate and native velocity studies remain required.
  public static func evaluate(objective: ReachHoldObjective, positions: [ReachHoldPositionSample],
    commands: [ReachHoldCommandInterval], rejectedAttempts: UInt64 = 0,
    commandFailures: UInt64 = 0) throws -> ReachHoldResult {
    try objective.validate()
    guard positions.count >= 2, positions.count <= 1_000_000,
      !commands.isEmpty, commands.count <= 1_000_000 else { throw PhysicalValidationError.invalid("invalid task trace size") }
    let first = positions[0].timestampMicroseconds, last = positions[positions.count - 1].timestampMicroseconds
    guard last > first, last - first == objective.durationMicroseconds else {
      throw PhysicalValidationError.invalid("reach/hold trace does not cover the exact predeclared physical horizon")
    }
    let holdStart = last - objective.holdDurationMicroseconds
    let dimension = objective.targetPositionMeters.count
    for sample in positions {
      guard sample.positionMeters.count == dimension, sample.positionMeters.allSatisfy(\.isFinite) else {
        throw PhysicalValidationError.invalid("invalid or differently framed task position")
      }
    }
    var tracking = 0.0, holdError = 0.0, holdSpeed = 0.0
    func norm(_ vector: [Double]) throws -> Double {
      let scale = vector.map(abs).max()!
      if scale == 0 { return 0 }
      let value = scale * sqrt(vector.reduce(0) { $0 + ($1 / scale) * ($1 / scale) })
      guard value.isFinite else { throw PhysicalValidationError.invalid("task residual overflow") }
      return value
    }
    for index in 1..<positions.count {
      let a = positions[index - 1], b = positions[index]
      guard b.timestampMicroseconds > a.timestampMicroseconds,
        b.timestampMicroseconds - a.timestampMicroseconds <= objective.maximumSampleGapMicroseconds else {
        throw PhysicalValidationError.invalid("nonmonotone task clock or excessive observation gap")
      }
      let dt = b.timestampMicroseconds - a.timestampMicroseconds
      let ea = zip(a.positionMeters, objective.targetPositionMeters).map(-)
      let eb = zip(b.positionMeters, objective.targetPositionMeters).map(-)
      let integral = zip(ea, eb).reduce(0.0) { sum, pair in
        let x = pair.0 / objective.positionScaleMeters, y = pair.1 / objective.positionScaleMeters
        return sum + (x * x + x * y + y * y) / 3
      }
      tracking += integral * Double(dt) / Double(objective.durationMicroseconds)
      if b.timestampMicroseconds > holdStart {
        let fraction = a.timestampMicroseconds < holdStart ? Double(holdStart - a.timestampMicroseconds) / Double(dt) : 0
        let beginError = zip(ea, eb).map { (1 - fraction) * $0 + fraction * $1 }
        holdError = max(holdError, try norm(beginError), try norm(eb))
        let velocity = zip(b.positionMeters, a.positionMeters).map { ($0 - $1) / (Double(dt) / 1_000_000) }
        holdSpeed = max(holdSpeed, try norm(velocity))
      }
    }
    var covered = first, effort = 0.0, previousEnd: UInt64?
    for command in commands {
      guard command.endMicroseconds > command.startMicroseconds,
        command.meanSquaredExcitation.isFinite, (0...1).contains(command.meanSquaredExcitation),
        previousEnd == nil || command.startMicroseconds >= previousEnd! else {
        throw PhysicalValidationError.invalid("invalid, overlapping or out-of-order applied command interval")
      }
      previousEnd = command.endMicroseconds
      let start = max(first, command.startMicroseconds), end = min(last, command.endMicroseconds)
      if end <= start { continue }
      guard start == covered else { throw PhysicalValidationError.invalid("missing physical command coverage") }
      effort += command.meanSquaredExcitation * Double(end - start) / Double(objective.durationMicroseconds)
      covered = end
    }
    guard covered == last else { throw PhysicalValidationError.invalid("incomplete command horizon") }
    let loss = tracking + objective.effortWeight * effort
    guard [tracking, effort, holdError, holdSpeed, loss].allSatisfy({ $0.isFinite && $0 >= 0 }) else {
      throw PhysicalValidationError.invalid("reach/hold objective overflow")
    }
    var failures: [String] = []
    if holdError > objective.maximumHoldErrorMeters { failures.append("hold_position_error") }
    if holdSpeed > objective.maximumHoldSecantSpeedMetersPerSecond { failures.append("hold_secant_speed") }
    if effort > objective.maximumMeanSquaredExcitation { failures.append("excitation_effort") }
    if rejectedAttempts > 0 { failures.append("rejected_attempts") }
    if commandFailures > 0 { failures.append("command_failures") }
    return ReachHoldResult(normalizedTrackingMSE: tracking, meanSquaredExcitation: effort,
      terminalHoldPeakErrorMeters: holdError, terminalHoldPeakSecantSpeedMetersPerSecond: holdSpeed,
      measuredDurationMicroseconds: last - first, objectiveLoss: loss, failures: failures)
  }
}
