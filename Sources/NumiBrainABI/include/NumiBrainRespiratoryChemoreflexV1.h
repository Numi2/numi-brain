#ifndef NUMI_BRAIN_RESPIRATORY_CHEMOREFLEX_V1_H
#define NUMI_BRAIN_RESPIRATORY_CHEMOREFLEX_V1_H

#if !defined(__METAL_VERSION__)
#include <stdint.h>
#endif

#if defined(__cplusplus)
extern "C" {
#endif

enum {
  NB_NUMI_RESPIRATORY_CHEMOREFLEX_ABI_VERSION = 1,
  NB_NUMI_RESPIRATORY_VALID_PA_O2 = 1u << 0,
  NB_NUMI_RESPIRATORY_VALID_PA_CO2 = 1u << 1,
  NB_NUMI_RESPIRATORY_INPUT_ACCEPTED = 1u << 0,
  NB_NUMI_RESPIRATORY_RECORD_VALID = 1u << 0,
  NB_NUMI_RESPIRATORY_INPUT_BYTE_COUNT = 48,
  NB_NUMI_RESPIRATORY_STATE_BYTE_COUNT = 32,
  NB_NUMI_RESPIRATORY_OUTPUT_BYTE_COUNT = 48,
  NB_NUMI_RESPIRATORY_PARAMETERS_BYTE_COUNT = 64,
};

/* One sample from the source-accepted Human physiology root. Gas pressures
 * are arterial mmHg; timestamps are physical microseconds. The candidate
 * transaction fingerprint is preserved through accepted/rejected publication.
 */
typedef struct NBNumiRespiratoryChemoreflexInputV1 {
  uint64_t sourceTimestampMicroseconds;
  uint64_t sourceAcceptedRootFingerprint;
  uint64_t targetTimestampMicroseconds;
  uint64_t targetTransactionFingerprint;
  float paO2MillimetersMercury;
  float paCO2MillimetersMercury;
  uint32_t validityMask;
  uint32_t flags;
} NBNumiRespiratoryChemoreflexInputV1;

/* Accepted-only controller history. The caller stages this beside the body
 * candidate and publishes it only when Matter accepts that same transaction.
 */
typedef struct NBNumiRespiratoryChemoreflexStateV1 {
  uint64_t timestampMicroseconds;
  uint64_t acceptedRootFingerprint;
  float centralCO2DriveLitresPerMinute;
  float peripheralDriveLitresPerMinute;
  float respiratoryPhaseCycles;
  uint32_t flags;
} NBNumiRespiratoryChemoreflexStateV1;

/* `targetTidalVolumeLitres` is a neural/mechanical setpoint. It is never
 * written to lung volume; the body owner obtains volume from muscle and lung
 * mechanics. Excitations are the diaphragm and intercostal MyoSim commands.
 */
typedef struct NBNumiRespiratoryChemoreflexOutputV1 {
  uint64_t targetTimestampMicroseconds;
  uint64_t sourceAcceptedRootFingerprint;
  uint64_t targetTransactionFingerprint;
  float targetMinuteVentilationLitresPerMinute;
  float targetFrequencyBreathsPerMinute;
  float targetTidalVolumeLitres;
  float diaphragmExcitation;
  float intercostalExcitation;
  uint32_t flags;
} NBNumiRespiratoryChemoreflexOutputV1;

/* Reference parameters are explicit configuration, shared by the NumiBrain
 * and Numi Human Metal paths. Units appear in each field name. */
typedef struct NBNumiRespiratoryChemoreflexParametersV1 {
  float restingMinuteVentilationLitresPerMinute;
  float CO2ResponseSlopeLitresPerMinutePerMmHg;
  float centralCO2Fraction;
  float centralTimeConstantSeconds;
  float peripheralTimeConstantSeconds;
  float hypoxicReferencePaO2MillimetersMercury;
  float hypoxicScalePaO2MillimetersMercury;
  float hypoxicIncrementAtPaO2FortyLitresPerMinute;
  float restingFrequencyBreathsPerMinute;
  float restingTidalVolumeLitres;
  float diaphragmExcitationGain;
  float intercostalExcitationGain;
  float inspirationFractionOfCycle;
  float minimumMinuteVentilationLitresPerMinute;
  float maximumMinuteVentilationLitresPerMinute;
  float reserved;
} NBNumiRespiratoryChemoreflexParametersV1;

/* Reference adult at rest. CO2 gain is the 2.60 L/min/mmHg mean reported in
 * 126 normal young adults (Irsigler, Am Rev Respir Dis 1976, PMID 970734,
 * DOI 10.1164/arrd.1976.114.3.529); vary it over 1.5-5.0 for sensitivity.
 * Central fraction 0.67 is an inferred representative of human estimates
 * around 60-80% (J Appl Physiol 2010, DOI 10.1152/japplphysiol.01059.2009).
 * The 120 s central and 5 s peripheral filters are reduced-order time scales;
 * they use representative values from the reported about-2-min central and
 * 3-10 s peripheral response ranges (Dahan et al., PLoS Med 2007,
 * DOI 10.1371/journal.pmed.0040239). The hypoxic curve
 * uses k=24.5 mmHg and an increment of 40 L/min at alveolar PO2=40 from young
 * normal adult data (JCI 1977, PMID 908760, DOI 10.1172/JCI108874); anchoring
 * its normoxic reference to arterial PaO2=95 mmHg is an explicit model choice,
 * not a conversion measured by that study. */
static inline NBNumiRespiratoryChemoreflexParametersV1
NBNumiRespiratoryChemoreflexReferenceParametersV1(void) {
  NBNumiRespiratoryChemoreflexParametersV1 value = {
    6.0f, 2.60f, 0.67f, 120.0f,
    5.0f, 95.0f, 24.5f, 40.0f,
    12.0f, 0.50f, 0.16f, 0.10f,
    0.40f, 2.0f, 40.0f, 0.0f
  };
  return value;
}

static inline NBNumiRespiratoryChemoreflexStateV1
NBNumiRespiratoryChemoreflexInitialStateV1(
  uint64_t timestampMicroseconds, uint64_t acceptedRootFingerprint) {
  NBNumiRespiratoryChemoreflexStateV1 value = {
    timestampMicroseconds, acceptedRootFingerprint,
    0.0f, 0.0f, 0.0f, NB_NUMI_RESPIRATORY_RECORD_VALID
  };
  return value;
}

#if defined(__cplusplus)
}
static_assert(sizeof(NBNumiRespiratoryChemoreflexInputV1) == 48,
  "respiratory input ABI");
static_assert(sizeof(NBNumiRespiratoryChemoreflexStateV1) == 32,
  "respiratory state ABI");
static_assert(sizeof(NBNumiRespiratoryChemoreflexOutputV1) == 48,
  "respiratory output ABI");
static_assert(sizeof(NBNumiRespiratoryChemoreflexParametersV1) == 64,
  "respiratory parameter ABI");
#else
_Static_assert(sizeof(NBNumiRespiratoryChemoreflexInputV1) == 48,
  "respiratory input ABI");
_Static_assert(sizeof(NBNumiRespiratoryChemoreflexStateV1) == 32,
  "respiratory state ABI");
_Static_assert(sizeof(NBNumiRespiratoryChemoreflexOutputV1) == 48,
  "respiratory output ABI");
_Static_assert(sizeof(NBNumiRespiratoryChemoreflexParametersV1) == 64,
  "respiratory parameter ABI");
#endif

#endif /* NUMI_BRAIN_RESPIRATORY_CHEMOREFLEX_V1_H */
