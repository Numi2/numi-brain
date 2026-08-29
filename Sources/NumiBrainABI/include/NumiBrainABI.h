#ifndef NUMIBRAIN_ABI_H
#define NUMIBRAIN_ABI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum {
  NB_BRAIN_ABI_VERSION = 1,
  NB_MODULE_DESCRIPTOR_BYTE_COUNT = 32,
  NB_MODULE_CLOCK_STATE_BYTE_COUNT = 16,
  NB_RECEPTOR_EVENT_BYTE_COUNT = 64,
  NB_INTERRUPT_EVENT_BYTE_COUNT = 24,
  NB_RECEPTOR_EVENT_TRANSDUCTION_UNIFORMS_BYTE_COUNT = 40,
  NB_RECEPTOR_EVENT_TRANSDUCTION_RESULT_BYTE_COUNT = 16,
  NB_DUE_INVOCATION_BYTE_COUNT = 32,
  NB_SCHEDULER_UNIFORMS_BYTE_COUNT = 56,
  NB_SCHEDULER_RESULT_BYTE_COUNT = 16,
  NB_REGIONAL_MODULE_STATE_BYTE_COUNT = 32,
  NB_REGIONAL_TOKEN_LAYOUT_BYTE_COUNT = 32,
  NB_REGIONAL_ROUTE_BYTE_COUNT = 24,
  NB_REGIONAL_TOKEN_PARAMETERS_BYTE_COUNT = 32,
  NB_REGIONAL_PROGRAM_HEADER_BYTE_COUNT = 48,
  NB_REGIONAL_ROUTE_HISTORY_STATE_BYTE_COUNT = 16,
  NB_REGIONAL_ROUTE_RUNTIME_STATE_BYTE_COUNT = 32,
  NB_PARAMETER_COMPONENT_BYTE_COUNT = 32,
  NB_PARAMETER_VERSION_BINDING_BYTE_COUNT = 64,
  NB_PARAMETER_MANIFEST_VERSION = 1,
  NB_COHORT_ENVIRONMENT_BYTE_COUNT = 40,
  NB_DISPATCH_GROUP_BYTE_COUNT = 24,
  NB_DISPATCH_ENTRY_BYTE_COUNT = 16,
  NB_DISPATCH_PLAN_HEADER_BYTE_COUNT = 48,
  NB_DISPATCH_PLAN_RESULT_BYTE_COUNT = 32,
  NB_DISPATCH_WORK_ITEM_BYTE_COUNT = 32,
  NB_DISPATCH_COHORT_UNIFORMS_BYTE_COUNT = 32,
  NB_DISPATCH_TOKEN_UNIFORMS_BYTE_COUNT = 32,
  NB_JOINT_TRANSACTION_TOKEN_BYTE_COUNT = 96,
  NB_JOINT_SUBSTEP_TOKEN_BYTE_COUNT = 72,
  NB_ACCEPTED_PHYSICS_STATE_TOKEN_BYTE_COUNT = 64,
  NB_JOINT_COMMIT_TOKEN_BYTE_COUNT = 64,
  NB_PROTECTIVE_COMMAND_BYTE_COUNT = 64,
  NB_MOTOR_CHANNEL_DESCRIPTOR_BYTE_COUNT = 32,
  NB_MOTOR_OUTPUT_HEADER_BYTE_COUNT = 64,
  NB_NUMANX_MOTOR_CANDIDATE_BYTE_COUNT = 96,
  NB_DISPATCH_PLAN_VERSION = 1,
  NB_JOINT_TRANSACTION_VERSION = 1,
  NB_PROTECTIVE_COMMAND_VERSION = 1,
  NB_MOTOR_PROFILE_VERSION = 1,
  NB_MOTOR_OUTPUT_VERSION = 2,
  NB_NUMANX_MOTOR_CANDIDATE_VERSION = 1,
  NB_REGIONAL_ROUTE_HISTORY_CAPACITY = 512,
  NB_REGIONAL_MAX_ROUTE_DELAY_MICROSECONDS = 5000,
  NB_REGIONAL_PROGRAM_VERSION = 2,
  NB_REGIONAL_MIN_ROUTE_PERSISTENCE_MICROSECONDS = 2000,
  NB_RECEPTOR_EVENT_ABI_VERSION = 1,
  NB_RECEPTOR_MAX_CONDUCTION_LATENCY_MICROSECONDS = 500000,
  NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED = 1 << 0,
  NB_PROTECTIVE_COMMAND_FLAG_VALID = 1 << 0,
  NB_PROTECTIVE_COMMAND_FLAG_EMERGENCY_STOP = 1 << 1,
  NB_PROTECTIVE_COMMAND_FLAG_WITHDRAWAL = 1 << 2,
  NB_PROTECTIVE_COMMAND_FLAG_POSTURAL_BRACE = 1 << 3,
  NB_PROTECTIVE_COMMAND_FLAG_AUTONOMIC_AROUSAL = 1 << 4,
  NB_MOTOR_CHANNEL_FLAG_VALID = 1 << 0,
  NB_MOTOR_CHANNEL_FLAG_WITHDRAWAL = 1 << 1,
  NB_MOTOR_CHANNEL_FLAG_POSTURAL_BRACE = 1 << 2,
  NB_MOTOR_OUTPUT_FLAG_VALID = 1 << 0,
  NB_MOTOR_OUTPUT_FLAG_EMERGENCY_STOP = 1 << 1,
  NB_MOTOR_OUTPUT_FLAG_LOCALIZED_SOURCE_INHIBITION = 1 << 2,
  NB_MOTOR_OUTPUT_FLAG_LOCALIZED_WITHDRAWAL = 1 << 3,
  NB_NUMANX_MOTOR_CANDIDATE_FLAG_VALID = 1 << 0,
};

