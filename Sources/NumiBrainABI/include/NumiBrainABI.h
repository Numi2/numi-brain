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
  NB_INTERRUPT_EVENT_BYTE_COUNT = 24,
  NB_DUE_INVOCATION_BYTE_COUNT = 32,
  NB_SCHEDULER_UNIFORMS_BYTE_COUNT = 40,
  NB_SCHEDULER_RESULT_BYTE_COUNT = 16,
  NB_REGIONAL_MODULE_STATE_BYTE_COUNT = 32,
  NB_REGIONAL_TOKEN_LAYOUT_BYTE_COUNT = 32,
  NB_REGIONAL_ROUTE_BYTE_COUNT = 24,
  NB_REGIONAL_TOKEN_PARAMETERS_BYTE_COUNT = 32,
  NB_REGIONAL_PROGRAM_HEADER_BYTE_COUNT = 48,
  NB_REGIONAL_ROUTE_HISTORY_STATE_BYTE_COUNT = 16,
  NB_REGIONAL_ROUTE_RUNTIME_STATE_BYTE_COUNT = 32,
  NB_REGIONAL_ROUTE_HISTORY_CAPACITY = 512,
  NB_REGIONAL_MAX_ROUTE_DELAY_MICROSECONDS = 5000,
  NB_REGIONAL_PROGRAM_VERSION = 2,
  NB_REGIONAL_MIN_ROUTE_PERSISTENCE_MICROSECONDS = 2000,
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

typedef struct NBInterruptEvent {
  uint64_t timestamp_microseconds;
  uint64_t interrupt_mask;
  uint32_t identifier;
  uint32_t flags;
} NBInterruptEvent;

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

typedef enum NBSchedulerStatus {
  NB_SCHEDULER_STATUS_VALID = 0,
  NB_SCHEDULER_STATUS_INVOCATION_CAPACITY = 1,
  NB_SCHEDULER_STATUS_TIME_OVERFLOW = 2,
} NBSchedulerStatus;

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

size_t nb_brain_abi_module_descriptor_size(void);
size_t nb_brain_abi_module_clock_state_size(void);
size_t nb_brain_abi_interrupt_event_size(void);
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

uint32_t nb_brain_abi_validate_regional_program(
    const NBModuleDescriptor *descriptors,
    const NBRegionalTokenLayout *layouts,
    uint32_t module_count,
    const NBRegionalRoute *routes,
    uint32_t route_count,
    const NBRegionalTokenParameters *parameters,
    uint32_t parameter_count
);

uint64_t nb_brain_abi_regional_program_fingerprint(
    const NBRegionalTokenLayout *layouts,
    uint32_t module_count,
    const NBRegionalRoute *routes,
    uint32_t route_count,
    const NBRegionalTokenParameters *parameters,
    uint32_t parameter_count
);

#ifdef __cplusplus
}
#endif

#endif
