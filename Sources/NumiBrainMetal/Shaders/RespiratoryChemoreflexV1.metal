#include <metal_stdlib>
#include <NumiBrainRespiratoryChemoreflexV1.h>

using namespace metal;

static_assert(sizeof(NBNumiRespiratoryChemoreflexInputV1)
    == NB_NUMI_RESPIRATORY_INPUT_BYTE_COUNT,
    "respiratory input ABI drift");
static_assert(sizeof(NBNumiRespiratoryChemoreflexStateV1)
    == NB_NUMI_RESPIRATORY_STATE_BYTE_COUNT,
    "respiratory state ABI drift");
static_assert(sizeof(NBNumiRespiratoryChemoreflexOutputV1)
    == NB_NUMI_RESPIRATORY_OUTPUT_BYTE_COUNT,
    "respiratory output ABI drift");
static_assert(sizeof(NBNumiRespiratoryChemoreflexParametersV1)
    == NB_NUMI_RESPIRATORY_PARAMETERS_BYTE_COUNT,
    "respiratory parameter ABI drift");

inline bool nb_respiratory_parameters_valid(
    constant NBNumiRespiratoryChemoreflexParametersV1 &p) {
  return isfinite(p.restingMinuteVentilationLitresPerMinute)
      && p.restingMinuteVentilationLitresPerMinute > 0.0f
      && isfinite(p.CO2ResponseSlopeLitresPerMinutePerMmHg)
      && p.CO2ResponseSlopeLitresPerMinutePerMmHg > 0.0f
      && isfinite(p.centralCO2Fraction)
      && p.centralCO2Fraction >= 0.0f && p.centralCO2Fraction <= 1.0f
      && isfinite(p.centralTimeConstantSeconds)
      && p.centralTimeConstantSeconds > 0.0f
      && isfinite(p.peripheralTimeConstantSeconds)
      && p.peripheralTimeConstantSeconds > 0.0f
      && isfinite(p.hypoxicReferencePaO2MillimetersMercury)
      && p.hypoxicReferencePaO2MillimetersMercury > 40.0f
      && isfinite(p.hypoxicScalePaO2MillimetersMercury)
      && p.hypoxicScalePaO2MillimetersMercury > 0.0f
      && isfinite(p.hypoxicIncrementAtPaO2FortyLitresPerMinute)
      && p.hypoxicIncrementAtPaO2FortyLitresPerMinute >= 0.0f
      && isfinite(p.restingFrequencyBreathsPerMinute)
      && p.restingFrequencyBreathsPerMinute > 0.0f
      && isfinite(p.restingTidalVolumeLitres)
      && p.restingTidalVolumeLitres > 0.0f
      && isfinite(p.diaphragmExcitationGain)
      && p.diaphragmExcitationGain >= 0.0f
      && p.diaphragmExcitationGain <= 1.0f
      && isfinite(p.intercostalExcitationGain)
      && p.intercostalExcitationGain >= 0.0f
      && p.intercostalExcitationGain <= 1.0f
      && isfinite(p.inspirationFractionOfCycle)
      && p.inspirationFractionOfCycle > 0.0f
      && p.inspirationFractionOfCycle < 1.0f
      && isfinite(p.minimumMinuteVentilationLitresPerMinute)
      && p.minimumMinuteVentilationLitresPerMinute > 0.0f
      && isfinite(p.maximumMinuteVentilationLitresPerMinute)
      && p.maximumMinuteVentilationLitresPerMinute
          >= p.restingMinuteVentilationLitresPerMinute
      && p.minimumMinuteVentilationLitresPerMinute
          <= p.restingMinuteVentilationLitresPerMinute;
}

inline void nb_respiratory_reject(
    device NBNumiRespiratoryChemoreflexStateV1 &candidateState,
    device NBNumiRespiratoryChemoreflexOutputV1 &output) {
  candidateState.timestampMicroseconds = 0ul;
  candidateState.acceptedRootFingerprint = 0ul;
  candidateState.centralCO2DriveLitresPerMinute = 0.0f;
  candidateState.peripheralDriveLitresPerMinute = 0.0f;
  candidateState.respiratoryPhaseCycles = 0.0f;
  candidateState.flags = 0u;
  output.targetTimestampMicroseconds = 0ul;
  output.sourceAcceptedRootFingerprint = 0ul;
  output.targetTransactionFingerprint = 0ul;
  output.targetMinuteVentilationLitresPerMinute = NAN;
  output.targetFrequencyBreathsPerMinute = NAN;
  output.targetTidalVolumeLitres = NAN;
  output.diaphragmExcitation = NAN;
  output.intercostalExcitation = NAN;
  output.flags = 0u;
}

