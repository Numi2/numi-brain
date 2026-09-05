import Foundation

public extension QualificationHardwareIdentity {
  func validate() throws {
    guard try Self(machineIdentifier: machineIdentifier, chipIdentifier: chipIdentifier,
      gpuFamily: gpuFamily, memoryBytes: memoryBytes, osBuild: osBuild,
      swiftVersion: swiftVersion, metalVersion: metalVersion) == self else {
      throw QualificationError.invalid("hardware identity is noncanonical")
    }
  }
}

public extension PerformanceWorkloadIdentity {
  func validate() throws {
    guard try Self(identifier: identifier, environmentCount: environmentCount,
      logicalDoF: logicalDoF, attachmentCount: attachmentCount,
      femElementCount: femElementCount, sensorScalarCount: sensorScalarCount,
      modelParameterCount: modelParameterCount, horizonRoots: horizonRoots,
      timestepMicroseconds: timestepMicroseconds, deterministic: deterministic,
      fastMath: fastMath) == self else {
      throw QualificationError.invalid("performance workload identity is noncanonical")
    }
  }
}

public extension LatencyDistribution {
  func validateSummary() throws {
    let values = [minimumMicroseconds, p50Microseconds, p95Microseconds,
      p99Microseconds, maximumMicroseconds, meanMicroseconds]
    guard sampleCount > 0, values.allSatisfy({ $0.isFinite && $0 >= 0 }),
      minimumMicroseconds <= p50Microseconds, p50Microseconds <= p95Microseconds,
      p95Microseconds <= p99Microseconds, p99Microseconds <= maximumMicroseconds,
      meanMicroseconds >= minimumMicroseconds, meanMicroseconds <= maximumMicroseconds else {
      throw QualificationError.invalid("latency summary is invalid")
    }
  }
}

public extension PerformanceCounterSummary {
  func validate() throws {
    guard try Self(gpuActiveFraction: gpuActiveFraction,
      gpuBandwidthBytesPerSecond: gpuBandwidthBytesPerSecond,
      cacheHitFraction: cacheHitFraction, commandBufferCount: commandBufferCount,
      cpuWaitCount: cpuWaitCount,
      queueCreationCountDuringMeasuredRegion: queueCreationCountDuringMeasuredRegion,
      hostPayloadReadbackBytes: hostPayloadReadbackBytes) == self else {
      throw QualificationError.invalid("performance counter summary is noncanonical")
    }
  }
}

public extension PerformanceRunArtifact {
  func validate() throws {
    try hardware.validate(); try workload.validate(); try latency.validateSummary(); try counters.validate()
    guard formatVersion == Self.formatVersion,
      try Self(sourceRevision: sourceRevision, binarySHA256: binarySHA256,
        metallibSHA256: metallibSHA256, hardware: hardware, workload: workload,
        warmupRoots: warmupRoots, measuredRoots: measuredRoots, latency: latency,
        simulatedSecondsPerWallSecond: simulatedSecondsPerWallSecond,
        environmentStepsPerSecond: environmentStepsPerSecond,
        peakResidentBytes: peakResidentBytes, steadyResidentBytes: steadyResidentBytes,
        bytesPerEnvironment: bytesPerEnvironment, meanPowerWatts: meanPowerWatts,
        energyJoulesPerSimulatedSecond: energyJoulesPerSimulatedSecond,
        counters: counters) == self else {
      throw QualificationError.invalid("performance run artifact is noncanonical")
    }
  }
}

public extension PerformanceQualificationProtocol {
  func validate() throws {
    guard try Self(maximumP99RootLatencyMicroseconds: maximumP99RootLatencyMicroseconds,
      minimumSimulatedSecondsPerWallSecond: minimumSimulatedSecondsPerWallSecond,
      minimumEnvironmentStepsPerSecond: minimumEnvironmentStepsPerSecond,
      maximumBytesPerEnvironment: maximumBytesPerEnvironment,
      requireZeroCPUWaits: requireZeroCPUWaits,
      requireZeroQueueCreation: requireZeroQueueCreation,
      requireZeroHostPayloadReadback: requireZeroHostPayloadReadback) == self else {
      throw QualificationError.invalid("performance qualification protocol is noncanonical")
    }
  }
}

// SafetyVector, SafetyEnvelope and WatchdogHeartbeat validate in their owning
// source and their Decodable initializers; do not maintain a second definition.
public extension SafetyIncidentArtifact {
  func validate() throws {
    try vector.validate()
    guard formatVersion == Self.formatVersion, decision.reasons.count <= 64,
      decision.reasons.allSatisfy({ $0.utf8.count <= 512 }),
      try Self(sourceRevision: sourceRevision, parameterVersionFingerprint: parameterVersionFingerprint,
        publicGeneration: publicGeneration, transactionFingerprint: transactionFingerprint,
        vector: vector, decision: decision, rejectedShadowExposed: rejectedShadowExposed,
        recoveryArtifactSHA256: recoveryArtifactSHA256) == self else {
      throw QualificationError.invalid("safety incident artifact is noncanonical")
    }
  }
}

public extension NumanXReleaseManifest {
  func validate() throws {
    guard formatVersion == Self.formatVersion,
      try Self(releaseIdentifier: releaseIdentifier, sourceRevision: sourceRevision,
        binarySHA256: binarySHA256, metallibSHA256: metallibSHA256,
        modelSHA256: modelSHA256, datasetManifestSHA256: datasetManifestSHA256,
        qualificationManifestSHA256: qualificationManifestSHA256,
        previousReleaseManifestSHA256: previousReleaseManifestSHA256,
        createdUnixSeconds: createdUnixSeconds,
        deploymentGeneration: deploymentGeneration) == self else {
      throw QualificationError.invalid("release manifest is noncanonical")
    }
  }
}
