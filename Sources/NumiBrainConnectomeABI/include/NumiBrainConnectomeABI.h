#ifndef NUMIBRAIN_CONNECTOME_ABI_H
#define NUMIBRAIN_CONNECTOME_ABI_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

/* NUMICNS1 is the existing NumiLab interchange format, not a new dataset.
 * Offsets below refer to validated, immutable bytes retained by the caller.
 * No pointer from this view is persisted as graph identity. */
typedef struct NBConnectomeGraphView {
  uint64_t fingerprint, source_fingerprint;
  uint64_t node_ids_offset, nodes_offset, offsets_offset;
  uint64_t sources_offset, weights_offset, labels_offset, labels_bytes;
  uint64_t manifest_offset, manifest_bytes;
  uint32_t node_count, edge_count, resolution, reserved;
} NBConnectomeGraphView;

typedef struct NBConnectomeNode {
  float alpha, bias, recurrent_gain, sensory_gain;
  float output_gain, legacy_clip, homeostatic_target, reserved;
  uint32_t identity_low, identity_high, flags, class_hash;
} NBConnectomeNode;

/* Flat indices refer to NumiBrain's already-transduced receptor arena. */
typedef struct NBConnectomeInput {
  uint32_t node, scalar, receptor, reserved;
  float weight, scale, bias, clip;
} NBConnectomeInput;
typedef struct NBConnectomeReadout {
  uint32_t node, channel;
  float weight;
  uint32_t reserved;
} NBConnectomeReadout;

typedef struct NBConnectomeDispatch {
  uint32_t nodes, inputs, readouts, channels;
  uint32_t step_count, reserved0, reserved1, reserved2;
  float time_ratio, output_clip, reserved3, reserved4;
} NBConnectomeDispatch;

/* Failures leave *view zero. Validation never throws across the C boundary.
 * FNV-1a is interchange integrity, NOT a signature or authentication. */
uint32_t nb_connectome_validate(const void *bytes, size_t byte_count,
  uint64_t maximum_bytes, NBConnectomeGraphView *view);
const char *nb_connectome_status_message(uint32_t status);
/* Cold-path projection validator/fingerprint. Zero means invalid.
 * All identity inputs are mandatory; equal shapes cannot rebind a body. */
uint64_t nb_connectome_binding_fingerprint(uint64_t graph, uint64_t species,
  uint64_t sensory_profile, uint64_t parameter_version,
  uint32_t nodes, uint32_t scalars, uint32_t receptors, uint32_t channels,
  uint32_t nominal_step_us, uint32_t integration_step_us,
  const NBConnectomeInput *inputs, uint32_t input_count,
  const NBConnectomeReadout *readouts, uint32_t readout_count);
/* Host compiler/learner utility. Does not step production neural state. */
uint64_t nb_connectome_fnv1a_update(uint64_t seed, const void *bytes, size_t count);
uint64_t nb_connectome_decoder_fingerprint(uint64_t binding_fingerprint,
  uint64_t compiled_species_fingerprint, uint32_t channels, uint32_t actuators,
  uint32_t command_kind, float maximum_drive_change_per_second,
  const float *weights, const float *bias);
#ifdef __cplusplus
}
#endif
#endif
