/// Exact, immutable physical anatomy copied from one validated native NumanX
/// runtime before the Brain runtime is constructed.
@frozen
public struct NumanXFullBodyAnatomy: Sendable {
  public let jointTopologyCatalog: NumanXJointTopologyCatalog
  public let muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog
  public let headBodyIdentifier: UInt32

  public init(
    jointTopologyCatalog: NumanXJointTopologyCatalog,
    muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog,
    headBodyIdentifier: UInt32
  ) throws {
    guard jointTopologyCatalog.bodyCount == muscleAttachmentCatalog.bodyCount,
      headBodyIdentifier < jointTopologyCatalog.bodyCount,
      muscleAttachmentCatalog.attachments.count
        == Int(NumanXFullBodyTransportTemplate.actuatorCount)
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX full-body native anatomy is inconsistent"
      )
    }
    self.jointTopologyCatalog = jointTopologyCatalog
    self.muscleAttachmentCatalog = muscleAttachmentCatalog
    self.headBodyIdentifier = headBodyIdentifier
  }
}

/// Production-owned nervous-system transport shape for the native NumanX
/// full-body bridge. This template describes sensor and motor transport only;
/// the native bridge separately loads and proves the 157-body, 129-q/
/// 128-DoF physical asset.
public enum NumanXFullBodyTransportTemplate {
  public static let actuatorCount: UInt32 = 416
  public static let somaticSynergyCount: UInt16 = 16
  public static let planningHorizonSteps: UInt16 = 4
  public static let workspaceCapacity: UInt16 = 16

