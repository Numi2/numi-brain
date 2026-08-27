import Foundation
import NumiBrainABI

/// Stable identity for counter-based stochastic tissue samples.
///
/// The context contains no mutable generator state. A sample is derived from
/// this identity, the accepted tissue step, event identifier, site, and sample
/// lane. Retrying an unaccepted physical substep therefore addresses the same
/// random value without advancing a host-side generator.
public struct TissueRandomContext: Equatable, Sendable, Codable {
  public var seed: UInt32
  public var environmentIdentifier: UInt32
  public var episodeIdentifier: UInt32
  public var moduleIdentifier: UInt32

  public init(
    seed: UInt32 = 0,
    environmentIdentifier: UInt32 = 0,
    episodeIdentifier: UInt32 = 0,
    moduleIdentifier: UInt32 = 12
  ) {
    self.seed = seed
    self.environmentIdentifier = environmentIdentifier
    self.episodeIdentifier = episodeIdentifier
    self.moduleIdentifier = moduleIdentifier
  }

  public static let deterministicDefault = TissueRandomContext()
}

public enum TissueCounterRandom {
  @inline(__always)
  private static func combine(_ state: inout UInt32, _ value: UInt32) {
    state &+= value &* 0x9e37_79b9
    state ^= state >> 16
    state &*= 0x7feb_352d
    state ^= state >> 15
    state &*= 0x846c_a68b
    state ^= state >> 16
  }

  /// Returns the shared CPU/Metal counter hash for one stochastic sample.
  public static func sampleBits(
    context: TissueRandomContext,
    acceptedStep: UInt64,
    eventIdentifier: UInt32,
    siteIndex: UInt32,
    sampleIndex: UInt32 = 0
  ) -> UInt32 {
    var state = context.seed ^ 0xa511_e9b3
    combine(&state, context.environmentIdentifier)
    combine(&state, context.episodeIdentifier)
    combine(&state, context.moduleIdentifier)
    combine(&state, UInt32(truncatingIfNeeded: acceptedStep))
    combine(&state, UInt32(truncatingIfNeeded: acceptedStep >> 32))
    combine(&state, eventIdentifier)
    combine(&state, siteIndex)
    combine(&state, sampleIndex)
    return state
  }

  /// Uniform FP32 sample in [0, 1), built from the upper 24 random bits.
  public static func uniform01(
    context: TissueRandomContext,
    acceptedStep: UInt64,
    eventIdentifier: UInt32,
    siteIndex: UInt32,
    sampleIndex: UInt32 = 0
  ) -> Float {
    let bits = sampleBits(
      context: context,
      acceptedStep: acceptedStep,
      eventIdentifier: eventIdentifier,
      siteIndex: siteIndex,
      sampleIndex: sampleIndex
    )
    return Float(bits >> 8) * (1.0 / 16_777_216.0)
  }

  /// Symmetric bounded FP32 sample in [-1, 1).
  public static func symmetricUnit(
    context: TissueRandomContext,
    acceptedStep: UInt64,
    eventIdentifier: UInt32,
    siteIndex: UInt32,
    sampleIndex: UInt32 = 0
  ) -> Float {
    2
      * uniform01(
        context: context,
        acceptedStep: acceptedStep,
        eventIdentifier: eventIdentifier,
        siteIndex: siteIndex,
        sampleIndex: sampleIndex
      ) - 1
  }
}

public struct TissueEventFlags: OptionSet, Equatable, Sendable, Codable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  /// Marks an event as eligible for a future permanent emergency route.
  public static let emergency = TissueEventFlags(rawValue: 1 << 0)
}

/// One receptor-derived neural input event.
///
/// Coordinates are normalized tissue coordinates. Noise is bounded uniform
/// drive noise, independently keyed for the excitatory and inhibitory lanes.
/// This is an input to neural tissue, not raw authoritative physics state.
public struct TissueReceptorEvent: Equatable, Sendable, Codable {
  public var identifier: UInt32
  public var centerX: Float
  public var centerY: Float
  public var radius: Float
  public var excitatoryDrive: Float
  public var inhibitoryDrive: Float
  public var noiseAmplitude: Float
  public var startMilliseconds: Float
  public var endMilliseconds: Float
  public var flags: TissueEventFlags
  public var interruptMask: BrainInterruptMask
  public var conductionLatencyMicroseconds: UInt32
  public var receptorIdentifier: UInt32
  public var magnitude: Float
  public var auxiliaryValue: Float

