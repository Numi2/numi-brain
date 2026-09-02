#ifndef NUMIBRAIN_METAL_BRIDGE_ABI_H
#define NUMIBRAIN_METAL_BRIDGE_ABI_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "NumiBrainABI.h"

#define MRNX_BRIDGE_ABI_V1 1u
#define MRNX_OWNER_WIRE_ABI_V4 4u
#define MRNX_FULL_BODY_NQ 129u
#define MRNX_FULL_BODY_NV 128u
#define MRNX_FULL_BODY_MUSCLE_COUNT 416u
#define MRNX_CANDIDATE_CHANNEL_HAS_VALIDITY_V1 (1u << 0u)
#define MRNX_CANDIDATE_MODALITY_VISION_V1 1u
#define MRNX_CANDIDATE_MODALITY_AUDITION_V1 2u
#define MRNX_CANDIDATE_MODALITY_TOUCH_V1 3u
#define MRNX_CANDIDATE_MODALITY_PROPRIOCEPTION_V1 4u
#define MRNX_CANDIDATE_MODALITY_VESTIBULAR_V1 5u
#define MRNX_CANDIDATE_MODALITY_INTEROCEPTION_V1 8u
#define MRNX_CANDIDATE_MODALITY_KINESTHESIA_V1 9u
#define MRNX_AGGREGATE_SNAPSHOT_ABI_V2 2u
#define MRNX_AGGREGATE_SNAPSHOT_ABI_V3 3u
#define MRNX_RUNTIME_CONFIG_ABI_V2 2u
#define MRNX_AGGREGATE_SNAPSHOT_ABI_V4 4u
#define MRNX_CULTURE_ACCEPTED_VIEW_ABI_V1 1u
#define MRNX_CULTURE_PREPARED_VIEW_ABI_V1 1u
#define MRNX_CULTURE_ACCEPTED_BUFFER_COUNT_V1 11u
#define MRNX_MAX_SENSOR_CHANNELS_V2 8u

typedef struct mrnx_runtime_v1 mrnx_runtime_v1;
typedef struct mrnx_prepared_v1 mrnx_prepared_v1;
typedef struct mrnx_candidate_v1 mrnx_candidate_v1;

typedef enum mrnx_element_type_v1 {
  MRNX_ELEMENT_RAW_BYTES_V1 = 0u,
  MRNX_ELEMENT_FLOAT32_V1 = 1u,
  MRNX_ELEMENT_UINT32_V1 = 2u,
} mrnx_element_type_v1;

typedef enum mrnx_completion_status_v1 {
  MRNX_COMPLETION_READY_V1 = 1u,
  MRNX_COMPLETION_ACCEPTED_PENDING_PUBLICATION_V1 = 2u,
  MRNX_COMPLETION_REJECTED_RELEASED_V1 = 3u,
  MRNX_COMPLETION_TERMINAL_NO_TOUCH_V1 = 4u,
  MRNX_COMPLETION_COMMAND_BUFFER_FAILURE_V1 = 5u,
  MRNX_COMPLETION_TIMEOUT_QUARANTINED_V1 = 6u,
} mrnx_completion_status_v1;

typedef enum mrnx_publication_disposition_v1 {
  MRNX_PUBLICATION_RELEASED_V1 = 1u,
  MRNX_PUBLICATION_REJECTED_V1 = 2u,
  MRNX_PUBLICATION_TERMINAL_NO_TOUCH_V1 = 3u,
} mrnx_publication_disposition_v1;

typedef enum mrnx_command_disposition_v1 {
  MRNX_COMMAND_ACCEPTED_PENDING_PUBLICATION_V1 = 1u,
  MRNX_COMMAND_REJECTED_RELEASED_V1 = 2u,
  MRNX_COMMAND_TERMINAL_NO_TOUCH_V1 = 3u,
} mrnx_command_disposition_v1;

