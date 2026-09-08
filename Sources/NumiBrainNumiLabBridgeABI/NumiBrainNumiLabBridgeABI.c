#include "NumiBrainNumiLabBridgeABI.h"

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct MRTaskRolloutStageHighWaterC {
  uint32_t candidate_pairs;
  uint32_t raw_contacts;
  uint32_t manifolds;
  uint32_t constraint_blocks;
  uint32_t constraint_rows;
  uint32_t islands;
  uint32_t hard_convex_pairs;
  uint32_t mesh_triangle_candidates;
  uint32_t solver_tiles;
  uint32_t spill_rows;
  uint32_t ccd_candidates;
  uint32_t ccd_events;
  uint32_t endpoint_runtime_records;
  uint32_t articulation_point_queries;
  uint32_t rod_candidate_pairs;
  uint32_t rod_raw_contacts;
  uint32_t rod_manifolds;
  uint32_t rod_ccd_events;
  uint32_t quality_generalized_velocities;
  uint32_t quality_rows;
  uint32_t quality_krylov_vectors;
  uint32_t quality_direct_tiles;
  uint32_t dynamic_nodes;
  uint32_t island_node_references;
  uint32_t island_constraint_references;
  uint32_t rod_factor_blocks;
  uint32_t operator_velocity_elements;
} MRTaskRolloutStageHighWaterC;

typedef struct MRTaskRolloutAdvanceC {
  uint32_t control_step_count;
  uint32_t successful_environment_steps;
  uint32_t failed_environment_steps;
  uint32_t first_failing_environment;
  uint32_t first_failing_control_step;
  uint32_t first_gpu_status_code;
  uint32_t host_requested_resets;
  uint32_t maximum_active_contacts;
  uint32_t maximum_manifolds;
  MRTaskRolloutStageHighWaterC high_water;
  double gpu_milliseconds;
  double submission_milliseconds;
} MRTaskRolloutAdvanceC;

typedef struct MRTaskRolloutLayoutC {
  uint32_t environment_count;
  uint32_t nq;
  uint32_t nv;
  uint32_t action_count;
  uint32_t actor_observation_count;
  uint32_t critic_observation_count;
  uint32_t scene_body_count;
  uint32_t motion_feature_count;
  uint32_t maximum_episode_steps;
  uint64_t world_fingerprint;
  uint64_t task_fingerprint;
  uint64_t observation_fingerprint;
  uint64_t action_fingerprint;
  uint64_t run_fingerprint;
  uint64_t robot_fingerprint;
  uint64_t sensor_fingerprint;
  uint64_t reality_fingerprint;
  uint64_t teacher_fingerprint;
  uint64_t submitted_control_steps;
  uint64_t completed_environment_steps;
  uint64_t submission_count;
  size_t retained_buffer_bytes;
  size_t immutable_private_bytes;
  size_t persistent_state_private_bytes;
  size_t transient_private_bytes;
  size_t shared_boundary_bytes;
  size_t peak_aliased_bytes;
  double total_gpu_milliseconds;
  double total_submission_milliseconds;
} MRTaskRolloutLayoutC;

typedef MRTaskRolloutLayoutC (*layout_fn)(const void*);
typedef int (*advance_fn)(
  void*, const float*, size_t, const uint32_t*, size_t, uint32_t,
  uint64_t, uint32_t, MRTaskRolloutAdvanceC*
);
typedef const char* (*last_error_fn)(void);

struct NBNumiLabBorrowedRollout {
  void* library;
  void* rollout;
  layout_fn layout;
  advance_fn advance;
  last_error_fn last_error;
  char error[512];
};

static void copy_error(char* destination, size_t count, const char* message) {
  if (destination == NULL || count == 0) return;
  if (message == NULL) message = "unknown NumiLab bridge error";
  snprintf(destination, count, "%s", message);
}

static void set_error(NBNumiLabBorrowedRollout* bridge, const char* message) {
  if (bridge == NULL) return;
  copy_error(bridge->error, sizeof(bridge->error), message);
}

NBNumiLabBorrowedRollout* nb_numilab_borrowed_rollout_open(
  const char* dylib_path,
  void* rollout_handle,
  char* error_buffer,
  size_t error_buffer_count
) {
  if (dylib_path == NULL || dylib_path[0] == '\0' || rollout_handle == NULL) {
    copy_error(error_buffer, error_buffer_count,
               "NumiLab library path and rollout handle are required");
    return NULL;
  }
  void* library = dlopen(dylib_path, RTLD_NOW | RTLD_LOCAL);
  if (library == NULL) {
    copy_error(error_buffer, error_buffer_count, dlerror());
    return NULL;
  }
  NBNumiLabBorrowedRollout* bridge = calloc(1, sizeof(*bridge));
  if (bridge == NULL) {
    dlclose(library);
    copy_error(error_buffer, error_buffer_count, "NumiLab bridge allocation failed");
    return NULL;
  }
  bridge->library = library;
  bridge->rollout = rollout_handle;
  bridge->layout = (layout_fn)dlsym(library, "mr_task_rollout_layout");
  bridge->advance = (advance_fn)dlsym(library, "mr_task_rollout_advance");
  bridge->last_error = (last_error_fn)dlsym(library, "mr_last_error");
  if (bridge->layout == NULL || bridge->advance == NULL || bridge->last_error == NULL) {
    set_error(bridge, "NumiLab rollout ABI symbols are missing");
    copy_error(error_buffer, error_buffer_count, bridge->error);
    nb_numilab_borrowed_rollout_destroy(bridge);
    return NULL;
  }
  MRTaskRolloutLayoutC layout = bridge->layout(bridge->rollout);
  if (layout.environment_count == 0 || layout.action_count == 0 ||
      layout.run_fingerprint == 0 || layout.world_fingerprint == 0 ||
      layout.task_fingerprint == 0 || layout.action_fingerprint == 0 ||
      layout.robot_fingerprint == 0) {
    set_error(bridge, "borrowed NumiLab rollout returned an invalid identity");
    copy_error(error_buffer, error_buffer_count, bridge->error);
    nb_numilab_borrowed_rollout_destroy(bridge);
    return NULL;
  }
  bridge->error[0] = '\0';
  return bridge;
}