  public static func compile(
    latencyMicroseconds: UInt32 = 1_000,
    anatomy: NumanXFullBodyAnatomy? = nil
  ) throws -> CompiledSpeciesTemplate {
    guard latencyMicroseconds > 0 else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX full-body transport latency must be positive"
      )
    }
    let capacities = try BrainCapacityProfile.fullCognitiveV1
    let referenceGraph = try ReferenceBrainGraph.mammalianV1()
    let jointTopology = if let anatomy {
      anatomy.jointTopologyCatalog
    } else {
      try NumanXJointTopologyCatalog(
      numanXModelFingerprint: 0x4e55_4d41_4e58,
      bodyCount: 2,
      joints: [
        try NumanXJointTopology(
          jointIdentifier: 1,
          parentBodyIdentifier: 0,
          childBodyIdentifier: 1,
          parentLocalAnchor: try NumanXBodyLocalPoint(x: 0, y: 0, z: 0),
          childLocalAnchor: try NumanXBodyLocalPoint(x: 0, y: 0, z: 0),
          restRelativeOrientation: try BrainQuaternion.identity,
          coordinates: [
            try NumanXJointCoordinateTopology(
              identifier: 0,
              kind: .angular,
              parentLocalAxis: try NumanXBodyLocalPoint(x: 1, y: 0, z: 0),
              minimumPosition: -1,
              maximumPosition: 1,
              restPosition: 0
            )
          ]
        )
      ]
      )
    }
    let senses = try SensoryModality.allCases.map { modality in
      switch modality {
      case .proprioception:
        return try sensoryTopology(
          modality: modality,
          receptorCount: 416,
          observationDimension: 10,
          latencyMicroseconds: latencyMicroseconds
        )
      case .interoception:
        return try sensoryTopology(
          modality: modality,
          receptorCount: 416,
          observationDimension: 6,
          latencyMicroseconds: latencyMicroseconds
        )
      case .kinesthesia:
        return try sensoryTopology(
          modality: modality,
          receptorCount: 128,
          observationDimension: 7,
          latencyMicroseconds: latencyMicroseconds
        )
      case .vestibular:
        return try sensoryTopology(
          modality: modality,
          receptorCount: 1,
          observationDimension: 22,
          latencyMicroseconds: latencyMicroseconds
        )
      case .audition:
        return try sensoryTopology(
          modality: modality,
          receptorCount: 24,
          observationDimension: 8,
          latencyMicroseconds: latencyMicroseconds,
          adaptationTimeConstantMicroseconds: 20_000
        )
      case .vision:
        return try sensoryTopology(
          modality: modality,
          receptorCount: 64 * 48,
          observationDimension: 8,
          latencyMicroseconds: latencyMicroseconds,
          activeSensingActionDimension: 1
        )
      case .touch:
        return try sensoryTopology(
          modality: modality,
          receptorCount: 10,
          observationDimension: 7,
          latencyMicroseconds: latencyMicroseconds
        )
      default:
        return try SensoryTopology(
          modality: modality,
          receptorCount: 0,
          observationDimension: 0,
          latencyMicroseconds: 0,
          adaptationTimeConstantMicroseconds: 10_000,
          noiseStandardDeviation: 0,
          activeSensingActionDimension: 0,
          enabled: false
        )
      }
    }
    let motor = try MotorTopology(
      actuatorCommandKind: .muscleExcitation,
      actuatorCount: actuatorCount,
      synergyCount: somaticSynergyCount,
      motorNucleusCount: 1,
      autonomicActionDimension: 1,
      activeSensingActionDimension: 1,
      outputMinimum: 0,
      outputMaximum: 1
    )
    let physiology = try PhysiologyTemplate(
      modelClass: .artificialEnergyThermal,
      stateDimension: 1,
      autonomicActionDimension: 1,
      viableMinimums: [0.2],
      viableMaximums: [0.8],
      criticalMinimums: [0],
      criticalMaximums: [1],
      receptorMappings: [
        try PhysiologicalReceptorTemplate(
          stateIdentifier: 0,
          receptorIdentifier: 900,
          interoceptiveReceptorIndex: 0,
          featureIndex: 0,
          magnitudeScale: 1
        )
      ],
      autonomicChannels: [
        try AutonomicChannelTemplate(
          identifier: 0,
          kind: .generic,
          criticalReceptorIdentifiers: [900],
          respondsToAnyPhysiologicalCritical: false,
          emergencyTarget: 1,
          emergencyGain: 1,
          cpgGain: 0
        )
      ]
    )
    let enabledModules = referenceGraph.modules.map(\.identifier)
    let development = try DevelopmentalStage.allCases.map { stage in
      try DevelopmentalStageTemplate(
        stage: stage,
        unlockedModuleIdentifiers: enabledModules,
        learningRateMultiplier: 1,
        sensorPrecisionMultiplier: 1,
        muscleStrengthMultiplier: 1,
        planningHorizonSteps: planningHorizonSteps,
        workspaceCapacity: workspaceCapacity,
        capabilityGateCodes: stage == .innateScaffold
          ? [] : [UInt64(stage.rawValue)]
      )
    }
    let bodyCount = anatomy?.jointTopologyCatalog.bodyCount ?? 2
    let muscleAttachmentCatalog = anatomy?.muscleAttachmentCatalog
    let species = try SpeciesTemplate(
      family: .genericRobot,
      name: "NumanX 416-muscle full-body transport",
      referenceGraph: referenceGraph,
      enabledModuleIdentifiers: enabledModules,
      body: try SpeciesBodyTopology(
        bodyCount: bodyCount,
        jointCount: UInt32(jointTopology.joints.count),
        jointTopologyFingerprint: jointTopology.fingerprint,
        muscleCount: UInt32(muscleAttachmentCatalog?.attachments.count ?? 0),
        muscleAttachmentFingerprint: muscleAttachmentCatalog?.fingerprint ?? 0,
        skinSurfaceCount: 1,
        actuatorCount: actuatorCount,
        morphologyCode: 0x4e55_4d41_4e58
      ),
      senses: senses,
      motor: motor,
      reflexes: [],
      cpg: try CPGTopology(oscillators: [], couplings: []),
      physiology: physiology,
      innateBehaviors: [],
      development: development,
      capacities: capacities
    )
    let bodyEndpoints: [NumanXReceptorEndpoint]
    let jointEndpoints: [NumanXJointReceptorEndpoint]
    let muscleEndpoints: [NumanXMuscleReceptorEndpoint]
    if let anatomy {
      bodyEndpoints = try fullBodyEndpoints(
        headBodyIdentifier: anatomy.headBodyIdentifier
      )
      // HumanIO's native 128-by-7 packet provides exact generalized position
      // and velocity rows. Publish only those two causal signals; force,
      // reaction, and limit semantics remain absent rather than inferred.
      jointEndpoints = try fullBodyJointEndpoints(
        topology: anatomy.jointTopologyCatalog
      )
      muscleEndpoints = try fullBodyMuscleEndpoints(
        attachments: anatomy.muscleAttachmentCatalog.attachments
      )
    } else {
      bodyEndpoints = [
        try NumanXReceptorEndpoint(
          identifier: 1,
          sourceEndpointIdentifier: 101,
          bodyIdentifier: 0,
          modality: .proprioception,
          receptorIndex: 0,
          featureIndex: 0,
          signal: .position,
          component: 0
        )
      ]
      jointEndpoints = try JointReceptorSignal.allCases.enumerated().map {
        index, signal in
        try NumanXJointReceptorEndpoint(
          identifier: UInt32(10 + index),
          sourceEndpointIdentifier: UInt64(110 + index),
          jointIdentifier: 1,
          coordinateIdentifier: 0,
          receptorIndex: 0,
          featureIndex: UInt32(index),
          signal: signal
        )
      }
      muscleEndpoints = []
    }
    let receptorAnatomy = try NumanXReceptorAnatomyCatalog(
      species: species,
      jointTopologyCatalog: jointTopology,
      muscleAttachmentCatalog: muscleAttachmentCatalog,
      numanXModelFingerprint: jointTopology.numanXModelFingerprint,
      endpoints: bodyEndpoints,
      jointEndpoints: jointEndpoints,
      muscleEndpoints: muscleEndpoints
    )
    let sensoryProfile = try SensoryTransductionProfile(
      species: species,
      eventRules: [],
      numanXReceptorAnatomy: receptorAnatomy,
      jointTopologyCatalog: jointTopology,
      muscleAttachmentCatalog: muscleAttachmentCatalog
    )
    let protectiveMotorProfile = try ProtectiveMotorProfile
      .runtimeFoundationFixture(
        muscleIdentifiers: Array(0..<actuatorCount)
      )
    let somaticSynergyCatalog = try muscleAttachmentCatalog.map {
      try anatomicalSynergyCatalog(attachments: $0)
    } ?? SomaticSynergyCatalog.runtimeFoundationFixture(
      actuatorCount: actuatorCount,
      synergyCount: somaticSynergyCount
    )
    return try SpeciesTemplateCompiler.compileRuntimeTemplate(
      referenceBrainGraph: referenceGraph,
      species: species,
      sensoryProfile: sensoryProfile,
      numanXReceptorAnatomyCatalog: receptorAnatomy,
      jointTopologyCatalog: jointTopology,
      muscleAttachmentCatalog: muscleAttachmentCatalog,
      somaticSynergyCatalog: somaticSynergyCatalog,
      protectiveMotorProfile: protectiveMotorProfile
    )
  }

  private static func fullBodyEndpoints(
    headBodyIdentifier: UInt32
  ) throws -> [NumanXReceptorEndpoint] {
    var result: [NumanXReceptorEndpoint] = []
    func append(
      body: UInt32,
      feature: UInt32,
      signal: BodyReceptorSignal,
      component: UInt16
    ) throws {
      let identifier = UInt32(result.count + 1)
      result.append(try NumanXReceptorEndpoint(
        identifier: identifier,
        sourceEndpointIdentifier: 0x4e58_0000 + UInt64(identifier),
        bodyIdentifier: body,
        modality: .vestibular,
        receptorIndex: 0,
        featureIndex: feature,
        signal: signal,
        component: component
      ))
    }
    for component in 0..<3 {
      try append(body: 0, feature: UInt32(component), signal: .position,
        component: UInt16(component))
      try append(body: 0, feature: UInt32(7 + component), signal: .velocity,
        component: UInt16(component))
      try append(body: 0, feature: UInt32(10 + component),
        signal: .angularVelocity, component: UInt16(component))
      try append(body: headBodyIdentifier, feature: UInt32(13 + component),
        signal: .position, component: UInt16(component))
    }
    for component in 0..<4 {
      try append(body: 0, feature: UInt32(3 + component), signal: .orientation,
        component: UInt16(component))
      try append(body: headBodyIdentifier, feature: UInt32(16 + component),
        signal: .orientation, component: UInt16(component))
    }
    try append(body: headBodyIdentifier, feature: 20,
      signal: .vestibularStability, component: 0)
    return result
  }

  private static func fullBodyMuscleEndpoints(
    attachments: [NumanXMuscleAttachment]
  ) throws -> [NumanXMuscleReceptorEndpoint] {
    var result: [NumanXMuscleReceptorEndpoint] = []
    result.reserveCapacity(attachments.count * 4)
    for attachment in attachments {
      let bindings: [(SensoryModality, UInt32, MuscleReceptorSignal)] = [
        (.proprioception, 4, .length),
        (.proprioception, 5, .lengthVelocity),
        (.proprioception, 7, .tendonForce),
        (.interoception, 4, .fatigue),
      ]
      for (modality, feature, signal) in bindings {
        let identifier = UInt32(result.count + 10_000)
        result.append(try NumanXMuscleReceptorEndpoint(
          identifier: identifier,
          sourceEndpointIdentifier: 0x4d59_0000 + UInt64(identifier),
          muscleIdentifier: attachment.muscleIdentifier,
          modality: modality,
          receptorIndex: attachment.muscleIdentifier,
          featureIndex: feature,
          signal: signal
        ))
      }
    }
    return result
  }

  private static func fullBodyJointEndpoints(
    topology: NumanXJointTopologyCatalog
  ) throws -> [NumanXJointReceptorEndpoint] {
    var result: [NumanXJointReceptorEndpoint] = []
    result.reserveCapacity(Int(actuatorCount))
    var receptorIndices = Set<UInt32>()
    for joint in topology.joints {
      for coordinate in joint.coordinates {
        guard let receptor = coordinate.kinesthesiaReceptorIndex,
          receptor < 128,
          receptorIndices.insert(receptor).inserted
        else {
          throw BrainRuntimeError.invalidDescriptor(
            "NumanX full-body joint coordinate lacks exact kinesthesia provenance"
          )
        }
        for (feature, signal) in [
          (UInt32(0), JointReceptorSignal.position),
          (UInt32(1), JointReceptorSignal.velocity),
        ] {
          let identifier = UInt32(1_000 + result.count)
          result.append(try NumanXJointReceptorEndpoint(
            identifier: identifier,
            sourceEndpointIdentifier: 0x4a59_0000 + UInt64(identifier),
            jointIdentifier: joint.jointIdentifier,
            coordinateIdentifier: coordinate.identifier,
            receptorIndex: receptor,
            featureIndex: feature,
            signal: signal
          ))
        }
      }
    }
    // Rows 0...5 are the floating-root generalized velocity. Root pose and
    // velocity already arrive through the authoritative vestibular body
    // channel; articulated joint coordinates own rows 6...127 exactly.
    guard receptorIndices == Set(UInt32(6)..<UInt32(128)) else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX full-body joint kinesthesia must cover native rows 6 through 127"
      )
    }
    return result
  }

  /// Sixteen contiguous body-region bases derived from endpoint anatomy.
  /// Every muscle projects to the region of each source endpoint, so the
  /// decoder represents body-local recruitment rather than actuator index.
  private static func anatomicalSynergyCatalog(
    attachments: NumanXMuscleAttachmentCatalog
  ) throws -> SomaticSynergyCatalog {
    let synergyCount = UInt32(somaticSynergyCount)
    func region(_ body: UInt32) -> UInt16 {
      UInt16(min(
        synergyCount - 1,
        UInt32((UInt64(body) * UInt64(synergyCount))
          / UInt64(attachments.bodyCount))
      ))
    }
    var routes: [SomaticSynergyRoute] = []
    var pairs = Set<UInt64>()
    for attachment in attachments.attachments {
      let first = region(attachment.firstBodyIdentifier)
      let terminal = region(attachment.terminalBodyIdentifier)
      let endpointRegions = first == terminal ? [first] : [first, terminal]
      for synergy in endpointRegions {
        routes.append(try SomaticSynergyRoute(
          synergyIdentifier: synergy,
          actuatorIdentifier: attachment.muscleIdentifier,
          gain: first == terminal ? 1 : 0.5
        ))
        pairs.insert(UInt64(attachment.muscleIdentifier) << 16 | UInt64(synergy))
      }
    }
    for synergy in UInt16(0)..<somaticSynergyCount {
      if routes.contains(where: { $0.synergyIdentifier == synergy }) { continue }
      let center = (UInt64(synergy) * UInt64(attachments.bodyCount)
        + UInt64(attachments.bodyCount / 2)) / UInt64(synergyCount)
      guard let nearest = attachments.attachments.min(by: {
        let lhs = min(
          abs(Int64($0.firstBodyIdentifier) - Int64(center)),
          abs(Int64($0.terminalBodyIdentifier) - Int64(center))
        )
        let rhs = min(
          abs(Int64($1.firstBodyIdentifier) - Int64(center)),
          abs(Int64($1.terminalBodyIdentifier) - Int64(center))
        )
        return lhs == rhs ? $0.muscleIdentifier < $1.muscleIdentifier : lhs < rhs
      }) else { continue }
      let pair = UInt64(nearest.muscleIdentifier) << 16 | UInt64(synergy)
      if pairs.insert(pair).inserted {
        routes.append(try SomaticSynergyRoute(
          synergyIdentifier: synergy,
          actuatorIdentifier: nearest.muscleIdentifier,
          gain: 0.25
        ))
      }
    }
    return try SomaticSynergyCatalog(
      actuatorCount: actuatorCount,
      synergyCount: somaticSynergyCount,
      routes: routes
    )
  }

  private static func sensoryTopology(
    modality: SensoryModality,
    receptorCount: UInt32,
    observationDimension: UInt32,
    latencyMicroseconds: UInt32,
    adaptationTimeConstantMicroseconds: UInt32 = 10_000,
    activeSensingActionDimension: UInt16 = 0
  ) throws -> SensoryTopology {
    try SensoryTopology(
      modality: modality,
      receptorCount: receptorCount,
      observationDimension: observationDimension,
      latencyMicroseconds: latencyMicroseconds,
      adaptationTimeConstantMicroseconds: adaptationTimeConstantMicroseconds,
      noiseStandardDeviation: 0,
      activeSensingActionDimension: activeSensingActionDimension,
      enabled: true
    )
  }
}