  public init(
    identifier: UInt32,
    centerX: Float,
    centerY: Float,
    radius: Float,
    excitatoryDrive: Float,
    inhibitoryDrive: Float = 0,
    noiseAmplitude: Float = 0,
    startMilliseconds: Float,
    endMilliseconds: Float,
    flags: TissueEventFlags = [],
    interruptMask: BrainInterruptMask = [],
    conductionLatencyMicroseconds: UInt32 = 0,
    receptorIdentifier: UInt32? = nil,
    magnitude: Float? = nil,
    auxiliaryValue: Float = 0
  ) {
    self.identifier = identifier
    self.centerX = centerX
    self.centerY = centerY
    self.radius = radius
    self.excitatoryDrive = excitatoryDrive
    self.inhibitoryDrive = inhibitoryDrive
    self.noiseAmplitude = noiseAmplitude
    self.startMilliseconds = startMilliseconds
    self.endMilliseconds = endMilliseconds
    self.flags = flags
    self.interruptMask = interruptMask
    self.conductionLatencyMicroseconds = conductionLatencyMicroseconds
    self.receptorIdentifier = receptorIdentifier ?? identifier
    self.magnitude =
      magnitude
      ?? max(abs(excitatoryDrive), abs(inhibitoryDrive)) + noiseAmplitude
    self.auxiliaryValue = auxiliaryValue
  }

  public init(
    stimulus: TissueStimulus,
    identifier: UInt32 = 0,
    noiseAmplitude: Float = 0,
    flags: TissueEventFlags = [],
    interruptMask: BrainInterruptMask = [],
    conductionLatencyMicroseconds: UInt32 = 0,
    receptorIdentifier: UInt32? = nil,
    magnitude: Float? = nil,
    auxiliaryValue: Float = 0
  ) {
    self.init(
      identifier: identifier,
      centerX: stimulus.centerX,
      centerY: stimulus.centerY,
      radius: stimulus.radius,
      excitatoryDrive: stimulus.excitatoryDrive,
      inhibitoryDrive: stimulus.inhibitoryDrive,
      noiseAmplitude: noiseAmplitude,
      startMilliseconds: stimulus.startMilliseconds,
      endMilliseconds: stimulus.endMilliseconds,
      flags: flags,
      interruptMask: interruptMask,
      conductionLatencyMicroseconds: conductionLatencyMicroseconds,
      receptorIdentifier: receptorIdentifier,
      magnitude: magnitude,
      auxiliaryValue: auxiliaryValue
    )
  }

  public func validate() throws {
    let values = [
      centerX, centerY, radius, excitatoryDrive, inhibitoryDrive,
      noiseAmplitude, startMilliseconds, endMilliseconds, magnitude, auxiliaryValue,
    ]
    guard values.allSatisfy(\.isFinite) else {
      throw TissueError.invalidEvents("all event values must be finite")
    }
    guard (0...1).contains(centerX), (0...1).contains(centerY) else {
      throw TissueError.invalidEvents("event center must use normalized [0, 1] coordinates")
    }
    guard radius >= 0, noiseAmplitude >= 0, magnitude >= 0 else {
      throw TissueError.invalidEvents(
        "event radius, noise amplitude, and magnitude must be nonnegative"
      )
    }
    guard endMilliseconds >= startMilliseconds else {
      throw TissueError.invalidEvents("event end time must not precede start time")
    }
    guard
      conductionLatencyMicroseconds
        <= UInt32(NB_RECEPTOR_MAX_CONDUCTION_LATENCY_MICROSECONDS)
    else {
      throw TissueError.invalidEvents("event conduction latency exceeds the receptor ABI limit")
    }
    if !interruptMask.isEmpty, startMilliseconds < 0 {
      throw TissueError.invalidEvents(
        "interrupt-producing receptor events cannot begin before simulation time zero"
      )
    }
  }