typedef struct NBModuleDescriptor {
  uint16_t module_id;
  uint16_t clock_class;
  uint32_t period_microseconds;
  uint32_t conduction_delay_microseconds;
  uint32_t intrinsic_timescale_microseconds;
  uint64_t interrupt_mask;
  uint16_t token_count;
  uint16_t token_dimension;
  uint32_t flags;
} NBModuleDescriptor;

typedef struct NBModuleClockState {
  uint64_t next_due_microseconds;
  uint64_t last_update_microseconds;
} NBModuleClockState;

typedef struct NBReceptorEvent {
  float center_x;
  float center_y;
  float radius;
  float start_milliseconds;
  float end_milliseconds;
  float excitatory_drive;
  float inhibitory_drive;
  float noise_amplitude;
  uint32_t identifier;
  uint32_t flags;
  uint64_t interrupt_mask;
  uint32_t conduction_latency_microseconds;
  uint32_t receptor_identifier;
  float magnitude;
  float auxiliary_value;
} NBReceptorEvent;

typedef struct NBInterruptEvent {
  uint64_t timestamp_microseconds;
  uint64_t interrupt_mask;
  uint32_t identifier;
  uint32_t flags;
} NBInterruptEvent;

typedef struct NBReceptorEventTransductionUniforms {
  uint64_t committed_time_microseconds;
  uint64_t target_time_microseconds;
  uint32_t receptor_event_count;
  uint32_t host_event_count;
  uint32_t event_capacity;
  uint32_t flags;
  uint32_t reserved_0;
  uint32_t reserved_1;
} NBReceptorEventTransductionUniforms;

typedef struct NBReceptorEventTransductionResult {
  uint32_t event_count;
  uint32_t receptor_event_count;
  uint32_t status;
  uint32_t reserved;
} NBReceptorEventTransductionResult;

typedef struct NBDueInvocation {
  uint64_t timestamp_microseconds;
  uint64_t interrupt_mask;
  uint32_t environment_identifier;
  uint16_t module_id;
  uint16_t clock_class;
  uint32_t reason_flags;
  uint32_t reserved;
} NBDueInvocation;

typedef struct NBSchedulerUniforms {
  uint64_t committed_time_microseconds;
  uint64_t target_time_microseconds;
  uint64_t parameter_version_fingerprint;
  uint64_t schedule_fingerprint;
  uint32_t module_count;
  uint32_t event_count;
  uint32_t invocation_capacity;
  uint32_t environment_identifier;
  uint32_t flags;
  uint32_t reserved;
} NBSchedulerUniforms;

typedef struct NBSchedulerResult {
  uint32_t invocation_count;
  uint32_t status;
  uint64_t target_time_microseconds;
} NBSchedulerResult;

typedef struct NBRegionalModuleState {
  float activation;
  float integration;
  float interrupt_salience;
  float phase;
  uint32_t update_count;
  uint32_t interrupt_count;
  uint64_t last_update_microseconds;
} NBRegionalModuleState;

typedef struct NBRegionalTokenLayout {
  uint32_t scalar_offset;
  uint32_t scalar_count;
  uint32_t parameter_offset;
  uint32_t incoming_route_offset;
  uint16_t module_id;
  uint16_t token_count;
  uint16_t token_dimension;
  uint16_t incoming_route_count;
  uint32_t flags;
  uint16_t normal_route_budget;
  uint16_t reserved;
} NBRegionalTokenLayout;

typedef struct NBRegionalRoute {
  uint16_t sender_module_id;
  uint16_t receiver_module_id;
  uint16_t sender_token;
  uint16_t flags;
  uint32_t delay_microseconds;
  float gain;
  uint32_t history_value_offset;
  uint32_t message_dimension;
} NBRegionalRoute;