typedef enum mrnx_runtime_status_v1 {
  MRNX_RUNTIME_READY_V1 = 1u,
  MRNX_RUNTIME_INVALID_CONFIGURATION_V1 = 2u,
  MRNX_RUNTIME_ASSET_FAILURE_V1 = 3u,
  MRNX_RUNTIME_METAL_FAILURE_V1 = 4u,
  MRNX_RUNTIME_MATTER_FAILURE_V1 = 5u,
  MRNX_RUNTIME_BUSY_V1 = 6u,
  MRNX_RUNTIME_INVALID_REQUEST_V1 = 7u,
  MRNX_RUNTIME_SUBMISSION_FAILURE_V1 = 8u,
  MRNX_RUNTIME_TERMINAL_QUARANTINE_V1 = 9u,
  MRNX_RUNTIME_CONTINUATION_UNAVAILABLE_V1 = 10u,
} mrnx_runtime_status_v1;

typedef struct mrnx_root_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint32_t owner_wire_abi_version;
  uint32_t environment_count;
  uint32_t environment;
  uint32_t transaction_slot;
  uint32_t step_index;
  uint32_t control_step;
  uint32_t substep_index;
  uint32_t physics_substep_count;
  uint32_t q_coordinate_count;
  uint32_t dof_count;
  uint32_t dof_layout_version;
  uint32_t reserved0;
  uint64_t program_fingerprint;
  uint64_t transaction_fingerprint;
  uint64_t linearization_epoch;
  uint64_t slot_generation;
  uint64_t device_registry_id;
} mrnx_root_v1;

typedef struct mrnx_metal_range_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  void *metal_buffer;
  uint64_t gpu_address;
  uint64_t byte_offset;
  uint64_t byte_count;
  uint32_t element_type;
  uint32_t element_byte_count;
} mrnx_metal_range_v1;

typedef struct mrnx_event_point_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  void *shared_event;
  uint64_t value;
  uint64_t device_registry_id;
} mrnx_event_point_v1;

typedef struct mrnx_candidate_key_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint64_t transaction_fingerprint;
  uint64_t program_fingerprint;
  uint64_t sensor_fingerprint;
  uint64_t transaction_instance_fingerprint;
  uint64_t sensor_generation;
  uint64_t command_buffer_identity;
  uint64_t fingerprint;
} mrnx_candidate_key_v1;

typedef struct mrnx_candidate_view_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  mrnx_candidate_key_v1 key;
  uint64_t accepted_brain_generation;
  uint64_t candidate_publication_fingerprint;
  uint64_t candidate_identity_fingerprint;
  uint64_t device_registry_id;
  uint32_t channel_count;
  uint32_t reserved0;
} mrnx_candidate_view_v1;

typedef struct mrnx_candidate_channel_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint32_t modality;
  uint32_t flags;
  uint64_t receptor_timestamp_microseconds;
  uint32_t receptor_count;
  uint32_t feature_dimension;
  mrnx_metal_range_v1 values;
  mrnx_metal_range_v1 validity;
} mrnx_candidate_channel_v1;

typedef struct mrnx_candidate_timing_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint64_t capture_timestamp_microseconds;
  uint64_t delivery_timestamp_microseconds;
  uint32_t latency_microseconds;
  uint32_t sample_interval_microseconds;
  uint64_t timing_fingerprint;
} mrnx_candidate_timing_v1;

typedef struct mrnx_wire_lease_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  mrnx_root_v1 root;
  mrnx_metal_range_v1 record;
  mrnx_event_point_v1 ready;
} mrnx_wire_lease_v1;

typedef struct mrnx_proposal_view_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  mrnx_root_v1 root;
  mrnx_metal_range_v1 proposal;
  mrnx_metal_range_v1 proposed_token;
  mrnx_metal_range_v1 publication_fence;
  mrnx_event_point_v1 ready;
} mrnx_proposal_view_v1;

typedef struct mrnx_applied_view_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  mrnx_root_v1 root;
  mrnx_metal_range_v1 applied;
  mrnx_metal_range_v1 final_token;
  mrnx_event_point_v1 ready;
  uint32_t command_disposition;
  uint32_t reserved0;
} mrnx_applied_view_v1;

typedef struct mrnx_completion_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint32_t status;
  uint32_t metal_status;
  uint64_t slot_generation;
} mrnx_completion_v1;

typedef struct mrnx_publication_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint64_t joint_commit_fingerprint;
  uint64_t brain_generation;
} mrnx_publication_v1;