  public var abiRecord: NBReceptorEvent {
    var record = NBReceptorEvent()
    record.center_x = centerX
    record.center_y = centerY
    record.radius = radius
    record.start_milliseconds = startMilliseconds
    record.end_milliseconds = endMilliseconds
    record.excitatory_drive = excitatoryDrive
    record.inhibitory_drive = inhibitoryDrive
    record.noise_amplitude = noiseAmplitude
    record.identifier = identifier
    record.flags = flags.rawValue
    record.interrupt_mask = interruptMask.rawValue
    record.conduction_latency_microseconds = conductionLatencyMicroseconds
    record.receptor_identifier = receptorIdentifier
    record.magnitude = magnitude
    record.auxiliary_value = auxiliaryValue
    return record
  }
}

/// Immutable, deterministically ordered receptor-event schedule.
///
/// The first GPU implementation deliberately caps the schedule. It performs a
/// bounded scan in the tissue kernel; dynamic GPU event compaction remains a
/// later runtime-foundation gate.
public struct TissueEventSchedule: Equatable, Sendable {
  public typealias PackedRecord = NBReceptorEvent
  public static let maximumEventCount = 64
  public static let receptorEventByteCount = Int(NB_RECEPTOR_EVENT_BYTE_COUNT)

  public let events: [TissueReceptorEvent]

  public init(events: [TissueReceptorEvent]) throws {
    guard events.count <= Self.maximumEventCount else {
      throw TissueError.invalidEvents(
        "event count exceeds the bounded \(Self.maximumEventCount)-event schedule"
      )
    }
    for event in events {
      try event.validate()
    }
    let canonical = events.sorted(by: Self.canonicalOrder)
    let records = canonical.map(\.abiRecord)
    let validation = records.withUnsafeBufferPointer { buffer in
      nb_brain_abi_validate_receptor_events(buffer.baseAddress, UInt32(buffer.count))
    }
    guard validation == UInt32(NB_RECEPTOR_EVENT_VALID.rawValue) else {
      throw TissueError.invalidEvents(
        "compiled receptor ABI validation failed with code \(validation)"
      )
    }
    self.events = canonical
  }

  private init(validatedEvents: [TissueReceptorEvent]) {
    self.events = validatedEvents
  }

  public var eventCount: Int { events.count }
  public var packedByteCount: Int {
    eventCount * MemoryLayout<PackedRecord>.stride
  }
  public var activeIndexByteCapacity: Int {
    (Self.maximumEventCount + 1) * MemoryLayout<UInt32>.stride
  }
  public var maximumSimultaneouslyActiveEventCount: Int {
    events.lazy
      .filter { $0.radius > 0 && $0.endMilliseconds > $0.startMilliseconds }
      .map { activeEventIndices(at: $0.startMilliseconds).count }
      .max() ?? 0
  }

  public static let empty = TissueEventSchedule(validatedEvents: [])

  public static func singleStimulus(
    _ stimulus: TissueStimulus,
    noiseAmplitude: Float = 0,
    flags: TissueEventFlags = [],
    interruptMask: BrainInterruptMask = [],
    conductionLatencyMicroseconds: UInt32 = 0,
    receptorIdentifier: UInt32? = nil
  ) throws -> TissueEventSchedule {
    try stimulus.validate()
    guard stimulus.radius > 0,
      stimulus.endMilliseconds > stimulus.startMilliseconds,
      stimulus.excitatoryDrive != 0 || stimulus.inhibitoryDrive != 0
        || noiseAmplitude != 0
    else {
      return .empty
    }
    return try TissueEventSchedule(
      events: [
        TissueReceptorEvent(
          stimulus: stimulus,
          noiseAmplitude: noiseAmplitude,
          flags: flags,
          interruptMask: interruptMask,
          conductionLatencyMicroseconds: conductionLatencyMicroseconds,
          receptorIdentifier: receptorIdentifier
        )
      ]
    )
  }

