#include "NumiBrainNumiLabBridgeABI.h"

#include <dlfcn.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Mirrors the pinned owner's C ABI. Tests optionally compile against its actual
// header as well; no runtime physics implementation is embedded in this bridge.
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

typedef NBNumiLabActionBindingV1 MRTaskActionBindingC;
typedef MRTaskRolloutLayoutC (*layout_fn)(const void*);
typedef int (*advance_fn)(
  void*, const float*, size_t, const uint32_t*, size_t, uint32_t,
  uint64_t, uint32_t, MRTaskRolloutAdvanceC*
);
typedef size_t (*action_binding_count_fn)(const void*);
typedef int (*copy_action_bindings_fn)(const void*, MRTaskActionBindingC*, size_t);
typedef uint64_t (*resident_state_fingerprint_fn)(void*);
typedef const char* (*last_error_fn)(void);

_Static_assert(sizeof(NBNumiLabActionBindingV1) == 64, "action ABI drift");
_Static_assert(sizeof(MRTaskRolloutAdvanceC) == 160, "advance ABI drift");
_Static_assert(sizeof(MRTaskRolloutLayoutC) == 200, "layout ABI drift");
enum { maximum_actions = 4096 };

struct NBNumiLabBorrowedRollout {
  void* library;
  void* rollout;
  layout_fn layout;
  advance_fn advance;
  action_binding_count_fn action_binding_count;
  copy_action_bindings_fn copy_action_bindings;
  resident_state_fingerprint_fn resident_state_fingerprint;
  last_error_fn last_error;
  MRTaskRolloutLayoutC expected;
  NBNumiLabActionBindingV1* bindings;
  int quarantined;
  char error[512];
};

static void copy_error(char* destination, size_t count, const char* message) {
  if (destination == NULL || count == 0) return;
  if (message == NULL || message[0] == '\0') message = "unknown NumiLab bridge error";
  snprintf(destination, count, "%s", message);
}

static int failure(NBNumiLabBorrowedRollout* bridge, const char* message, int quarantine) {
  if (bridge != NULL && !bridge->quarantined) {
    copy_error(bridge->error, sizeof(bridge->error), message);
    bridge->quarantined = quarantine;
  }
  return -1;
}

static int valid_layout(const MRTaskRolloutLayoutC* x) {
  return x->environment_count > 0 && x->action_count > 0 && x->action_count <= maximum_actions &&
    x->run_fingerprint != 0 && x->world_fingerprint != 0 &&
    x->task_fingerprint != 0 && x->action_fingerprint != 0 && x->robot_fingerprint != 0;
}

static int same_model(const MRTaskRolloutLayoutC* a, const MRTaskRolloutLayoutC* b) {
#define SAME(field) if (a->field != b->field) return 0
  SAME(environment_count); SAME(nq); SAME(nv); SAME(action_count);
  SAME(actor_observation_count); SAME(critic_observation_count); SAME(scene_body_count);
  SAME(motion_feature_count); SAME(maximum_episode_steps); SAME(world_fingerprint);
  SAME(task_fingerprint); SAME(observation_fingerprint); SAME(action_fingerprint);
  SAME(run_fingerprint); SAME(robot_fingerprint); SAME(sensor_fingerprint);
  SAME(reality_fingerprint); SAME(teacher_fingerprint);
#undef SAME
  return 1;
}

static int same_counters(const MRTaskRolloutLayoutC* a, const MRTaskRolloutLayoutC* b) {
  return a->submission_count == b->submission_count &&
    a->submitted_control_steps == b->submitted_control_steps &&
    a->completed_environment_steps == b->completed_environment_steps;
}

static int valid_binding(const NBNumiLabActionBindingV1* b, size_t index) {
  return b->action_index == index && b->reserved0 == 0 && b->interaction_motion <= 1 &&
    b->actuator_kind <= 7 && isfinite(b->normalized_scale) && b->normalized_scale > 0 &&
    isfinite(b->lower_target) && isfinite(b->upper_target) && b->lower_target <= b->upper_target &&
    isfinite(b->response_time_seconds) && b->response_time_seconds >= 0 &&
    isfinite(b->drive_stiffness) && b->drive_stiffness >= 0 &&
    isfinite(b->drive_damping) && b->drive_damping >= 0;
}

static int unchanged_bindings(NBNumiLabBorrowedRollout* b) {
  const size_t count = b->expected.action_count;
  NBNumiLabActionBindingV1 actual[maximum_actions];
  if (b->action_binding_count(b->rollout) != count ||
      b->copy_action_bindings(b->rollout, actual, count) != 0 ||
      memcmp(actual, b->bindings, count * sizeof(*actual)) != 0) {
    return failure(b, "NumiLab compiled action bindings changed after admission", 1);
  }
  return 0;
}