/* One thread handles one embodied human. It reads only a frame-begin gas
 * sample and accepted controller state, then writes a shadow state/output.
 * The caller publishes that shadow only with the matching accepted Matter
 * transaction; this kernel has no commit or readback path.
 */
kernel void advance_numi_respiratory_chemoreflex_v1(
    constant NBNumiRespiratoryChemoreflexParametersV1 *parameters
        [[buffer(0)]],
    device const NBNumiRespiratoryChemoreflexInputV1 *input [[buffer(1)]],
    device const NBNumiRespiratoryChemoreflexStateV1 *committedStates
        [[buffer(2)]],
    device NBNumiRespiratoryChemoreflexStateV1 *candidateStates
        [[buffer(3)]],
    device NBNumiRespiratoryChemoreflexOutputV1 *outputs [[buffer(4)]],
    uint environment [[thread_position_in_grid]]) {
  const NBNumiRespiratoryChemoreflexInputV1 sample = input[environment];
  const NBNumiRespiratoryChemoreflexStateV1 baseline =
      committedStates[environment];
  device NBNumiRespiratoryChemoreflexStateV1 &nextState =
      candidateStates[environment];
  device NBNumiRespiratoryChemoreflexOutputV1 &output = outputs[environment];
  constant NBNumiRespiratoryChemoreflexParametersV1 &p = parameters[0];

  const uint32_t required =
      NB_NUMI_RESPIRATORY_VALID_PA_O2 | NB_NUMI_RESPIRATORY_VALID_PA_CO2;
  const ulong elapsedMicroseconds = sample.targetTimestampMicroseconds
      >= sample.sourceTimestampMicroseconds
      ? sample.targetTimestampMicroseconds - sample.sourceTimestampMicroseconds
      : 0ul;
  const bool inputValid = sample.flags & NB_NUMI_RESPIRATORY_INPUT_ACCEPTED;
  const bool pressuresValid = (sample.validityMask & required) == required
      && isfinite(sample.paO2MillimetersMercury)
      && isfinite(sample.paCO2MillimetersMercury)
      && sample.paO2MillimetersMercury > 0.0f
      && sample.paO2MillimetersMercury <= 300.0f
      && sample.paCO2MillimetersMercury > 0.0f
      && sample.paCO2MillimetersMercury <= 200.0f;
  const bool chronologyValid = sample.sourceTimestampMicroseconds
          == baseline.timestampMicroseconds
      && sample.sourceAcceptedRootFingerprint
          == baseline.acceptedRootFingerprint
      && sample.sourceAcceptedRootFingerprint != 0ul
      && sample.targetTimestampMicroseconds
          > sample.sourceTimestampMicroseconds
      && sample.targetTransactionFingerprint != 0ul
      && elapsedMicroseconds <= 250000ul;
  const bool baselineValid =
      (baseline.flags & NB_NUMI_RESPIRATORY_RECORD_VALID) != 0u
      && isfinite(baseline.centralCO2DriveLitresPerMinute)
      && isfinite(baseline.peripheralDriveLitresPerMinute)
      && isfinite(baseline.respiratoryPhaseCycles)
      && baseline.respiratoryPhaseCycles >= 0.0f
      && baseline.respiratoryPhaseCycles < 1.0f;
  if (!inputValid || !pressuresValid || !chronologyValid || !baselineValid
      || !nb_respiratory_parameters_valid(p)) {
    nb_respiratory_reject(nextState, output);
    return;
  }

  const float elapsedSeconds = float(elapsedMicroseconds) * 1.0e-6f;
  const float co2Error = sample.paCO2MillimetersMercury - 40.0f;
  const float centralTarget = clamp(
      p.CO2ResponseSlopeLitresPerMinutePerMmHg
          * p.centralCO2Fraction * co2Error,
      p.minimumMinuteVentilationLitresPerMinute
          - p.restingMinuteVentilationLitresPerMinute,
      p.maximumMinuteVentilationLitresPerMinute
          - p.restingMinuteVentilationLitresPerMinute);
  const float peripheralCo2Target =
      p.CO2ResponseSlopeLitresPerMinutePerMmHg
          * (1.0f - p.centralCO2Fraction) * co2Error;
  float hypoxicTarget = 0.0f;
  if (sample.paO2MillimetersMercury
      < p.hypoxicReferencePaO2MillimetersMercury) {
    const float hypoxiaRise = exp(
        (p.hypoxicReferencePaO2MillimetersMercury
            - sample.paO2MillimetersMercury)
            / p.hypoxicScalePaO2MillimetersMercury) - 1.0f;
    const float riseAtForty = exp(
        (p.hypoxicReferencePaO2MillimetersMercury - 40.0f)
            / p.hypoxicScalePaO2MillimetersMercury) - 1.0f;
    hypoxicTarget = p.hypoxicIncrementAtPaO2FortyLitresPerMinute
        * max(hypoxiaRise, 0.0f) / max(riseAtForty, 1.0e-6f);
  }
  const float peripheralTarget = peripheralCo2Target + hypoxicTarget;
  const float centralAlpha = 1.0f - exp(
      -elapsedSeconds / p.centralTimeConstantSeconds);
  const float peripheralAlpha = 1.0f - exp(
      -elapsedSeconds / p.peripheralTimeConstantSeconds);
  const float centralDrive = baseline.centralCO2DriveLitresPerMinute
      + centralAlpha * (centralTarget
          - baseline.centralCO2DriveLitresPerMinute);
  const float peripheralDrive = baseline.peripheralDriveLitresPerMinute
      + peripheralAlpha * (peripheralTarget
          - baseline.peripheralDriveLitresPerMinute);
  const float ventilation = clamp(
      p.restingMinuteVentilationLitresPerMinute
          + centralDrive + peripheralDrive,
      p.minimumMinuteVentilationLitresPerMinute,
      p.maximumMinuteVentilationLitresPerMinute);
  const float frequency = clamp(
      p.restingFrequencyBreathsPerMinute
          * sqrt(ventilation / p.restingMinuteVentilationLitresPerMinute),
      4.0f, 40.0f);
  const float tidalVolume = clamp(
      ventilation / frequency,
      0.15f, p.maximumMinuteVentilationLitresPerMinute / frequency);
  const float phase = fract(
      baseline.respiratoryPhaseCycles
          + elapsedSeconds * frequency / 60.0f);
  const float inspirationPhase = phase / p.inspirationFractionOfCycle;
  const float inspiratoryEnvelope = phase < p.inspirationFractionOfCycle
      ? sin(M_PI_F * clamp(inspirationPhase, 0.0f, 1.0f))
      : 0.0f;
  const float amplitudeScale = sqrt(
      tidalVolume / p.restingTidalVolumeLitres);

  nextState.timestampMicroseconds = sample.targetTimestampMicroseconds;
  nextState.acceptedRootFingerprint = sample.targetTransactionFingerprint;
  nextState.centralCO2DriveLitresPerMinute = centralDrive;
  nextState.peripheralDriveLitresPerMinute = peripheralDrive;
  nextState.respiratoryPhaseCycles = phase;
  nextState.flags = NB_NUMI_RESPIRATORY_RECORD_VALID;
  output.targetTimestampMicroseconds = sample.targetTimestampMicroseconds;
  output.sourceAcceptedRootFingerprint = sample.sourceAcceptedRootFingerprint;
  output.targetTransactionFingerprint = sample.targetTransactionFingerprint;
  output.targetMinuteVentilationLitresPerMinute = ventilation;
  output.targetFrequencyBreathsPerMinute = frequency;
  output.targetTidalVolumeLitres = tidalVolume;
  output.diaphragmExcitation = clamp(
      p.diaphragmExcitationGain * amplitudeScale * inspiratoryEnvelope,
      0.0f, 1.0f);
  output.intercostalExcitation = clamp(
      p.intercostalExcitationGain * amplitudeScale * inspiratoryEnvelope,
      0.0f, 1.0f);
  output.flags = NB_NUMI_RESPIRATORY_RECORD_VALID;
}