typedef struct mrnx_runtime_config_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  void *metal_device;
  const char *rigid_payload_path;
  const char *muscle_payload_path;
  const char *support_contact_payload_path;
  const char *visual_pack_path;
  const char *vision_profile_path;
  const char *metalrobo_metallib_path;
  const char *matter_metallib_path;
  const char *matter_material_path;
  uint64_t timestep_microseconds;
  uint64_t maximum_retained_bytes;
  uint32_t transaction_slot_count;
  uint32_t reserved0;
} mrnx_runtime_config_v1;

typedef struct mrnx_runtime_config_v2 {
  uint32_t abi_version;
  uint32_t struct_size;
  void *metal_device;
  const char *rigid_payload_path;
  const char *muscle_payload_path;
  const char *support_contact_payload_path;
  const char *visual_pack_path;
  const char *vision_profile_path;
  const char *metalrobo_metallib_path;
  const char *matter_metallib_path;
  const char *matter_material_path;
  uint64_t timestep_microseconds;
  uint64_t maximum_retained_bytes;
  uint32_t transaction_slot_count;
  uint32_t reserved0;
  const char *culture_pack_path;
  const char *culture_checkpoint_path;
  const char *culture_protocol_path;
  uint32_t culture_window_ticks;
  float culture_current_per_newton;
} mrnx_runtime_config_v2;

typedef struct mrnx_runtime_info_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint32_t status;
  uint32_t body_count;
  uint32_t q_coordinate_count;
  uint32_t dof_count;
  uint32_t muscle_count;
  uint32_t transaction_slot_count;
  uint32_t request_failure_stage;
  uint32_t resident_continuation_count;
  uint64_t device_registry_id;
  uint64_t accepted_state_proof_program_fingerprint;
  uint64_t model_source_fingerprint;
} mrnx_runtime_info_v1;

typedef struct mrnx_joint_anatomy_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint32_t joint_identifier;
  uint32_t parent_body_identifier;
  uint32_t child_body_identifier;
  uint32_t coordinate_offset;
  uint32_t coordinate_count;
  uint32_t reserved0;
  float parent_local_anchor[3];
  float reserved1;
  float child_local_anchor[3];
  float reserved2;
  float rest_relative_orientation[4];
} mrnx_joint_anatomy_v1;

typedef struct mrnx_runtime_anatomy_info_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint32_t body_count;
  uint32_t joint_count;
  uint32_t coordinate_count;
  uint32_t muscle_count;
  uint32_t head_body_identifier;
  uint32_t reserved0;
  uint64_t model_source_fingerprint;
} mrnx_runtime_anatomy_info_v1;

typedef struct mrnx_joint_coordinate_anatomy_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint32_t joint_identifier;
  uint32_t coordinate_identifier;
  uint32_t kind;
  uint32_t q_index;
  uint32_t v_index;
  uint32_t flags;
  float parent_local_axis[3];
  float minimum_position;
  float maximum_position;
  float rest_position;
  float reserved0;
  float reserved1;
} mrnx_joint_coordinate_anatomy_v1;

typedef struct mrnx_muscle_attachment_anatomy_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint32_t muscle_identifier;
  uint32_t route_node_count;
  uint32_t first_body_identifier;
  uint32_t terminal_body_identifier;
  uint32_t reserved0;
  uint32_t reserved1;
  float first_local_point[3];
  float reserved2;
  float terminal_local_point[3];
  float reserved3;
} mrnx_muscle_attachment_anatomy_v1;

enum mrnx_joint_coordinate_kind_v1 {
  MRNX_JOINT_COORDINATE_ANGULAR_V1 = 1u,
  MRNX_JOINT_COORDINATE_LINEAR_V1 = 2u,
};

enum mrnx_joint_coordinate_flags_v1 {
  MRNX_JOINT_COORDINATE_POSITION_LIMIT_V1 = 1u << 0u,
};

typedef struct mrnx_aggregate_snapshot_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint64_t publication_epoch;
  uint64_t brain_generation;
  uint64_t physics_generation;
  uint64_t sensor_generation;
  mrnx_root_v1 root;
  mrnx_candidate_view_v1 sensor;
  mrnx_candidate_channel_v1 proprioception;
  mrnx_candidate_channel_v1 interoception;
} mrnx_aggregate_snapshot_v1;

