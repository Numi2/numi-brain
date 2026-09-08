#ifndef NUMIBRAIN_NUMILAB_BRIDGE_ABI_H
#define NUMIBRAIN_NUMILAB_BRIDGE_ABI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NBNumiLabBorrowedRollout NBNumiLabBorrowedRollout;

typedef struct NBNumiLabRolloutIdentityV1 {
  uint32_t environment_count;
  uint32_t action_count;
  uint64_t run_fingerprint;
  uint64_t world_fingerprint;
  uint64_t task_fingerprint;
  uint64_t action_fingerprint;
  uint64_t robot_fingerprint;
  uint64_t submitted_control_steps;
  uint64_t completed_environment_steps;
  uint64_t submission_count;
} NBNumiLabRolloutIdentityV1;

typedef struct NBNumiLabAdvanceResultV1 {
  uint32_t control_step_count;
  uint32_t successful_environment_steps;
  uint32_t failed_environment_steps;
  uint32_t first_failing_environment;
  uint32_t first_failing_control_step;
  uint32_t first_gpu_status_code;
  uint32_t host_requested_resets;
  uint32_t maximum_active_contacts;
  uint32_t maximum_manifolds;
  double gpu_milliseconds;
  double submission_milliseconds;
} NBNumiLabAdvanceResultV1;

typedef struct NBNumiLabActionBindingV1 {
  uint32_t action_index;
  uint32_t dof_index;
  uint32_t q_index;
  uint32_t v_index;
  float normalized_scale;
  float lower_target;
  float upper_target;
  float response_time_seconds;
  float drive_stiffness;
  float drive_damping;
  uint32_t interaction_motion;
  uint32_t reserved0;
  uint32_t actuator_kind;
  uint32_t resolved_component;
  uint32_t component_lane;
  uint32_t flags;
} NBNumiLabActionBindingV1;

// Opens only the symbol bridge. `rollout_handle` remains caller-owned and must
// be a live MRTaskRolloutHandle created by the same loaded NumiLab library.
NBNumiLabBorrowedRollout* nb_numilab_borrowed_rollout_open(
  const char* dylib_path,
  void* rollout_handle,
  char* error_buffer,
  size_t error_buffer_count
);
void nb_numilab_borrowed_rollout_destroy(NBNumiLabBorrowedRollout* bridge);

int nb_numilab_borrowed_rollout_identity(
  NBNumiLabBorrowedRollout* bridge,
  NBNumiLabRolloutIdentityV1* output
);

size_t nb_numilab_borrowed_rollout_action_binding_count(
  NBNumiLabBorrowedRollout* bridge
);
int nb_numilab_borrowed_rollout_copy_action_bindings(
  NBNumiLabBorrowedRollout* bridge,
  NBNumiLabActionBindingV1* output,
  size_t output_count
);

// Returns the physical owner's complete persistent continuation-state digest,
// or zero unless the rollout owns an initialized accepted idle resident state.
uint64_t nb_numilab_borrowed_rollout_resident_state_fingerprint(
  NBNumiLabBorrowedRollout* bridge
);

// Compatibility execution boundary: exactly one externally authored action
// frame. Batched/multi-step use is deliberately rejected by the Swift owner.
int nb_numilab_borrowed_rollout_advance(
  NBNumiLabBorrowedRollout* bridge,
  const float* normalized_actions,
  size_t normalized_action_count,
  uint64_t policy_revision,
  NBNumiLabAdvanceResultV1* output
);

const char* nb_numilab_borrowed_rollout_last_error(
  const NBNumiLabBorrowedRollout* bridge
);

#ifdef __cplusplus
}
#endif
#endif
