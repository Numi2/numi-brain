public enum TissueUniformIndex: Int, Sendable {
  case width = 0
  case height = 1
  case timestepMilliseconds = 2
  case timeMilliseconds = 3
  case excitatoryTimeConstant = 4
  case inhibitoryTimeConstant = 5
  case adaptationTimeConstant = 6
  case axonalRelayTimeConstant = 7
  case excitatorySelfWeight = 8
  case inhibitoryToExcitatoryWeight = 9
  case excitatoryToInhibitoryWeight = 10
  case inhibitorySelfWeight = 11
  case excitatorySpatialMix = 12
  case inhibitorySpatialMix = 13
  case adaptationStrength = 14
  case longRangeProjectionGain = 15
  case excitatoryBias = 16
  case inhibitoryBias = 17
  case excitatoryGain = 18
  case inhibitoryGain = 19
  case stimulusCenterX = 20
  case stimulusCenterY = 21
  case stimulusRadius = 22
  case stimulusExcitatoryDrive = 23
  case stimulusInhibitoryDrive = 24
  case stimulusStartMilliseconds = 25
  case stimulusEndMilliseconds = 26
  case historyStep = 27
  case historyCapacity = 28
  case historyOwnerMask = 29
  case historyWriteSlot = 30
  case historyWritePlane = 31
  case eventCount = 32
  case randomSeed = 33
  case randomEnvironmentIdentifier = 34
  case randomEpisodeIdentifier = 35
  case randomModuleIdentifier = 36
  case acceptedStepLow = 37
  case acceptedStepHigh = 38
  case currentTimestampLow = 39
  case currentTimestampHigh = 40
  case candidateTimestampLow = 41
  case candidateTimestampHigh = 42
  case nominalTimestepMicrosecondsLow = 43
  case nominalTimestepMicrosecondsHigh = 44
}

public enum TissueUniforms {
  public static let count = 45
  public static let byteCount = count * MemoryLayout<Float>.stride