typedef struct NBRegionalTokenParameters {
  float recurrent_gain;
  float local_gain;
  float route_gain;
  float drive_gain;
  float bias;
  float gate_bias;
  float gate_recurrent_gain;
  float gate_input_gain;
} NBRegionalTokenParameters;

typedef struct NBRegionalProgramHeader {
  uint32_t module_count;
  uint32_t token_scalar_count;
  uint32_t route_count;
  uint32_t parameter_count;
  uint64_t program_fingerprint;
  uint32_t history_capacity;
  uint32_t history_scalar_count;
  uint32_t program_version;
  uint32_t minimum_route_persistence_microseconds;
  float salience_gain;
  float persistence_bonus;
} NBRegionalProgramHeader;

typedef struct NBRegionalRouteHistoryState {
  uint32_t next_slot;
  uint32_t count;
  uint64_t latest_timestamp_microseconds;
} NBRegionalRouteHistoryState;

typedef struct NBRegionalRouteRuntimeState {
  float score;
  float strength;
  uint32_t active;
  uint32_t selection_count;
  uint64_t last_selected_timestamp_microseconds;
  uint32_t switch_count;
  uint32_t reserved;
} NBRegionalRouteRuntimeState;

/// Canonical identity for one immutable shared-parameter component. Component
/// records are ordered strictly by `component_kind` before fingerprinting.
typedef struct NBParameterComponent {
  uint16_t component_kind;
  uint16_t element_type;
  uint32_t flags;
  uint64_t element_count;
  uint64_t byte_count;
  uint64_t content_fingerprint;
} NBParameterComponent;

/// Immutable rollout binding uploaded once with a parameter generation. The
/// version fingerprint authenticates this header (except itself) plus its
/// canonical component records.
typedef struct NBParameterVersionBinding {
  uint32_t format_version;
  uint32_t component_count;
  uint64_t version_sequence;
  uint64_t version_fingerprint;
  uint64_t parent_version_fingerprint;
  uint64_t schedule_fingerprint;
  uint64_t regional_shape_fingerprint;
  uint64_t regional_program_fingerprint;
  uint64_t total_parameter_bytes;
} NBParameterVersionBinding;

/// Canonical source-transaction identity for one independent environment.
typedef struct NBCohortEnvironment {
  uint32_t environment_identifier;
  uint32_t invocation_offset;
  uint32_t invocation_count;
  uint32_t reserved;
  uint64_t base_generation;
  uint64_t base_committed_time_microseconds;
  uint64_t target_time_microseconds;
} NBCohortEnvironment;

/// One contiguous timestamp/module group in a flattened cohort plan.
typedef struct NBDispatchGroup {
  uint64_t timestamp_microseconds;
  uint32_t entry_offset;
  uint32_t entry_count;
  uint16_t module_id;
  uint16_t clock_class;
  uint32_t reserved;
} NBDispatchGroup;

/// One independent environment contribution to a dispatch group.
typedef struct NBDispatchEntry {
  uint64_t interrupt_mask;
  uint32_t environment_identifier;
  uint32_t reason_flags;
} NBDispatchEntry;

/// Content-addressed flattened cohort plan. Source transactions remain
/// independent; groups share one schedule and immutable parameter version.
typedef struct NBDispatchPlanHeader {
  uint64_t schedule_fingerprint;
  uint64_t parameter_version_fingerprint;
  uint64_t cohort_fingerprint;
  uint64_t plan_fingerprint;
  uint32_t group_count;
  uint32_t entry_count;
  uint32_t plan_version;
  uint32_t flags;
} NBDispatchPlanHeader;

typedef struct NBDispatchPlanResult {
  uint32_t group_count;
  uint32_t entry_count;
  uint32_t status;
  uint32_t reserved;
  uint64_t plan_fingerprint;
  uint64_t parameter_version_fingerprint;
} NBDispatchPlanResult;

/// One fully expanded active-environment work item consumed by a downstream
/// indirect dispatch. It retains the source group for deterministic tracing.
typedef struct NBDispatchWorkItem {
  uint64_t timestamp_microseconds;
  uint64_t interrupt_mask;
  uint32_t environment_identifier;
  uint32_t reason_flags;
  uint16_t module_id;
  uint16_t clock_class;
  uint32_t group_index;
} NBDispatchWorkItem;

/// Immutable counts and identities for an indirectly dispatched cohort-state
/// update. State records are environment-major, then canonical module-major.
typedef struct NBDispatchCohortUniforms {
  uint64_t plan_fingerprint;
  uint64_t parameter_version_fingerprint;
  uint32_t environment_count;
  uint32_t module_count;
  uint32_t state_count;
  uint32_t flags;
} NBDispatchCohortUniforms;