  /// Returns canonical schedule indices active at the supplied physical time.
  /// Intervals are half-open and zero-radius records never enter the active set.
  public func activeEventIndices(at timeMilliseconds: Float) -> [UInt32] {
    guard timeMilliseconds.isFinite else { return [] }
    return events.indices.compactMap { index in
      let event = events[index]
      guard event.radius > 0,
        timeMilliseconds >= event.startMilliseconds,
        timeMilliseconds < event.endMilliseconds
      else {
        return nil
      }
      return UInt32(index)
    }
  }

  public func packedRecords() -> [PackedRecord] {
    events.map(\.abiRecord)
  }

  public func stableHash() -> String {
    let records = packedRecords()
    let hash = records.withUnsafeBufferPointer { buffer in
      nb_brain_abi_receptor_event_fingerprint(buffer.baseAddress, UInt32(buffer.count))
    }
    return String(format: "%016llx", hash)
  }

  /// Produces causal event-onset interrupts for a committed scheduler window.
  /// The first root includes its lower boundary; later roots exclude it so an
  /// onset exactly at a committed boundary cannot be delivered twice.
  public func schedulerInterruptEvents(
    committedTime: BrainTimestamp,
    targetTime: BrainTimestamp,
    includeCommittedBoundary: Bool
  ) throws -> [BrainInterruptEvent] {
    guard targetTime >= committedTime else {
      throw TissueError.invalidEvents("scheduler interrupt window runs backward")
    }
    var result: [BrainInterruptEvent] = []
    result.reserveCapacity(events.count)
    for event in events where !event.interruptMask.isEmpty {
      guard event.radius > 0, event.endMilliseconds > event.startMilliseconds else {
        continue
      }
      let onset = try Self.timestampMicroseconds(milliseconds: event.startMilliseconds)
      let (delivered, overflow) = onset.addingReportingOverflow(
        UInt64(event.conductionLatencyMicroseconds)
      )
      guard !overflow else {
        throw TissueError.invalidEvents("receptor interrupt timestamp overflows UInt64")
      }
      let timestamp = BrainTimestamp(microseconds: delivered)
      let afterLowerBound =
        includeCommittedBoundary
        ? timestamp >= committedTime
        : timestamp > committedTime
      guard afterLowerBound, timestamp <= targetTime else { continue }
      result.append(
        try BrainInterruptEvent(
          timestamp: timestamp,
          mask: event.interruptMask,
          identifier: event.receptorIdentifier,
          flags: UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED)
        )
      )
    }
    return result.sorted(by: Self.interruptOrder)
  }

  private static func timestampMicroseconds(milliseconds: Float) throws -> UInt64 {
    guard milliseconds.isFinite, milliseconds >= 0 else {
      throw TissueError.invalidEvents("receptor interrupt time must be nonnegative and finite")
    }
    let scaled = Double(milliseconds) * 1_000
    let rounded = scaled.rounded()
    guard rounded < Double(UInt64.max), abs(scaled - rounded) <= 0.01 else {
      throw TissueError.invalidEvents(
        "receptor interrupt time is not representable in integer microseconds"
      )
    }
    return UInt64(rounded)
  }

  private static func interruptOrder(
    _ lhs: BrainInterruptEvent,
    _ rhs: BrainInterruptEvent
  ) -> Bool {
    if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
    if lhs.identifier != rhs.identifier { return lhs.identifier < rhs.identifier }
    if lhs.mask.rawValue != rhs.mask.rawValue { return lhs.mask.rawValue < rhs.mask.rawValue }
    return lhs.flags < rhs.flags
  }

  private static func canonicalOrder(
    _ lhs: TissueReceptorEvent,
    _ rhs: TissueReceptorEvent
  ) -> Bool {
    if lhs.startMilliseconds != rhs.startMilliseconds {
      return lhs.startMilliseconds < rhs.startMilliseconds
    }
    if lhs.endMilliseconds != rhs.endMilliseconds {
      return lhs.endMilliseconds < rhs.endMilliseconds
    }
    return lhs.identifier < rhs.identifier
  }
}