// Track both immutable layout and last admitted counters, not merely positive
// fingerprints. Calls through another wrapper/external owner are unsupported.
static int live(NBNumiLabBorrowedRollout* b, MRTaskRolloutLayoutC* result) {
  if (b == NULL || b->quarantined) return -1;
  *result = b->layout(b->rollout);
  if (!same_model(result, &b->expected) || !same_counters(result, &b->expected)) {
    return failure(b, "NumiLab live identity or counters changed outside the owning bridge", 1);
  }
  return unchanged_bindings(b);
}

NBNumiLabBorrowedRollout* nb_numilab_borrowed_rollout_open(
  const char* dylib_path, void* rollout_handle, char* error_buffer, size_t error_buffer_count
) {
  if (error_buffer != NULL && error_buffer_count > 0) error_buffer[0] = '\0';
  if (dylib_path == NULL || dylib_path[0] == '\0' || rollout_handle == NULL) {
    copy_error(error_buffer, error_buffer_count, "NumiLab library path and rollout handle are required");
    return NULL;
  }
  void* library = dlopen(dylib_path, RTLD_NOW | RTLD_LOCAL);
  if (library == NULL) { copy_error(error_buffer, error_buffer_count, dlerror()); return NULL; }
  NBNumiLabBorrowedRollout* b = calloc(1, sizeof(*b));
  if (b == NULL) {
    dlclose(library); copy_error(error_buffer, error_buffer_count, "NumiLab bridge allocation failed"); return NULL;
  }
  b->library = library; b->rollout = rollout_handle;
  b->layout = (layout_fn)dlsym(library, "mr_task_rollout_layout");
  b->advance = (advance_fn)dlsym(library, "mr_task_rollout_advance");
  b->action_binding_count = (action_binding_count_fn)dlsym(library, "mr_task_rollout_action_binding_count");
  b->copy_action_bindings = (copy_action_bindings_fn)dlsym(library, "mr_task_rollout_copy_action_bindings");
  b->resident_state_fingerprint = (resident_state_fingerprint_fn)dlsym(library, "mr_task_rollout_resident_state_fingerprint");
  b->last_error = (last_error_fn)dlsym(library, "mr_last_error");
  if (b->layout == NULL || b->advance == NULL || b->action_binding_count == NULL ||
      b->copy_action_bindings == NULL || b->resident_state_fingerprint == NULL || b->last_error == NULL) {
    failure(b, "NumiLab physical-owner ABI symbols are missing", 1); goto rejected;
  }
  b->expected = b->layout(b->rollout);
  const size_t count = b->expected.action_count;
  if (!valid_layout(&b->expected) || b->action_binding_count(b->rollout) != count) {
    failure(b, "borrowed NumiLab rollout returned an invalid physical-owner identity", 1); goto rejected;
  }
  b->bindings = calloc(count, sizeof(*b->bindings));
  if (b->bindings == NULL || b->copy_action_bindings(b->rollout, b->bindings, count) != 0) {
    failure(b, "NumiLab compiled action table could not be retained", 1); goto rejected;
  }
  for (size_t i = 0; i < count; ++i) if (!valid_binding(&b->bindings[i], i)) {
    failure(b, "NumiLab compiled action table is malformed", 1); goto rejected;
  }
  MRTaskRolloutLayoutC stable;
  if (live(b, &stable) != 0) goto rejected;
  return b;
rejected:
  copy_error(error_buffer, error_buffer_count, b->error);
  nb_numilab_borrowed_rollout_destroy(b);
  return NULL;
}

void nb_numilab_borrowed_rollout_destroy(NBNumiLabBorrowedRollout* b) {
  if (b == NULL) return;
  free(b->bindings);
  if (b->library != NULL) dlclose(b->library);
  free(b);
}

int nb_numilab_borrowed_rollout_identity(NBNumiLabBorrowedRollout* b, NBNumiLabRolloutIdentityV1* output) {
  if (output == NULL) return failure(b, "NumiLab identity output is null", 0);
  memset(output, 0, sizeof(*output));
  MRTaskRolloutLayoutC x;
  if (live(b, &x) != 0) return -1;
  output->environment_count = x.environment_count; output->action_count = x.action_count;
  output->run_fingerprint = x.run_fingerprint; output->world_fingerprint = x.world_fingerprint;
  output->task_fingerprint = x.task_fingerprint; output->action_fingerprint = x.action_fingerprint;
  output->robot_fingerprint = x.robot_fingerprint;
  output->submitted_control_steps = x.submitted_control_steps;
  output->completed_environment_steps = x.completed_environment_steps;
  output->submission_count = x.submission_count;
  b->error[0] = '\0'; return 0;
}

