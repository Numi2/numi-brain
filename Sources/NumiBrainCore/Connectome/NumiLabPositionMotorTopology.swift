import Foundation

extension NumiLabPositionActionEncoder {
  /// Builds the NumiBrain somatic motor contract from an exact compiled
  /// NumiLab position task. This prevents a robot controller from inheriting
  /// `.muscleExcitation` merely because the generic full-body template was
  /// convenient during graph/controller bring-up.
  ///
  /// Sensory, physiology, developmental and regional templates remain separate
  /// owners and are deliberately not synthesized here.
  public func motorTopology(
    neutralCommands: [String: Float],
    emergencyCommands: [String: Float],
    synergyCount: UInt16,
    motorNucleusCount: UInt16,
    autonomicActionDimension: UInt16,
    activeSensingActionDimension: UInt16
  ) throws -> MotorTopology {
    guard isPhysicalOwnerBound, !lanes.isEmpty else {
      throw ConnectomeError.invalid(
        "robot motor topology requires an exact compiled physical-owner task"
      )
    }
    let identifiers = Set(lanes.map(\.actuatorIdentifier))
    guard Set(neutralCommands.keys) == identifiers,
      Set(emergencyCommands.keys) == identifiers else {
      throw ConnectomeError.invalid(
        "every compiled task action requires explicit neutral and emergency positions"
      )
    }
    let channels = try lanes.enumerated().map { index, lane in
      guard let neutral = neutralCommands[lane.actuatorIdentifier],
        let emergency = emergencyCommands[lane.actuatorIdentifier] else {
        throw ConnectomeError.invalid("missing explicit robot command")
      }
      return try ActuatorChannelTemplate(identifier: UInt32(index),
        outputMinimum: lane.minimumPosition, outputMaximum: lane.maximumPosition,
        neutralCommand: neutral, emergencyCommand: emergency)
    }
    guard let outputMinimum = channels.map(\.outputMinimum).min(),
      let outputMaximum = channels.map(\.outputMaximum).max(),
      outputMinimum < outputMaximum else {
      throw ConnectomeError.invalid("compiled robot position range is degenerate")
    }
    return try MotorTopology(actuatorCommandKind: .position,
      actuatorCount: UInt32(channels.count), synergyCount: synergyCount,
      motorNucleusCount: motorNucleusCount,
      autonomicActionDimension: autonomicActionDimension,
      activeSensingActionDimension: activeSensingActionDimension,
      outputMinimum: outputMinimum, outputMaximum: outputMaximum,
      actuatorChannels: channels, communicationEffectors: [])
  }
}