typedef struct mrnx_aggregate_snapshot_v2 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint64_t publication_epoch;
  uint64_t brain_generation;
  uint64_t physics_generation;
  uint64_t sensor_generation;
  mrnx_root_v1 root;
  mrnx_candidate_view_v1 sensor;
  uint32_t channel_count;
  uint32_t channel_capacity;
  mrnx_candidate_channel_v1 channels[MRNX_MAX_SENSOR_CHANNELS_V2];
} mrnx_aggregate_snapshot_v2;

typedef struct mrnx_aggregate_snapshot_v3 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint64_t publication_epoch;
  uint64_t brain_generation;
  uint64_t physics_generation;
  uint64_t sensor_generation;
  mrnx_root_v1 root;
  mrnx_candidate_view_v1 sensor;
  mrnx_candidate_timing_v1 timing;
  uint32_t channel_count;
  uint32_t channel_capacity;
  mrnx_candidate_channel_v1 channels[MRNX_MAX_SENSOR_CHANNELS_V2];
} mrnx_aggregate_snapshot_v3;

typedef struct mrnx_culture_accepted_view_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint64_t culture_fingerprint;
  uint64_t generation;
  uint64_t tick;
  uint64_t growth_generation;
  uint64_t source_root_fingerprint;
  uint64_t receipt_fingerprint;
  mrnx_event_point_v1 ready;
  uint32_t buffer_count;
  uint32_t reserved0;
  mrnx_metal_range_v1 buffers[MRNX_CULTURE_ACCEPTED_BUFFER_COUNT_V1];
} mrnx_culture_accepted_view_v1;

typedef struct mrnx_culture_prepared_view_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  mrnx_root_v1 root;
  uint64_t culture_fingerprint;
  uint64_t accepted_generation;
  uint64_t prepared_generation;
  uint64_t source_root_fingerprint;
  uint64_t receipt_fingerprint;
  mrnx_event_point_v1 ready;
  uint32_t status;
  uint32_t reserved0;
} mrnx_culture_prepared_view_v1;

typedef struct mrnx_aggregate_snapshot_v4 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint64_t publication_epoch;
  uint64_t brain_generation;
  uint64_t physics_generation;
  uint64_t sensor_generation;
  mrnx_root_v1 root;
  mrnx_candidate_view_v1 sensor;
  mrnx_candidate_timing_v1 timing;
  uint32_t channel_count;
  uint32_t channel_capacity;
  mrnx_candidate_channel_v1 channels[MRNX_MAX_SENSOR_CHANNELS_V2];
  mrnx_culture_accepted_view_v1 culture;
} mrnx_aggregate_snapshot_v4;

typedef struct mrnx_physical_root_request_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  NBJointTransactionToken root;
  NBJointSubstepToken substep;
  NBNumanXMotorCandidate candidate;
  mrnx_metal_range_v1 motor_header;
  mrnx_metal_range_v1 muscle_excitation;
  mrnx_metal_range_v1 autonomic_command;
  mrnx_metal_range_v1 active_sensing_command;
  mrnx_metal_range_v1 motor_ready_gate;
  mrnx_event_point_v1 motor_ready;
} mrnx_physical_root_request_v1;

_Static_assert(sizeof(mrnx_root_v1) == 96u, "mrnx root ABI");
_Static_assert(sizeof(mrnx_metal_range_v1) == 48u, "mrnx range ABI");
_Static_assert(sizeof(mrnx_event_point_v1) == 32u, "mrnx event ABI");
_Static_assert(sizeof(mrnx_candidate_view_v1) == 112u, "mrnx candidate ABI");
_Static_assert(sizeof(mrnx_candidate_channel_v1) == 128u, "mrnx channel ABI");
_Static_assert(sizeof(mrnx_candidate_timing_v1) == 40u,
               "mrnx timing ABI");
_Static_assert(offsetof(mrnx_candidate_timing_v1, timing_fingerprint) == 32u,
               "mrnx timing fingerprint offset");
_Static_assert(sizeof(mrnx_wire_lease_v1) == 184u, "mrnx wire ABI");
_Static_assert(sizeof(mrnx_proposal_view_v1) == 280u, "mrnx proposal ABI");
_Static_assert(sizeof(mrnx_applied_view_v1) == 240u, "mrnx applied ABI");
_Static_assert(sizeof(mrnx_runtime_config_v1) == 104u, "mrnx config ABI");
_Static_assert(sizeof(mrnx_runtime_config_v2) == 136u, "mrnx config v2 ABI");
_Static_assert(offsetof(mrnx_runtime_config_v2, culture_pack_path) == 104u,
               "mrnx config v2 culture offset");