/// Immutable shape and identity for one environment-major cohort token-state
/// generation. The total count is 64-bit because production cohorts can
/// contain hundreds of millions of FP32 scalars.
typedef struct NBDispatchTokenUniforms {
  uint64_t regional_program_fingerprint;
  uint64_t schedule_fingerprint;
  uint32_t environment_count;
  uint32_t scalar_count_per_environment;
  uint64_t total_scalar_count;
} NBDispatchTokenUniforms;

/// Immutable root identity shared by NumiBrain and NumanX. The fingerprint is
/// the only opaque transaction handle accepted by nested substep records.
typedef struct NBJointTransactionToken {
  uint32_t format_version;
  uint32_t environment_identifier;
  uint64_t episode_identifier;
  uint64_t control_step_identifier;
  uint64_t parameter_version_fingerprint;
  uint64_t base_brain_generation;
  uint64_t base_physics_generation;
  uint64_t committed_timestamp_microseconds;
  uint64_t target_timestamp_microseconds;
  uint64_t shadow_generation;
  uint64_t random_counter_generation;
  uint32_t flags;
  uint32_t reserved;
  uint64_t transaction_fingerprint;
} NBJointTransactionToken;

/// One candidate physical substep. Rejected attempts retain the accepted
/// substep index, shadow generation, and random-counter generation.
typedef struct NBJointSubstepToken {
  uint64_t transaction_fingerprint;
  uint32_t substep_index;
  uint32_t attempt_index;
  uint64_t start_timestamp_microseconds;
  uint64_t duration_microseconds;
  uint64_t candidate_timestamp_microseconds;
  uint64_t shadow_generation;
  uint64_t random_counter_generation;
  uint32_t flags;
  uint32_t reserved;
  uint64_t substep_fingerprint;
} NBJointSubstepToken;

/// NumanX acceptance proof for one candidate. The physical state itself stays
/// NumanX-owned; NumiBrain receives only this content-addressed handoff.
typedef struct NBAcceptedPhysicsStateToken {
  uint64_t transaction_fingerprint;
  uint64_t substep_fingerprint;
  uint64_t physics_state_fingerprint;
  uint64_t accepted_timestamp_microseconds;
  uint64_t physics_generation;
  uint32_t environment_identifier;
  uint32_t flags;
  uint64_t reserved;
  uint64_t token_fingerprint;
} NBAcceptedPhysicsStateToken;

/// Atomic root-commit receipt. Publishing this record means both runtimes
/// accepted the same final physical token and committed timestamp.
typedef struct NBJointCommitToken {
  uint64_t transaction_fingerprint;
  uint64_t accepted_physics_token_fingerprint;
  uint64_t brain_generation;
  uint64_t physics_generation;
  uint64_t committed_timestamp_microseconds;
  uint64_t parameter_version_fingerprint;
  uint32_t environment_identifier;
  uint32_t flags;
  uint64_t commit_fingerprint;
} NBJointCommitToken;

/// Species-neutral protective output derived from accepted fast regional
/// state. A species motor adapter maps these bounded drives to muscles or
/// actuators for the following physical candidate.
typedef struct NBProtectiveCommand {
  uint32_t format_version;
  uint32_t flags;
  uint64_t timestamp_microseconds;
  uint64_t brain_generation;
  uint64_t interrupt_mask;
  float withdrawal_drive;
  float postural_stiffness;
  float motor_inhibition;
  float autonomic_arousal;
  uint32_t environment_identifier;
  uint32_t reserved;
  uint64_t command_fingerprint;
} NBProtectiveCommand;

/// One immutable species/body mapping channel. Gains map the species-neutral
/// protective command into a bounded muscle-excitation residual.
typedef struct NBMotorChannelDescriptor {
  uint32_t muscle_id;
  uint32_t flags;
  float resting_excitation;
  float withdrawal_gain;
  float brace_gain;
  float maximum_excitation;
  uint32_t reserved0;
  uint32_t reserved1;
} NBMotorChannelDescriptor;

/// Header paired with a contiguous FP32 excitation array. The output remains
/// neural control input to NumanX; it never authoritatively mutates physics.
typedef struct NBMotorOutputHeader {
  uint32_t format_version;
  uint32_t flags;
  uint64_t timestamp_microseconds;
  uint64_t brain_generation;
  uint64_t profile_fingerprint;
  uint64_t protective_command_fingerprint;
  uint32_t muscle_count;
  uint32_t environment_identifier;
  float motor_inhibition;
  float autonomic_arousal;
  uint64_t output_fingerprint;
} NBMotorOutputHeader;

