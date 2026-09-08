#pragma once
#include <stddef.h>
#include <stdint.h>
// Test-only mirror of the pinned owner ABI, not a physics implementation.
// Apple CI also compiles this fixture with the actual pinned c_api.h.
typedef struct MRTaskRolloutHandle MRTaskRolloutHandle;


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

typedef struct MRTaskActionBindingC {
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
} MRTaskActionBindingC;
