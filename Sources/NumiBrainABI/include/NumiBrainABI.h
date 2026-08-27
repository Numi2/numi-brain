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

size_t nb_brain_abi_module_descriptor_size(void);
size_t nb_brain_abi_module_clock_state_size(void);
size_t nb_brain_abi_interrupt_event_size(void);
size_t nb_brain_abi_due_invocation_size(void);
size_t nb_brain_abi_scheduler_uniforms_size(void);
size_t nb_brain_abi_scheduler_result_size(void);
size_t nb_brain_abi_regional_module_state_size(void);

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

#ifdef __cplusplus
}
#endif

#endif