/// Transaction-local GPU handoff for one NumanX physical candidate. GPU
/// addresses are ephemeral process state and are deliberately not persistent
/// checkpoint identity.
typedef struct NBNumanXMotorCandidate {
  uint32_t format_version;
  uint32_t flags;
  uint64_t transaction_fingerprint;
  uint64_t substep_fingerprint;
  uint64_t accepted_brain_timestamp_microseconds;
  uint64_t brain_generation;
  uint64_t motor_profile_fingerprint;
  uint64_t motor_output_header_gpu_address;
  uint64_t muscle_excitation_gpu_address;
  uint64_t random_counter_generation;
  uint32_t motor_output_header_byte_count;
  uint32_t muscle_excitation_byte_count;
  uint32_t muscle_count;
  uint32_t environment_identifier;
  uint64_t candidate_fingerprint;
} NBNumanXMotorCandidate;

typedef enum NBParameterComponentKind {
  NB_PARAMETER_COMPONENT_SENSORY = 1,
  NB_PARAMETER_COMPONENT_BELIEF = 2,
  NB_PARAMETER_COMPONENT_WORLD = 3,
  NB_PARAMETER_COMPONENT_ROUTE = 4,
  NB_PARAMETER_COMPONENT_MEMORY = 5,
  NB_PARAMETER_COMPONENT_VALUE = 6,
  NB_PARAMETER_COMPONENT_POLICY = 7,
  NB_PARAMETER_COMPONENT_MOTOR = 8,
  NB_PARAMETER_COMPONENT_CEREBELLAR = 9,
  NB_PARAMETER_COMPONENT_PLASTICITY = 10,
  NB_PARAMETER_COMPONENT_TISSUE_DYNAMICS = 11,
  NB_PARAMETER_COMPONENT_REGIONAL_OPERATOR = 12,
} NBParameterComponentKind;

typedef enum NBParameterElementType {
  NB_PARAMETER_ELEMENT_FP16 = 1,
  NB_PARAMETER_ELEMENT_BF16 = 2,
  NB_PARAMETER_ELEMENT_FP32 = 3,
  NB_PARAMETER_ELEMENT_INT8 = 4,
  NB_PARAMETER_ELEMENT_OPAQUE = 5,
} NBParameterElementType;

typedef enum NBSchedulerStatus {
  NB_SCHEDULER_STATUS_VALID = 0,
  NB_SCHEDULER_STATUS_INVOCATION_CAPACITY = 1,
  NB_SCHEDULER_STATUS_TIME_OVERFLOW = 2,
  NB_SCHEDULER_STATUS_EVENT_TRANSDUCTION = 3,
  NB_SCHEDULER_STATUS_PARAMETER_VERSION = 4,
  NB_SCHEDULER_STATUS_REGIONAL_PROGRAM = 5,
} NBSchedulerStatus;

typedef enum NBReceptorEventTransductionStatus {
  NB_RECEPTOR_TRANSDUCTION_STATUS_VALID = 0,
  NB_RECEPTOR_TRANSDUCTION_STATUS_EVENT_CAPACITY = 1,
  NB_RECEPTOR_TRANSDUCTION_STATUS_TIME_OVERFLOW = 2,
} NBReceptorEventTransductionStatus;

typedef enum NBReceptorEventValidation {
  NB_RECEPTOR_EVENT_VALID = 0,
  NB_RECEPTOR_EVENT_NULL = 1,
  NB_RECEPTOR_EVENT_NONFINITE = 2,
  NB_RECEPTOR_EVENT_COORDINATE_RANGE = 3,
  NB_RECEPTOR_EVENT_NEGATIVE_EXTENT = 4,
  NB_RECEPTOR_EVENT_TIME_ORDER = 5,
  NB_RECEPTOR_EVENT_LATENCY_RANGE = 6,
  NB_RECEPTOR_EVENT_DUPLICATE_IDENTIFIER = 7,
} NBReceptorEventValidation;

typedef enum NBModuleDescriptorValidation {
  NB_MODULE_DESCRIPTOR_VALID = 0,
  NB_MODULE_DESCRIPTOR_NULL = 1,
  NB_MODULE_DESCRIPTOR_ZERO_ID = 2,
  NB_MODULE_DESCRIPTOR_NONCANONICAL_ID = 3,
  NB_MODULE_DESCRIPTOR_ZERO_PERIOD = 4,
  NB_MODULE_DESCRIPTOR_ZERO_SHAPE = 5,
  NB_MODULE_DESCRIPTOR_ZERO_TIMESCALE = 6,
} NBModuleDescriptorValidation;

typedef enum NBRegionalProgramValidation {
  NB_REGIONAL_PROGRAM_VALID = 0,
  NB_REGIONAL_PROGRAM_NULL = 1,
  NB_REGIONAL_PROGRAM_COUNT_MISMATCH = 2,
  NB_REGIONAL_PROGRAM_LAYOUT_MISMATCH = 3,
  NB_REGIONAL_PROGRAM_ROUTE_ORDER = 4,
  NB_REGIONAL_PROGRAM_UNKNOWN_MODULE = 5,
  NB_REGIONAL_PROGRAM_TOKEN_RANGE = 6,
  NB_REGIONAL_PROGRAM_NONFINITE = 7,
  NB_REGIONAL_PROGRAM_DELAY_RANGE = 8,
  NB_REGIONAL_PROGRAM_HISTORY_LAYOUT = 9,
} NBRegionalProgramValidation;