  public static func encode(
    width: Int,
    height: Int,
    timeMilliseconds: Float,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    historyStep: UInt32 = 0,
    historyOwnerMask: UInt32 = 0,
    historyWriteSlot: UInt32 = 0,
    historyWritePlane: UInt32 = 2,
    eventCount: Int = 0,
    randomContext: TissueRandomContext = .deterministicDefault,
    acceptedStep: UInt64 = 0,
    timestepMilliseconds: Float? = nil,
    currentTimestamp: BrainTimestamp = BrainTimestamp(microseconds: 0),
    candidateTimestamp: BrainTimestamp? = nil
  ) -> [Float] {
    var values = Array(repeating: Float.zero, count: count)
    values[TissueUniformIndex.width.rawValue] = Float(width)
    values[TissueUniformIndex.height.rawValue] = Float(height)
    let integrationTimestep = timestepMilliseconds ?? parameters.timestepMilliseconds
    values[TissueUniformIndex.timestepMilliseconds.rawValue] = integrationTimestep
    values[TissueUniformIndex.timeMilliseconds.rawValue] = timeMilliseconds
    values[TissueUniformIndex.excitatoryTimeConstant.rawValue] =
      parameters.excitatoryTimeConstantMilliseconds
    values[TissueUniformIndex.inhibitoryTimeConstant.rawValue] =
      parameters.inhibitoryTimeConstantMilliseconds
    values[TissueUniformIndex.adaptationTimeConstant.rawValue] =
      parameters.adaptationTimeConstantMilliseconds
    values[TissueUniformIndex.axonalRelayTimeConstant.rawValue] =
      parameters.axonalRelayTimeConstantMilliseconds
    values[TissueUniformIndex.excitatorySelfWeight.rawValue] = parameters.excitatorySelfWeight
    values[TissueUniformIndex.inhibitoryToExcitatoryWeight.rawValue] =
      parameters.inhibitoryToExcitatoryWeight
    values[TissueUniformIndex.excitatoryToInhibitoryWeight.rawValue] =
      parameters.excitatoryToInhibitoryWeight
    values[TissueUniformIndex.inhibitorySelfWeight.rawValue] = parameters.inhibitorySelfWeight
    values[TissueUniformIndex.excitatorySpatialMix.rawValue] = parameters.excitatorySpatialMix
    values[TissueUniformIndex.inhibitorySpatialMix.rawValue] = parameters.inhibitorySpatialMix
    values[TissueUniformIndex.adaptationStrength.rawValue] = parameters.adaptationStrength
    values[TissueUniformIndex.longRangeProjectionGain.rawValue] =
      parameters.longRangeProjectionGain
    values[TissueUniformIndex.excitatoryBias.rawValue] = parameters.excitatoryBias
    values[TissueUniformIndex.inhibitoryBias.rawValue] = parameters.inhibitoryBias
    values[TissueUniformIndex.excitatoryGain.rawValue] = parameters.excitatoryGain
    values[TissueUniformIndex.inhibitoryGain.rawValue] = parameters.inhibitoryGain
    values[TissueUniformIndex.stimulusCenterX.rawValue] = stimulus.centerX
    values[TissueUniformIndex.stimulusCenterY.rawValue] = stimulus.centerY
    values[TissueUniformIndex.stimulusRadius.rawValue] = stimulus.radius
    values[TissueUniformIndex.stimulusExcitatoryDrive.rawValue] = stimulus.excitatoryDrive
    values[TissueUniformIndex.stimulusInhibitoryDrive.rawValue] = stimulus.inhibitoryDrive
    values[TissueUniformIndex.stimulusStartMilliseconds.rawValue] = stimulus.startMilliseconds
    values[TissueUniformIndex.stimulusEndMilliseconds.rawValue] = stimulus.endMilliseconds
    values[TissueUniformIndex.historyStep.rawValue] = Float(historyStep)
    values[TissueUniformIndex.historyCapacity.rawValue] = Float(TissueDelayField.historyCapacity)
    values[TissueUniformIndex.historyOwnerMask.rawValue] = Float(bitPattern: historyOwnerMask)
    values[TissueUniformIndex.historyWriteSlot.rawValue] = Float(historyWriteSlot)
    values[TissueUniformIndex.historyWritePlane.rawValue] = Float(historyWritePlane)
    values[TissueUniformIndex.eventCount.rawValue] = Float(eventCount)
    values[TissueUniformIndex.randomSeed.rawValue] = Float(bitPattern: randomContext.seed)
    values[TissueUniformIndex.randomEnvironmentIdentifier.rawValue] = Float(
      bitPattern: randomContext.environmentIdentifier
    )
    values[TissueUniformIndex.randomEpisodeIdentifier.rawValue] = Float(
      bitPattern: randomContext.episodeIdentifier
    )
    values[TissueUniformIndex.randomModuleIdentifier.rawValue] = Float(
      bitPattern: randomContext.moduleIdentifier
    )
    values[TissueUniformIndex.acceptedStepLow.rawValue] = Float(
      bitPattern: UInt32(truncatingIfNeeded: acceptedStep)
    )
    values[TissueUniformIndex.acceptedStepHigh.rawValue] = Float(
      bitPattern: UInt32(truncatingIfNeeded: acceptedStep >> 32)
    )
    let candidateTimestamp = candidateTimestamp ?? currentTimestamp
    values[TissueUniformIndex.currentTimestampLow.rawValue] = Float(
      bitPattern: UInt32(truncatingIfNeeded: currentTimestamp.rawValue)
    )
    values[TissueUniformIndex.currentTimestampHigh.rawValue] = Float(
      bitPattern: UInt32(truncatingIfNeeded: currentTimestamp.rawValue >> 32)
    )
    values[TissueUniformIndex.candidateTimestampLow.rawValue] = Float(
      bitPattern: UInt32(truncatingIfNeeded: candidateTimestamp.rawValue)
    )
    values[TissueUniformIndex.candidateTimestampHigh.rawValue] = Float(
      bitPattern: UInt32(truncatingIfNeeded: candidateTimestamp.rawValue >> 32)
    )
    let nominalTimestepMicroseconds = UInt64(
      (Double(parameters.timestepMilliseconds) * 1_000).rounded()
    )
    values[TissueUniformIndex.nominalTimestepMicrosecondsLow.rawValue] = Float(
      bitPattern: UInt32(truncatingIfNeeded: nominalTimestepMicroseconds)
    )
    values[TissueUniformIndex.nominalTimestepMicrosecondsHigh.rawValue] = Float(
      bitPattern: UInt32(truncatingIfNeeded: nominalTimestepMicroseconds >> 32)
    )
    return values
  }
}