void nb_numilab_borrowed_rollout_destroy(NBNumiLabBorrowedRollout* bridge) {
  if (bridge == NULL) return;
  if (bridge->library != NULL) dlclose(bridge->library);
  free(bridge);
}

int nb_numilab_borrowed_rollout_identity(
  NBNumiLabBorrowedRollout* bridge,
  NBNumiLabRolloutIdentityV1* output
) {
  if (bridge == NULL || output == NULL || bridge->layout == NULL) return -1;
  MRTaskRolloutLayoutC value = bridge->layout(bridge->rollout);
  if (value.environment_count == 0 || value.action_count == 0 ||
      value.run_fingerprint == 0 || value.world_fingerprint == 0 ||
      value.task_fingerprint == 0 || value.action_fingerprint == 0 ||
      value.robot_fingerprint == 0) {
    set_error(bridge, "live NumiLab rollout identity became invalid");
    return -2;
  }
  output->environment_count = value.environment_count;
  output->action_count = value.action_count;
  output->run_fingerprint = value.run_fingerprint;
  output->world_fingerprint = value.world_fingerprint;
  output->task_fingerprint = value.task_fingerprint;
  output->action_fingerprint = value.action_fingerprint;
  output->robot_fingerprint = value.robot_fingerprint;
  output->submitted_control_steps = value.submitted_control_steps;
  output->completed_environment_steps = value.completed_environment_steps;
  output->submission_count = value.submission_count;
  bridge->error[0] = '\0';
  return 0;
}

int nb_numilab_borrowed_rollout_advance(
  NBNumiLabBorrowedRollout* bridge,
  const float* normalized_actions,
  size_t normalized_action_count,
  uint64_t policy_revision,
  NBNumiLabAdvanceResultV1* output
) {
  if (bridge == NULL || output == NULL || normalized_actions == NULL ||
      normalized_action_count == 0 || bridge->advance == NULL) return -1;
  MRTaskRolloutLayoutC before = bridge->layout(bridge->rollout);
  if (before.environment_count != 1 || before.action_count != normalized_action_count) {
    set_error(bridge, "compatibility advance requires one environment and one exact action frame");
    return -2;
  }
  MRTaskRolloutAdvanceC native = {0};
  int status = bridge->advance(
    bridge->rollout,
    normalized_actions,
    normalized_action_count,
    NULL,
    0,
    1,
    policy_revision,
    0,
    &native
  );
  if (status != 0) {
    const char* owner = bridge->last_error != NULL ? bridge->last_error() : NULL;
    set_error(bridge, owner != NULL ? owner : "NumiLab rollout advance failed");
    return status;
  }
  MRTaskRolloutLayoutC after = bridge->layout(bridge->rollout);
  if (after.run_fingerprint != before.run_fingerprint ||
      after.world_fingerprint != before.world_fingerprint ||
      after.task_fingerprint != before.task_fingerprint ||
      after.action_fingerprint != before.action_fingerprint ||
      after.robot_fingerprint != before.robot_fingerprint ||
      after.submission_count != before.submission_count + 1 ||
      after.submitted_control_steps != before.submitted_control_steps + 1) {
    set_error(bridge, "NumiLab rollout identity or submission counters drifted during advance");
    return -3;
  }
  output->control_step_count = native.control_step_count;
  output->successful_environment_steps = native.successful_environment_steps;
  output->failed_environment_steps = native.failed_environment_steps;
  output->first_failing_environment = native.first_failing_environment;
  output->first_failing_control_step = native.first_failing_control_step;
  output->first_gpu_status_code = native.first_gpu_status_code;
  output->host_requested_resets = native.host_requested_resets;
  output->maximum_active_contacts = native.maximum_active_contacts;
  output->maximum_manifolds = native.maximum_manifolds;
  output->gpu_milliseconds = native.gpu_milliseconds;
  output->submission_milliseconds = native.submission_milliseconds;
  bridge->error[0] = '\0';
  return 0;
}

const char* nb_numilab_borrowed_rollout_last_error(
  const NBNumiLabBorrowedRollout* bridge
) {
  if (bridge == NULL) return "NumiLab borrowed rollout bridge is null";
  return bridge->error;
}