_Static_assert(sizeof(mrnx_runtime_info_v1) == 64u, "mrnx info ABI");
_Static_assert(sizeof(mrnx_joint_anatomy_v1) == 80u,
               "mrnx joint anatomy ABI");
_Static_assert(offsetof(mrnx_joint_anatomy_v1,
                        rest_relative_orientation) == 64u,
               "mrnx joint anatomy orientation offset");
_Static_assert(sizeof(mrnx_joint_coordinate_anatomy_v1) == 64u,
               "mrnx joint coordinate anatomy ABI");
_Static_assert(offsetof(mrnx_joint_coordinate_anatomy_v1,
                        parent_local_axis) == 32u,
               "mrnx joint coordinate axis offset");
_Static_assert(sizeof(mrnx_muscle_attachment_anatomy_v1) == 64u,
               "mrnx muscle anatomy ABI");
_Static_assert(sizeof(mrnx_runtime_anatomy_info_v1) == 40u,
               "mrnx runtime anatomy info ABI");
_Static_assert(offsetof(mrnx_muscle_attachment_anatomy_v1,
                        first_local_point) == 32u,
               "mrnx muscle anatomy point offset");
_Static_assert(sizeof(mrnx_aggregate_snapshot_v1) == 504u, "mrnx snapshot ABI");
_Static_assert(sizeof(mrnx_aggregate_snapshot_v2) == 1280u,
               "mrnx snapshot v2 ABI");
_Static_assert(offsetof(mrnx_aggregate_snapshot_v2, root) == 40u,
               "mrnx snapshot v2 root offset");
_Static_assert(offsetof(mrnx_aggregate_snapshot_v2, sensor) == 136u,
               "mrnx snapshot v2 sensor offset");
_Static_assert(offsetof(mrnx_aggregate_snapshot_v2, channel_count) == 248u,
               "mrnx snapshot v2 count offset");
_Static_assert(offsetof(mrnx_aggregate_snapshot_v2, channels) == 256u,
               "mrnx snapshot v2 channels offset");
_Static_assert(sizeof(mrnx_aggregate_snapshot_v3) == 1320u,
               "mrnx snapshot v3 ABI");
_Static_assert(offsetof(mrnx_aggregate_snapshot_v3, timing) == 248u,
               "mrnx snapshot v3 timing offset");
_Static_assert(offsetof(mrnx_aggregate_snapshot_v3, channel_count) == 288u,
               "mrnx snapshot v3 count offset");
_Static_assert(offsetof(mrnx_aggregate_snapshot_v3, channels) == 296u,
               "mrnx snapshot v3 channels offset");
_Static_assert(sizeof(mrnx_culture_accepted_view_v1) == 624u,
               "mrnx culture accepted ABI");
_Static_assert(offsetof(mrnx_culture_accepted_view_v1,
                        receipt_fingerprint) == 48u,
               "mrnx culture accepted receipt offset");
_Static_assert(offsetof(mrnx_culture_accepted_view_v1, buffers) == 96u,
               "mrnx culture accepted buffers offset");
_Static_assert(sizeof(mrnx_culture_prepared_view_v1) == 184u,
               "mrnx culture prepared ABI");
_Static_assert(sizeof(mrnx_aggregate_snapshot_v4) == 1944u,
               "mrnx snapshot v4 ABI");
_Static_assert(offsetof(mrnx_aggregate_snapshot_v4, culture) == 1320u,
               "mrnx snapshot v4 culture offset");
_Static_assert(sizeof(mrnx_physical_root_request_v1) == 600u, "mrnx request ABI");
_Static_assert(offsetof(mrnx_physical_root_request_v1, motor_header) == 328u,
               "mrnx request motor offset");
_Static_assert(offsetof(mrnx_physical_root_request_v1, motor_ready_gate) == 520u,
               "mrnx request gate offset");
_Static_assert(offsetof(mrnx_physical_root_request_v1, motor_ready) == 568u,
               "mrnx request event offset");

#endif
