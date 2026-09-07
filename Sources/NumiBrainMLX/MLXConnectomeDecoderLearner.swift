import Foundation
import MLX
import NumiBrainCore

/// Offline behavioral cloning of accepted teacher drives. The connectome and
/// receptor projection remain immutable. No teacher input is added to runtime
/// sensing and no gradient passes through an invented physical body.
@available(macOS 26.0, *)
public enum MLXConnectomeDecoderLearner {
  public struct Settings: Codable, Equatable, Sendable {
    public let iterations: Int
    public let learningRate: Float
    public let l2: Float
    public let gradientLimit: Float
    public let parameterLimit: Float
    public init(iterations: Int = 200, learningRate: Float = 0.02, l2: Float = 0.0001,
      gradientLimit: Float = 1, parameterLimit: Float = 16) throws {
      self.iterations = iterations; self.learningRate = learningRate; self.l2 = l2
      self.gradientLimit = gradientLimit; self.parameterLimit = parameterLimit
      try validate()
    }
    public func validate() throws {
      guard (1...4096).contains(iterations), learningRate.isFinite, learningRate > 0, learningRate <= 1,
        l2.isFinite, l2 >= 0, l2 <= 1, gradientLimit.isFinite, gradientLimit > 0, gradientLimit <= 64,
        parameterLimit.isFinite, parameterLimit > 0, parameterLimit <= 64 else {
        throw ConnectomeError.invalid("invalid bounded decoder-learning settings")
      }
    }
  }
  public struct Result: Codable, Sendable {
    public let version: UInt32
    public let promotable: Bool
    public let parentDecoderFingerprint: UInt64
    public let teacherProgramFingerprint: UInt64
    public let trainingDataSHA256: String
    public let heldOutDataSHA256: String
    public let settings: Settings
    public let trainingActionMSEBefore: Float
    public let trainingActionMSEAfter: Float
    public let heldOutActionMSEBefore: Float
    public let heldOutActionMSEAfter: Float
    public let decoder: ConnectomeMotorDecoder
  }

  public static func train(program: ConnectomeProgram, split: ConnectomeTrainingSplit, settings: Settings) throws -> Result {
    try settings.validate()
    _ = try ConnectomeTrainingSplit(program: program, training: split.training, heldOut: split.heldOut)
    let parent = try program.decoder.validated()
    guard parent.weights.allSatisfy({ abs($0) <= settings.parameterLimit }),
      parent.bias.allSatisfy({ abs($0) <= settings.parameterLimit }) else {
      throw ConnectomeError.invalid("parent decoder exceeds declared learner bounds")
    }
    let c = Int(parent.channelCount), a = Int(parent.actuatorCount)
    let trainN = split.training.count, heldN = split.heldOut.count
    guard (trainN + heldN) <= 16_777_216 / max(c, a) else {
      throw ConnectomeError.invalid("decoder learning exceeds the 16M-scalar data budget")
    }
    let x = MLXArray(split.training.flatMap(\.features), [trainN, c])
    let y = MLXArray(split.training.flatMap(\.normalizedDrives), [trainN, a])
    let hx = MLXArray(split.heldOut.flatMap(\.features), [heldN, c])
    let hy = MLXArray(split.heldOut.flatMap(\.normalizedDrives), [heldN, a])
    // Fit the exact decoder's inverse activation. Epsilon only resolves the
    // infinite logits at saturated commands; it is part of the algorithm.
    let signedTarget = parent.commandKind == 1 ? y : 2*y - 1
    let bounded = clip(signedTarget, min: -0.9999, max: 0.9999)
    let logits = 0.5 * log((1 + bounded) / (1 - bounded))
    var w = MLXArray(parent.weights, [a, c]), b = MLXArray(parent.bias, [a])
    func action(_ input: MLXArray, _ weights: MLXArray, _ bias: MLXArray) -> MLXArray {
      let signed = tanh(matmul(input, weights.transposed()) + bias)
      return parent.commandKind == 1 ? maximum(signed, MLXArray(Float(0))) : (signed + 1)*0.5
    }
    func mse(_ x: MLXArray, _ y: MLXArray, _ w: MLXArray, _ b: MLXArray) -> Float {
      let error = action(x,w,b)-y
      return mean(error*error).item(Float.self)
    }
    let trainBefore = mse(x,y,w,b), heldBefore = mse(hx,hy,w,b)
    for _ in 0..<settings.iterations {
      let error = matmul(x, w.transposed()) + b - logits
      // Per-output mean logit loss; deterministic full-batch updates avoid
      // using held-out data for gradients, stopping decisions or scaling.
      let dw = (2/Float(trainN))*matmul(error.transposed(), x) + settings.l2*w
      let db = 2*mean(error, axis: 0)
      let boundedW = clip(w - settings.learningRate*clip(dw, min: -settings.gradientLimit, max: settings.gradientLimit),
        min: -settings.parameterLimit, max: settings.parameterLimit)
      // Stay inside the native per-actuator L1 bound with FP32 margin.
      let nextW = boundedW / maximum(MLXArray(Float(1)), sum(abs(boundedW), axis: 1, keepDims: true)/63)
      let nextB = clip(b - settings.learningRate*clip(db, min: -settings.gradientLimit, max: settings.gradientLimit),
        min: -settings.parameterLimit, max: settings.parameterLimit)
      eval(nextW,nextB); w = nextW; b = nextB
    }
    let decoder = try parent.replacing(weights: w.asArray(Float.self), bias: b.asArray(Float.self))
    let trainAfter = mse(x,y,w,b), heldAfter = mse(hx,hy,w,b)
    guard [trainBefore, heldBefore, trainAfter, heldAfter].allSatisfy({ $0.isFinite && $0 >= 0 }) else {
      throw ConnectomeError.invalid("nonfinite decoder-learning evaluation")
    }
    guard decoder.fingerprint != parent.fingerprint, trainAfter < trainBefore else {
      throw ConnectomeError.invalid("teacher data did not produce a resolved improvement; no candidate published")
    }
    return Result(version: 1, promotable: false, parentDecoderFingerprint: parent.fingerprint,
      teacherProgramFingerprint: program.fingerprint,
      trainingDataSHA256: BrainPolicyEvidenceArtifact.sha256(try BrainPolicyEvidenceArtifact.encodeCanonical(split.training)),
      heldOutDataSHA256: BrainPolicyEvidenceArtifact.sha256(try BrainPolicyEvidenceArtifact.encodeCanonical(split.heldOut)),
      settings: settings, trainingActionMSEBefore: trainBefore, trainingActionMSEAfter: trainAfter,
      heldOutActionMSEBefore: heldBefore, heldOutActionMSEAfter: heldAfter, decoder: decoder)
  }
}