typedef enum NBParameterVersionValidation {
  NB_PARAMETER_VERSION_VALID = 0,
  NB_PARAMETER_VERSION_NULL = 1,
  NB_PARAMETER_VERSION_FORMAT = 2,
  NB_PARAMETER_VERSION_EMPTY = 3,
  NB_PARAMETER_VERSION_COMPONENT_ORDER = 4,
  NB_PARAMETER_VERSION_COMPONENT_VALUE = 5,
  NB_PARAMETER_VERSION_BYTE_COUNT = 6,
  NB_PARAMETER_VERSION_IDENTITY = 7,
  NB_PARAMETER_VERSION_FINGERPRINT = 8,
} NBParameterVersionValidation;

typedef enum NBDispatchPlanValidation {
  NB_DISPATCH_PLAN_VALID = 0,
  NB_DISPATCH_PLAN_NULL = 1,
  NB_DISPATCH_PLAN_FORMAT = 2,
  NB_DISPATCH_PLAN_IDENTITY = 3,
  NB_DISPATCH_PLAN_GROUP_ORDER = 4,
  NB_DISPATCH_PLAN_ENTRY_LAYOUT = 5,
  NB_DISPATCH_PLAN_ENTRY_ORDER = 6,
  NB_DISPATCH_PLAN_ENTRY_VALUE = 7,
  NB_DISPATCH_PLAN_FINGERPRINT = 8,
} NBDispatchPlanValidation;

typedef enum NBJointTransactionValidation {
  NB_JOINT_TRANSACTION_VALID = 0,
  NB_JOINT_TRANSACTION_NULL = 1,
  NB_JOINT_TRANSACTION_FORMAT = 2,
  NB_JOINT_TRANSACTION_IDENTITY = 3,
  NB_JOINT_TRANSACTION_TIME_ORDER = 4,
  NB_JOINT_TRANSACTION_GENERATION = 5,
  NB_JOINT_TRANSACTION_FLAGS = 6,
  NB_JOINT_TRANSACTION_FINGERPRINT = 7,
  NB_JOINT_TRANSACTION_RELATION = 8,
} NBJointTransactionValidation;

typedef enum NBProtectiveCommandValidation {
  NB_PROTECTIVE_COMMAND_VALID = 0,
  NB_PROTECTIVE_COMMAND_NULL = 1,
  NB_PROTECTIVE_COMMAND_FORMAT = 2,
  NB_PROTECTIVE_COMMAND_FLAGS = 3,
  NB_PROTECTIVE_COMMAND_GENERATION = 4,
  NB_PROTECTIVE_COMMAND_NONFINITE = 5,
  NB_PROTECTIVE_COMMAND_RANGE = 6,
  NB_PROTECTIVE_COMMAND_RELATION = 7,
  NB_PROTECTIVE_COMMAND_FINGERPRINT = 8,
} NBProtectiveCommandValidation;

typedef enum NBMotorProfileValidation {
  NB_MOTOR_PROFILE_VALID = 0,
  NB_MOTOR_PROFILE_NULL = 1,
  NB_MOTOR_PROFILE_COUNT = 2,
  NB_MOTOR_PROFILE_FLAGS = 3,
  NB_MOTOR_PROFILE_NONFINITE = 4,
  NB_MOTOR_PROFILE_RANGE = 5,
  NB_MOTOR_PROFILE_RELATION = 6,
  NB_MOTOR_PROFILE_DUPLICATE = 7,
} NBMotorProfileValidation;

typedef enum NBMotorOutputValidation {
  NB_MOTOR_OUTPUT_VALID = 0,
  NB_MOTOR_OUTPUT_NULL = 1,
  NB_MOTOR_OUTPUT_FORMAT = 2,
  NB_MOTOR_OUTPUT_FLAGS = 3,
  NB_MOTOR_OUTPUT_COUNT = 4,
  NB_MOTOR_OUTPUT_GENERATION = 5,
  NB_MOTOR_OUTPUT_NONFINITE = 6,
  NB_MOTOR_OUTPUT_RANGE = 7,
  NB_MOTOR_OUTPUT_RELATION = 8,
  NB_MOTOR_OUTPUT_FINGERPRINT = 9,
} NBMotorOutputValidation;

