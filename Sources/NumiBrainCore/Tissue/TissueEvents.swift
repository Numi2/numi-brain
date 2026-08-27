import Foundation

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
    flags: TissueEventFlags = []
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
  }

  public init(
    stimulus: TissueStimulus,
    identifier: UInt32 = 0,
    noiseAmplitude: Float = 0,
    flags: TissueEventFlags = []
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
      flags: flags
    )
  }

  public func validate() throws {
    let values = [
      centerX, centerY, radius, excitatoryDrive, inhibitoryDrive,
      noiseAmplitude, startMilliseconds, endMilliseconds,
    ]
    guard values.allSatisfy(\.isFinite) else {
      throw TissueError.invalidEvents("all event values must be finite")
    }
    guard (0...1).contains(centerX), (0...1).contains(centerY) else {
      throw TissueError.invalidEvents("event center must use normalized [0, 1] coordinates")
    }
    guard radius >= 0, noiseAmplitude >= 0 else {
      throw TissueError.invalidEvents("event radius and noise amplitude must be nonnegative")
    }
    guard endMilliseconds >= startMilliseconds else {
      throw TissueError.invalidEvents("event end time must not precede start time")
    }
  }
}

/// Immutable, deterministically ordered receptor-event schedule.
///
/// The first GPU implementation deliberately caps the schedule. It performs a
/// bounded scan in the tissue kernel; dynamic GPU event compaction remains a
/// later runtime-foundation gate.
public struct TissueEventSchedule: Equatable, Sendable {
  public typealias PackedVector = SIMD4<Float>
  public static let maximumEventCount = 64
  public static let packedVectorsPerEvent = 3

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
    guard Set(events.map(\.identifier)).count == events.count else {
      throw TissueError.invalidEvents("event identifiers must be unique")
    }
    self.events = events.sorted(by: Self.canonicalOrder)
  }

  private init(validatedEvents: [TissueReceptorEvent]) {
    self.events = validatedEvents
  }

  public var eventCount: Int { events.count }
  public var packedByteCount: Int {
    eventCount * Self.packedVectorsPerEvent * MemoryLayout<PackedVector>.stride
  }

  public static let empty = TissueEventSchedule(validatedEvents: [])

  public static func singleStimulus(
    _ stimulus: TissueStimulus,
    noiseAmplitude: Float = 0
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
          noiseAmplitude: noiseAmplitude
        )
      ]
    )
  }

  public func packedVectors() -> [PackedVector] {
    events.flatMap { event in
      [
        PackedVector(
          event.centerX,
          event.centerY,
          event.radius,
          event.startMilliseconds
        ),
        PackedVector(
          event.endMilliseconds,
          event.excitatoryDrive,
          event.inhibitoryDrive,
          event.noiseAmplitude
        ),
        PackedVector(
          Float(bitPattern: event.identifier),
          Float(bitPattern: event.flags.rawValue),
          0,
          0
        ),
      ]
    }
  }

  public func stableHash() -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    @inline(__always)
    func mix(_ value: UInt32, into hash: inout UInt64) {
      var littleEndian = value.littleEndian
      withUnsafeBytes(of: &littleEndian) { bytes in
        for byte in bytes {
          hash ^= UInt64(byte)
          hash &*= 0x100_0000_01b3
        }
      }
    }
    mix(UInt32(eventCount), into: &hash)
    for event in events {
      mix(event.identifier, into: &hash)
      mix(event.centerX.bitPattern, into: &hash)
      mix(event.centerY.bitPattern, into: &hash)
      mix(event.radius.bitPattern, into: &hash)
      mix(event.excitatoryDrive.bitPattern, into: &hash)
      mix(event.inhibitoryDrive.bitPattern, into: &hash)
      mix(event.noiseAmplitude.bitPattern, into: &hash)
      mix(event.startMilliseconds.bitPattern, into: &hash)
      mix(event.endMilliseconds.bitPattern, into: &hash)
      mix(event.flags.rawValue, into: &hash)
    }
    return String(format: "%016llx", hash)
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