size_t nb_numilab_borrowed_rollout_action_binding_count(NBNumiLabBorrowedRollout* b) {
  MRTaskRolloutLayoutC x;
  return live(b, &x) == 0 ? x.action_count : 0;
}

int nb_numilab_borrowed_rollout_copy_action_bindings(
  NBNumiLabBorrowedRollout* b, NBNumiLabActionBindingV1* output, size_t count
) {
  if (output == NULL || count == 0 || count > maximum_actions) return failure(b, "NumiLab binding output is invalid", 0);
  memset(output, 0, count * sizeof(*output));
  if (b == NULL) return -1;
  if (count != b->expected.action_count) return failure(b, "NumiLab binding output count is not exact", 0);
  MRTaskRolloutLayoutC x;
  if (live(b, &x) != 0) return -1;
  memcpy(output, b->bindings, count * sizeof(*output));
  b->error[0] = '\0'; return 0;
}

uint64_t nb_numilab_borrowed_rollout_resident_state_fingerprint(NBNumiLabBorrowedRollout* b) {
  MRTaskRolloutLayoutC x;
  if (live(b, &x) != 0) return 0;
  // A fresh world has no accepted boundary; do not quarantine it for inspection.
  if (x.completed_environment_steps == 0) { failure(b, "NumiLab has no accepted step yet", 0); return 0; }
  const uint64_t fingerprint = b->resident_state_fingerprint(b->rollout);
  if (fingerprint == 0) { failure(b, "NumiLab accepted resident-state digest is unavailable", 1); return 0; }
  if (live(b, &x) != 0) return 0;
  b->error[0] = '\0'; return fingerprint;
}

int nb_numilab_borrowed_rollout_advance(
  NBNumiLabBorrowedRollout* b, const float* normalized_actions,
  size_t count, uint64_t policy_revision, NBNumiLabAdvanceResultV1* output
) {
  if (output == NULL) return failure(b, "NumiLab advance output is null", 0);
  memset(output, 0, sizeof(*output));
  if (b == NULL || b->quarantined) return -1;
  if (normalized_actions == NULL || count == 0 || count > maximum_actions) {
    return failure(b, "NumiLab action input is invalid", 0);
  }
  float actions[maximum_actions];
  for (size_t i = 0; i < count; ++i) {
    actions[i] = normalized_actions[i];
    if (!isfinite(actions[i])) return failure(b, "NumiLab action input is non-finite", 0);
  }
  MRTaskRolloutLayoutC before;
  if (live(b, &before) != 0) return -1;
  if (before.environment_count != 1 || before.action_count != count) {
    return failure(b, "compatibility advance requires one environment and one exact compiled action frame", 0);
  }
  if (before.submission_count == UINT64_MAX || before.submitted_control_steps == UINT64_MAX ||
      before.completed_environment_steps == UINT64_MAX) {
    return failure(b, "NumiLab advance counters would overflow", 0);
  }
  MRTaskRolloutAdvanceC native = {0};
  const int status = b->advance(b->rollout, actions, count, NULL, 0, 1, policy_revision, 0, &native);
  // Once the native function has been entered a failure cannot be assumed
  // mutation-free. A quarantined bridge never silently retries the world.
  if (status != 0) return failure(b, b->last_error(), 1);
  const MRTaskRolloutLayoutC after = b->layout(b->rollout);
  if (!same_model(&after, &before) ||
      after.submission_count != before.submission_count + 1 ||
      after.submitted_control_steps != before.submitted_control_steps + 1 ||
      after.completed_environment_steps != before.completed_environment_steps + 1 ||
      unchanged_bindings(b) != 0) {
    return failure(b, "NumiLab identity, bindings or counters drifted during advance", 1);
  }
  if (native.control_step_count != 1 || native.successful_environment_steps != 1 ||
      native.failed_environment_steps != 0 || native.host_requested_resets != 0 ||
      native.first_gpu_status_code != 0 || !isfinite(native.gpu_milliseconds) ||
      native.gpu_milliseconds < 0 || !isfinite(native.submission_milliseconds) ||
      native.submission_milliseconds < 0) {
    return failure(b, "NumiLab did not return one clean accepted step", 1);
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
  b->expected = after; b->error[0] = '\0'; return 0;
}

const char* nb_numilab_borrowed_rollout_last_error(const NBNumiLabBorrowedRollout* b) {
  return b == NULL ? "NumiLab borrowed rollout bridge is null" : b->error;
}