typedef enum NBNumanXMotorCandidateValidation {
  NB_NUMANX_MOTOR_CANDIDATE_VALID = 0,
  NB_NUMANX_MOTOR_CANDIDATE_NULL = 1,
  NB_NUMANX_MOTOR_CANDIDATE_FORMAT = 2,
  NB_NUMANX_MOTOR_CANDIDATE_FLAGS = 3,
  NB_NUMANX_MOTOR_CANDIDATE_IDENTITY = 4,
  NB_NUMANX_MOTOR_CANDIDATE_GENERATION = 5,
  NB_NUMANX_MOTOR_CANDIDATE_ADDRESS = 6,
  NB_NUMANX_MOTOR_CANDIDATE_SIZE = 7,
  NB_NUMANX_MOTOR_CANDIDATE_FINGERPRINT = 8,
} NBNumanXMotorCandidateValidation;

size_t nb_brain_abi_module_descriptor_size(void);
size_t nb_brain_abi_module_clock_state_size(void);
size_t nb_brain_abi_receptor_event_size(void);
size_t nb_brain_abi_interrupt_event_size(void);
size_t nb_brain_abi_receptor_event_transduction_uniforms_size(void);
size_t nb_brain_abi_receptor_event_transduction_result_size(void);
size_t nb_brain_abi_due_invocation_size(void);
size_t nb_brain_abi_scheduler_uniforms_size(void);
size_t nb_brain_abi_scheduler_result_size(void);
size_t nb_brain_abi_regional_module_state_size(void);
size_t nb_brain_abi_regional_token_layout_size(void);
size_t nb_brain_abi_regional_route_size(void);
size_t nb_brain_abi_regional_token_parameters_size(void);
size_t nb_brain_abi_regional_program_header_size(void);
size_t nb_brain_abi_regional_route_history_state_size(void);
size_t nb_brain_abi_regional_route_runtime_state_size(void);
size_t nb_brain_abi_parameter_component_size(void);
size_t nb_brain_abi_parameter_version_binding_size(void);
size_t nb_brain_abi_cohort_environment_size(void);
size_t nb_brain_abi_dispatch_group_size(void);
size_t nb_brain_abi_dispatch_entry_size(void);
size_t nb_brain_abi_dispatch_plan_header_size(void);
size_t nb_brain_abi_dispatch_plan_result_size(void);
size_t nb_brain_abi_dispatch_work_item_size(void);
size_t nb_brain_abi_dispatch_cohort_uniforms_size(void);
size_t nb_brain_abi_dispatch_token_uniforms_size(void);
size_t nb_brain_abi_joint_transaction_token_size(void);
size_t nb_brain_abi_joint_substep_token_size(void);
size_t nb_brain_abi_accepted_physics_state_token_size(void);
size_t nb_brain_abi_joint_commit_token_size(void);
size_t nb_brain_abi_protective_command_size(void);
size_t nb_brain_abi_motor_channel_descriptor_size(void);
size_t nb_brain_abi_motor_output_header_size(void);
size_t nb_brain_abi_numanx_motor_candidate_size(void);

size_t nb_brain_abi_module_descriptor_offset_module_id(void);
size_t nb_brain_abi_module_descriptor_offset_interrupt_mask(void);
size_t nb_brain_abi_module_descriptor_offset_flags(void);

uint32_t nb_brain_abi_validate_module_descriptors(
    const NBModuleDescriptor *descriptors,
    uint32_t count
);

uint64_t nb_brain_abi_module_descriptor_fingerprint(
    const NBModuleDescriptor *descriptors,
    uint32_t count
);

uint32_t nb_brain_abi_validate_receptor_events(
    const NBReceptorEvent *events,
    uint32_t count
);

uint64_t nb_brain_abi_receptor_event_fingerprint(
    const NBReceptorEvent *events,
    uint32_t count
);

uint32_t nb_brain_abi_validate_regional_program(
    const NBModuleDescriptor *descriptors,
    const NBRegionalTokenLayout *layouts,
    uint32_t module_count,
    const NBRegionalRoute *routes,
    uint32_t route_count,
    const NBRegionalTokenParameters *parameters,
    uint32_t parameter_count,
    uint32_t history_capacity
);

uint64_t nb_brain_abi_regional_program_fingerprint(
    const NBRegionalTokenLayout *layouts,
    uint32_t module_count,
    const NBRegionalRoute *routes,
    uint32_t route_count,
    const NBRegionalTokenParameters *parameters,
    uint32_t parameter_count,
    uint32_t history_capacity
);

uint64_t nb_brain_abi_regional_program_shape_fingerprint(
    const NBRegionalTokenLayout *layouts,
    uint32_t module_count,
    const NBRegionalRoute *routes,
    uint32_t route_count,
    uint32_t parameter_count,
    uint32_t history_capacity
);

uint64_t nb_brain_abi_parameter_version_fingerprint(
    const NBParameterVersionBinding *binding,
    const NBParameterComponent *components
);

uint32_t nb_brain_abi_validate_parameter_version(
    const NBParameterVersionBinding *binding,
    const NBParameterComponent *components
);

uint64_t nb_brain_abi_cohort_environment_fingerprint(
    const NBCohortEnvironment *environments,
    uint32_t environment_count
);

uint64_t nb_brain_abi_dispatch_plan_fingerprint(
    const NBDispatchPlanHeader *header,
    const NBDispatchGroup *groups,
    const NBDispatchEntry *entries
);

uint32_t nb_brain_abi_validate_dispatch_plan(
    const NBDispatchPlanHeader *header,
    const NBDispatchGroup *groups,
    const NBDispatchEntry *entries
);

uint64_t nb_brain_abi_dispatch_work_fingerprint(
    uint64_t plan_fingerprint,
    uint64_t parameter_version_fingerprint,
    const NBDispatchWorkItem *items,
    uint32_t item_count
);

uint64_t nb_brain_abi_cohort_regional_state_fingerprint(
    uint64_t plan_fingerprint,
    uint64_t parameter_version_fingerprint,
    uint64_t schedule_fingerprint,
    const uint32_t *environment_identifiers,
    uint32_t environment_count,
    const NBRegionalModuleState *states,
    uint32_t module_count
);

uint64_t nb_brain_abi_cohort_token_state_fingerprint(
    uint64_t plan_fingerprint,
    uint64_t parameter_version_fingerprint,
    uint64_t regional_program_fingerprint,
    const uint32_t *environment_identifiers,
    uint32_t environment_count,
    const float *token_values,
    uint32_t scalar_count_per_environment
);

uint64_t nb_brain_abi_cohort_routing_state_fingerprint(
    uint64_t plan_fingerprint,
    uint64_t parameter_version_fingerprint,
    uint64_t regional_program_fingerprint,
    const uint32_t *environment_identifiers,
    uint32_t environment_count,
    const NBRegionalRouteHistoryState *history_states,
    const uint64_t *history_timestamps,
    const float *history_values,
    const NBRegionalRouteRuntimeState *runtime_states,
    uint32_t route_count,
    uint32_t history_capacity,
    uint32_t history_scalar_count
);

uint64_t nb_brain_abi_cohort_invocation_fingerprint(
    uint64_t plan_fingerprint,
    uint64_t parameter_version_fingerprint,
    const uint32_t *environment_identifiers,
    uint32_t environment_count,
    const NBDueInvocation *invocations,
    const uint32_t *invocation_counts,
    uint32_t invocation_capacity_per_environment
);

uint64_t nb_brain_abi_joint_transaction_fingerprint(
    const NBJointTransactionToken *token
);

uint32_t nb_brain_abi_validate_joint_transaction(
    const NBJointTransactionToken *token
);

uint64_t nb_brain_abi_joint_substep_fingerprint(
    const NBJointSubstepToken *token
);

uint32_t nb_brain_abi_validate_joint_substep(
    const NBJointTransactionToken *transaction,
    const NBJointSubstepToken *substep
);

uint64_t nb_brain_abi_accepted_physics_state_fingerprint(
    const NBAcceptedPhysicsStateToken *token
);

uint32_t nb_brain_abi_validate_accepted_physics_state(
    const NBJointTransactionToken *transaction,
    const NBJointSubstepToken *substep,
    const NBAcceptedPhysicsStateToken *accepted
);

uint64_t nb_brain_abi_joint_commit_fingerprint(
    const NBJointCommitToken *token
);

uint32_t nb_brain_abi_validate_joint_commit(
    const NBJointTransactionToken *transaction,
    const NBAcceptedPhysicsStateToken *accepted,
    const NBJointCommitToken *commit
);

uint64_t nb_brain_abi_protective_command_fingerprint(
    const NBProtectiveCommand *command
);

uint32_t nb_brain_abi_validate_protective_command(
    const NBProtectiveCommand *command
);

uint64_t nb_brain_abi_motor_profile_fingerprint(
    const NBMotorChannelDescriptor *channels,
    uint32_t channel_count
);

uint32_t nb_brain_abi_validate_motor_profile(
    const NBMotorChannelDescriptor *channels,
    uint32_t channel_count
);

uint64_t nb_brain_abi_motor_output_fingerprint(
    const NBMotorOutputHeader *header,
    const float *muscle_excitations
);

uint32_t nb_brain_abi_validate_motor_output(
    const NBMotorOutputHeader *header,
    const float *muscle_excitations
);

uint64_t nb_brain_abi_numanx_motor_candidate_fingerprint(
    const NBNumanXMotorCandidate *candidate
);

uint32_t nb_brain_abi_validate_numanx_motor_candidate(
    const NBJointTransactionToken *root,
    const NBJointSubstepToken *substep,
    const NBNumanXMotorCandidate *candidate
);

#ifdef __cplusplus
}
#endif

#endif
