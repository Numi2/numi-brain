#include "NumiBrainABI.h"

#include <cstddef>
#include <cmath>
#include <cstring>
#include <type_traits>

static_assert(std::is_standard_layout_v<NBModuleDescriptor>);
static_assert(sizeof(NBModuleDescriptor) == NB_MODULE_DESCRIPTOR_BYTE_COUNT);
static_assert(sizeof(NBModuleClockState) == NB_MODULE_CLOCK_STATE_BYTE_COUNT);
static_assert(sizeof(NBReceptorEvent) == NB_RECEPTOR_EVENT_BYTE_COUNT);
static_assert(sizeof(NBInterruptEvent) == NB_INTERRUPT_EVENT_BYTE_COUNT);
static_assert(
    sizeof(NBReceptorEventTransductionUniforms)
    == NB_RECEPTOR_EVENT_TRANSDUCTION_UNIFORMS_BYTE_COUNT
);
static_assert(
    sizeof(NBReceptorEventTransductionResult)
    == NB_RECEPTOR_EVENT_TRANSDUCTION_RESULT_BYTE_COUNT
);
static_assert(sizeof(NBDueInvocation) == NB_DUE_INVOCATION_BYTE_COUNT);
static_assert(sizeof(NBSchedulerUniforms) == NB_SCHEDULER_UNIFORMS_BYTE_COUNT);
static_assert(sizeof(NBSchedulerResult) == NB_SCHEDULER_RESULT_BYTE_COUNT);
static_assert(sizeof(NBRegionalModuleState) == NB_REGIONAL_MODULE_STATE_BYTE_COUNT);
static_assert(sizeof(NBRegionalTokenLayout) == NB_REGIONAL_TOKEN_LAYOUT_BYTE_COUNT);
static_assert(sizeof(NBRegionalRoute) == NB_REGIONAL_ROUTE_BYTE_COUNT);
static_assert(sizeof(NBRegionalTokenParameters) == NB_REGIONAL_TOKEN_PARAMETERS_BYTE_COUNT);
static_assert(sizeof(NBRegionalProgramHeader) == NB_REGIONAL_PROGRAM_HEADER_BYTE_COUNT);
static_assert(sizeof(NBRegionalRouteHistoryState) == NB_REGIONAL_ROUTE_HISTORY_STATE_BYTE_COUNT);
static_assert(sizeof(NBRegionalRouteRuntimeState) == NB_REGIONAL_ROUTE_RUNTIME_STATE_BYTE_COUNT);
static_assert(sizeof(NBParameterComponent) == NB_PARAMETER_COMPONENT_BYTE_COUNT);
static_assert(sizeof(NBParameterVersionBinding) == NB_PARAMETER_VERSION_BINDING_BYTE_COUNT);
static_assert(sizeof(NBCohortEnvironment) == NB_COHORT_ENVIRONMENT_BYTE_COUNT);
static_assert(sizeof(NBDispatchGroup) == NB_DISPATCH_GROUP_BYTE_COUNT);
static_assert(sizeof(NBDispatchEntry) == NB_DISPATCH_ENTRY_BYTE_COUNT);
static_assert(sizeof(NBDispatchPlanHeader) == NB_DISPATCH_PLAN_HEADER_BYTE_COUNT);
static_assert(sizeof(NBDispatchPlanResult) == NB_DISPATCH_PLAN_RESULT_BYTE_COUNT);
static_assert(sizeof(NBDispatchWorkItem) == NB_DISPATCH_WORK_ITEM_BYTE_COUNT);
static_assert(sizeof(NBDispatchCohortUniforms) == NB_DISPATCH_COHORT_UNIFORMS_BYTE_COUNT);
static_assert(sizeof(NBDispatchTokenUniforms) == NB_DISPATCH_TOKEN_UNIFORMS_BYTE_COUNT);
static_assert(sizeof(NBJointTransactionToken) == NB_JOINT_TRANSACTION_TOKEN_BYTE_COUNT);
static_assert(sizeof(NBJointSubstepToken) == NB_JOINT_SUBSTEP_TOKEN_BYTE_COUNT);
static_assert(
    sizeof(NBAcceptedPhysicsStateToken)
    == NB_ACCEPTED_PHYSICS_STATE_TOKEN_BYTE_COUNT
);
static_assert(sizeof(NBJointCommitToken) == NB_JOINT_COMMIT_TOKEN_BYTE_COUNT);
static_assert(sizeof(NBProtectiveCommand) == NB_PROTECTIVE_COMMAND_BYTE_COUNT);
static_assert(
    sizeof(NBMotorChannelDescriptor) == NB_MOTOR_CHANNEL_DESCRIPTOR_BYTE_COUNT
);
static_assert(sizeof(NBMotorOutputHeader) == NB_MOTOR_OUTPUT_HEADER_BYTE_COUNT);
static_assert(sizeof(NBAutonomicCommand) == NB_AUTONOMIC_COMMAND_BYTE_COUNT);
static_assert(offsetof(NBAutonomicCommand, command) == 0);
static_assert(offsetof(NBAutonomicCommand, flags) == 12);
static_assert(
    sizeof(NBActiveSensingCommand) == NB_ACTIVE_SENSING_COMMAND_BYTE_COUNT
);
static_assert(offsetof(NBActiveSensingCommand, command) == 0);
static_assert(offsetof(NBActiveSensingCommand, kind_and_flags) == 12);
static_assert(
    sizeof(NBNumanXMotorCandidate) == NB_NUMANX_MOTOR_CANDIDATE_BYTE_COUNT
);
static_assert(
    sizeof(NBNumanXSensorChannel) == NB_NUMANX_SENSOR_CHANNEL_BYTE_COUNT
);
static_assert(
    sizeof(NBNumanXSensorPacket) == NB_NUMANX_SENSOR_PACKET_BYTE_COUNT
);
static_assert(offsetof(NBMotorChannelDescriptor, muscle_id) == 0);
static_assert(offsetof(NBMotorChannelDescriptor, resting_excitation) == 8);
static_assert(offsetof(NBMotorChannelDescriptor, maximum_excitation) == 20);
static_assert(offsetof(NBMotorChannelDescriptor, reserved0) == 24);
static_assert(offsetof(NBMotorOutputHeader, format_version) == 0);
static_assert(offsetof(NBMotorOutputHeader, timestamp_microseconds) == 8);
static_assert(offsetof(NBMotorOutputHeader, brain_generation) == 16);
static_assert(offsetof(NBMotorOutputHeader, profile_fingerprint) == 24);
static_assert(offsetof(NBMotorOutputHeader, protective_command_fingerprint) == 32);
static_assert(offsetof(NBMotorOutputHeader, muscle_count) == 40);
static_assert(offsetof(NBMotorOutputHeader, motor_inhibition) == 48);
static_assert(offsetof(NBMotorOutputHeader, actuator_command_kind) == 56);
static_assert(offsetof(NBMotorOutputHeader, output_minimum) == 64);
static_assert(offsetof(NBMotorOutputHeader, output_fingerprint) == 72);
static_assert(offsetof(NBNumanXMotorCandidate, format_version) == 0);
static_assert(offsetof(NBNumanXMotorCandidate, transaction_fingerprint) == 8);
static_assert(offsetof(NBNumanXMotorCandidate, substep_fingerprint) == 16);
static_assert(
    offsetof(NBNumanXMotorCandidate, accepted_brain_timestamp_microseconds) == 24
);
static_assert(offsetof(NBNumanXMotorCandidate, brain_generation) == 32);
static_assert(offsetof(NBNumanXMotorCandidate, motor_profile_fingerprint) == 40);
static_assert(
    offsetof(NBNumanXMotorCandidate, motor_output_header_gpu_address) == 48
);
static_assert(offsetof(NBNumanXMotorCandidate, muscle_excitation_gpu_address) == 56);
static_assert(offsetof(NBNumanXMotorCandidate, random_counter_generation) == 64);
static_assert(offsetof(NBNumanXMotorCandidate, motor_output_header_byte_count) == 72);
static_assert(offsetof(NBNumanXMotorCandidate, autonomic_command_gpu_address) == 88);
static_assert(offsetof(NBNumanXMotorCandidate, autonomic_command_byte_count) == 96);
static_assert(offsetof(NBNumanXMotorCandidate, autonomic_command_count) == 100);
static_assert(offsetof(NBNumanXMotorCandidate, active_sensing_command_gpu_address) == 104);
static_assert(offsetof(NBNumanXMotorCandidate, active_sensing_command_byte_count) == 112);
static_assert(offsetof(NBNumanXMotorCandidate, active_sensing_command_count) == 116);
static_assert(offsetof(NBNumanXMotorCandidate, actuator_command_kind) == 120);
static_assert(offsetof(NBNumanXMotorCandidate, species_template_fingerprint) == 128);
static_assert(
    offsetof(NBNumanXMotorCandidate, compiled_species_template_fingerprint) == 136
);
static_assert(offsetof(NBNumanXMotorCandidate, candidate_fingerprint) == 144);
static_assert(offsetof(NBNumanXSensorChannel, modality) == 0);
static_assert(offsetof(NBNumanXSensorChannel, gpu_address) == 8);
static_assert(
    offsetof(NBNumanXSensorChannel, receptor_timestamp_microseconds) == 16
);
static_assert(offsetof(NBNumanXSensorChannel, byte_count) == 24);
static_assert(offsetof(NBNumanXSensorChannel, latency_microseconds) == 36);
static_assert(offsetof(NBNumanXSensorChannel, validity_gpu_address) == 40);
static_assert(offsetof(NBNumanXSensorChannel, validity_byte_count) == 48);
static_assert(offsetof(NBNumanXSensorChannel, reserved) == 52);
static_assert(offsetof(NBNumanXSensorPacket, format_version) == 0);
static_assert(offsetof(NBNumanXSensorPacket, transaction_fingerprint) == 8);
static_assert(
    offsetof(NBNumanXSensorPacket, accepted_physics_token_fingerprint) == 16
);
static_assert(
    offsetof(NBNumanXSensorPacket, delivery_timestamp_microseconds) == 24
);
static_assert(offsetof(NBNumanXSensorPacket, physics_generation) == 32);
static_assert(offsetof(NBNumanXSensorPacket, environment_identifier) == 56);
static_assert(offsetof(NBNumanXSensorPacket, packet_fingerprint) == 64);
static_assert(offsetof(NBModuleDescriptor, module_id) == 0);
static_assert(offsetof(NBModuleDescriptor, interrupt_mask) == 16);
static_assert(offsetof(NBModuleDescriptor, flags) == 28);

namespace {

constexpr uint64_t kFNVOffset = 0xcbf29ce484222325ULL;
constexpr uint64_t kFNVPrime = 0x100000001b3ULL;
constexpr float kRegionalRouteSalienceGain = 0.125F;
constexpr float kRegionalRoutePersistenceBonus = 0.05F;

void mix_byte(uint64_t &hash, uint8_t byte) {
  hash ^= static_cast<uint64_t>(byte);
  hash *= kFNVPrime;
}

template <typename T>
void mix_little_endian(uint64_t &hash, T value) {
  static_assert(std::is_unsigned_v<T>);
  for (size_t byte = 0; byte < sizeof(T); ++byte) {
    mix_byte(hash, static_cast<uint8_t>(value >> (byte * 8)));
  }
}

void mix_float(uint64_t &hash, float value) {
  uint32_t bits = 0;
  std::memcpy(&bits, &value, sizeof(bits));
  mix_little_endian(hash, bits);
}

int module_index(const NBModuleDescriptor *descriptors, uint32_t count, uint16_t module_id) {
  for (uint32_t index = 0; index < count; ++index) {
    if (descriptors[index].module_id == module_id) {
      return static_cast<int>(index);
    }
  }
  return -1;
}

}  // namespace

size_t nb_brain_abi_module_descriptor_size(void) {
  return sizeof(NBModuleDescriptor);
}

size_t nb_brain_abi_module_clock_state_size(void) {
  return sizeof(NBModuleClockState);
}

size_t nb_brain_abi_receptor_event_size(void) {
  return sizeof(NBReceptorEvent);
}

size_t nb_brain_abi_interrupt_event_size(void) {
  return sizeof(NBInterruptEvent);
}

size_t nb_brain_abi_receptor_event_transduction_uniforms_size(void) {
  return sizeof(NBReceptorEventTransductionUniforms);
}

size_t nb_brain_abi_receptor_event_transduction_result_size(void) {
  return sizeof(NBReceptorEventTransductionResult);
}

size_t nb_brain_abi_due_invocation_size(void) {
  return sizeof(NBDueInvocation);
}

size_t nb_brain_abi_scheduler_uniforms_size(void) {
  return sizeof(NBSchedulerUniforms);
}

size_t nb_brain_abi_scheduler_result_size(void) {
  return sizeof(NBSchedulerResult);
}

size_t nb_brain_abi_regional_module_state_size(void) {
  return sizeof(NBRegionalModuleState);
}

size_t nb_brain_abi_regional_token_layout_size(void) {
  return sizeof(NBRegionalTokenLayout);
}

size_t nb_brain_abi_regional_route_size(void) {
  return sizeof(NBRegionalRoute);
}

size_t nb_brain_abi_regional_token_parameters_size(void) {
  return sizeof(NBRegionalTokenParameters);
}

size_t nb_brain_abi_regional_program_header_size(void) {
  return sizeof(NBRegionalProgramHeader);
}

size_t nb_brain_abi_regional_route_history_state_size(void) {
  return sizeof(NBRegionalRouteHistoryState);
}

size_t nb_brain_abi_regional_route_runtime_state_size(void) {
  return sizeof(NBRegionalRouteRuntimeState);
}

size_t nb_brain_abi_parameter_component_size(void) {
  return sizeof(NBParameterComponent);
}

size_t nb_brain_abi_parameter_version_binding_size(void) {
  return sizeof(NBParameterVersionBinding);
}

size_t nb_brain_abi_cohort_environment_size(void) {
  return sizeof(NBCohortEnvironment);
}

size_t nb_brain_abi_dispatch_group_size(void) {
  return sizeof(NBDispatchGroup);
}

size_t nb_brain_abi_dispatch_entry_size(void) {
  return sizeof(NBDispatchEntry);
}

size_t nb_brain_abi_dispatch_plan_header_size(void) {
  return sizeof(NBDispatchPlanHeader);
}

size_t nb_brain_abi_dispatch_plan_result_size(void) {
  return sizeof(NBDispatchPlanResult);
}

size_t nb_brain_abi_dispatch_work_item_size(void) {
  return sizeof(NBDispatchWorkItem);
}

size_t nb_brain_abi_dispatch_cohort_uniforms_size(void) {
  return sizeof(NBDispatchCohortUniforms);
}

size_t nb_brain_abi_dispatch_token_uniforms_size(void) {
  return sizeof(NBDispatchTokenUniforms);
}

size_t nb_brain_abi_joint_transaction_token_size(void) {
  return sizeof(NBJointTransactionToken);
}

size_t nb_brain_abi_joint_substep_token_size(void) {
  return sizeof(NBJointSubstepToken);
}

size_t nb_brain_abi_accepted_physics_state_token_size(void) {
  return sizeof(NBAcceptedPhysicsStateToken);
}

size_t nb_brain_abi_joint_commit_token_size(void) {
  return sizeof(NBJointCommitToken);
}

size_t nb_brain_abi_protective_command_size(void) {
  return sizeof(NBProtectiveCommand);
}

size_t nb_brain_abi_motor_channel_descriptor_size(void) {
  return sizeof(NBMotorChannelDescriptor);
}

size_t nb_brain_abi_motor_output_header_size(void) {
  return sizeof(NBMotorOutputHeader);
}

size_t nb_brain_abi_numanx_motor_candidate_size(void) {
  return sizeof(NBNumanXMotorCandidate);
}

size_t nb_brain_abi_numanx_sensor_channel_size(void) {
  return sizeof(NBNumanXSensorChannel);
}

size_t nb_brain_abi_numanx_sensor_packet_size(void) {
  return sizeof(NBNumanXSensorPacket);
}

size_t nb_brain_abi_module_descriptor_offset_module_id(void) {
  return offsetof(NBModuleDescriptor, module_id);
}

size_t nb_brain_abi_module_descriptor_offset_interrupt_mask(void) {
  return offsetof(NBModuleDescriptor, interrupt_mask);
}

size_t nb_brain_abi_module_descriptor_offset_flags(void) {
  return offsetof(NBModuleDescriptor, flags);
}

uint32_t nb_brain_abi_validate_module_descriptors(
    const NBModuleDescriptor *descriptors,
    uint32_t count
) {
  if (count > 0 && descriptors == nullptr) {
    return NB_MODULE_DESCRIPTOR_NULL;
  }
  uint16_t previous_id = 0;
  for (uint32_t index = 0; index < count; ++index) {
    const NBModuleDescriptor &descriptor = descriptors[index];
    if (descriptor.module_id == 0) {
      return NB_MODULE_DESCRIPTOR_ZERO_ID;
    }
    if (index > 0 && descriptor.module_id <= previous_id) {
      return NB_MODULE_DESCRIPTOR_NONCANONICAL_ID;
    }
    if (descriptor.period_microseconds == 0) {
      return NB_MODULE_DESCRIPTOR_ZERO_PERIOD;
    }
    if (descriptor.intrinsic_timescale_microseconds == 0) {
      return NB_MODULE_DESCRIPTOR_ZERO_TIMESCALE;
    }
    if (descriptor.token_count == 0 || descriptor.token_dimension == 0) {
      return NB_MODULE_DESCRIPTOR_ZERO_SHAPE;
    }
    previous_id = descriptor.module_id;
  }
  return NB_MODULE_DESCRIPTOR_VALID;
}

uint64_t nb_brain_abi_module_descriptor_fingerprint(
    const NBModuleDescriptor *descriptors,
    uint32_t count
) {
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_BRAIN_ABI_VERSION));
  mix_little_endian(hash, count);
  for (uint32_t index = 0; index < count; ++index) {
    const NBModuleDescriptor &descriptor = descriptors[index];
    mix_little_endian(hash, descriptor.module_id);
    mix_little_endian(hash, descriptor.clock_class);
    mix_little_endian(hash, descriptor.period_microseconds);
    mix_little_endian(hash, descriptor.conduction_delay_microseconds);
    mix_little_endian(hash, descriptor.intrinsic_timescale_microseconds);
    mix_little_endian(hash, descriptor.interrupt_mask);
    mix_little_endian(hash, descriptor.token_count);
    mix_little_endian(hash, descriptor.token_dimension);
    mix_little_endian(hash, descriptor.flags);
  }
  return hash;
}

uint32_t nb_brain_abi_validate_receptor_events(
    const NBReceptorEvent *events,
    uint32_t count
) {
  if (count > 0 && events == nullptr) {
    return NB_RECEPTOR_EVENT_NULL;
  }
  for (uint32_t index = 0; index < count; ++index) {
    const NBReceptorEvent &event = events[index];
    const float values[] = {
        event.center_x,
        event.center_y,
        event.radius,
        event.start_milliseconds,
        event.end_milliseconds,
        event.excitatory_drive,
        event.inhibitory_drive,
        event.noise_amplitude,
        event.magnitude,
        event.auxiliary_value,
    };
    for (float value : values) {
      if (!std::isfinite(value)) {
        return NB_RECEPTOR_EVENT_NONFINITE;
      }
    }
    if (event.center_x < 0.0F || event.center_x > 1.0F
        || event.center_y < 0.0F || event.center_y > 1.0F) {
      return NB_RECEPTOR_EVENT_COORDINATE_RANGE;
    }
    if (event.radius < 0.0F || event.noise_amplitude < 0.0F
        || event.magnitude < 0.0F) {
      return NB_RECEPTOR_EVENT_NEGATIVE_EXTENT;
    }
    if (event.end_milliseconds < event.start_milliseconds) {
      return NB_RECEPTOR_EVENT_TIME_ORDER;
    }
    if (event.conduction_latency_microseconds
        > NB_RECEPTOR_MAX_CONDUCTION_LATENCY_MICROSECONDS) {
      return NB_RECEPTOR_EVENT_LATENCY_RANGE;
    }
    for (uint32_t previous = 0; previous < index; ++previous) {
      if (events[previous].identifier == event.identifier) {
        return NB_RECEPTOR_EVENT_DUPLICATE_IDENTIFIER;
      }
    }
  }
  return NB_RECEPTOR_EVENT_VALID;
}

uint64_t nb_brain_abi_receptor_event_fingerprint(
    const NBReceptorEvent *events,
    uint32_t count
) {
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_RECEPTOR_EVENT_ABI_VERSION));
  mix_little_endian(hash, count);
  for (uint32_t index = 0; index < count; ++index) {
    const NBReceptorEvent &event = events[index];
    mix_float(hash, event.center_x);
    mix_float(hash, event.center_y);
    mix_float(hash, event.radius);
    mix_float(hash, event.start_milliseconds);
    mix_float(hash, event.end_milliseconds);
    mix_float(hash, event.excitatory_drive);
    mix_float(hash, event.inhibitory_drive);
    mix_float(hash, event.noise_amplitude);
    mix_little_endian(hash, event.identifier);
    mix_little_endian(hash, event.flags);
    mix_little_endian(hash, event.interrupt_mask);
    mix_little_endian(hash, event.conduction_latency_microseconds);
    mix_little_endian(hash, event.receptor_identifier);
    mix_float(hash, event.magnitude);
    mix_float(hash, event.auxiliary_value);
  }
  return hash;
}

uint32_t nb_brain_abi_validate_regional_program(
    const NBModuleDescriptor *descriptors,
    const NBRegionalTokenLayout *layouts,
    uint32_t module_count,
    const NBRegionalRoute *routes,
    uint32_t route_count,
    const NBRegionalTokenParameters *parameters,
    uint32_t parameter_count,
    uint32_t history_capacity
) {
  if (module_count == 0 || descriptors == nullptr || layouts == nullptr
      || parameter_count == 0 || parameters == nullptr
      || (route_count > 0 && routes == nullptr)
      || history_capacity == 0
      || history_capacity > NB_REGIONAL_ROUTE_HISTORY_CAPACITY) {
    return NB_REGIONAL_PROGRAM_NULL;
  }
  uint32_t expected_scalar_offset = 0;
  uint32_t expected_route_offset = 0;
  uint32_t expected_dense_weight_offset = 0;
  for (uint32_t index = 0; index < module_count; ++index) {
    const NBModuleDescriptor &descriptor = descriptors[index];
    const NBRegionalTokenLayout &layout = layouts[index];
    const uint64_t scalar_count = static_cast<uint64_t>(descriptor.token_count)
        * static_cast<uint64_t>(descriptor.token_dimension);
    const uint64_t dense_weight_count =
        static_cast<uint64_t>(descriptor.token_dimension)
        * static_cast<uint64_t>(descriptor.token_dimension);
    if (scalar_count > UINT32_MAX || dense_weight_count > UINT32_MAX
        || layout.module_id != descriptor.module_id
        || layout.token_count != descriptor.token_count
        || layout.token_dimension != descriptor.token_dimension
        || layout.scalar_offset != expected_scalar_offset
        || layout.parameter_offset != expected_scalar_offset
        || layout.scalar_count != scalar_count
        || layout.incoming_route_offset != expected_route_offset
        || layout.dense_weight_offset != expected_dense_weight_offset
        || layout.dense_weight_count != dense_weight_count) {
      return NB_REGIONAL_PROGRAM_LAYOUT_MISMATCH;
    }
    if (layout.incoming_route_offset > route_count
        || layout.incoming_route_count > route_count - layout.incoming_route_offset) {
      return NB_REGIONAL_PROGRAM_COUNT_MISMATCH;
    }
    for (uint32_t route_index = layout.incoming_route_offset;
         route_index < layout.incoming_route_offset + layout.incoming_route_count;
         ++route_index) {
      if (routes[route_index].receiver_module_id != descriptor.module_id) {
        return NB_REGIONAL_PROGRAM_LAYOUT_MISMATCH;
      }
    }
    uint32_t normal_route_count = 0;
    for (uint32_t route_index = layout.incoming_route_offset;
         route_index < layout.incoming_route_offset + layout.incoming_route_count;
         ++route_index) {
      if ((routes[route_index].flags & 1U) == 0U) {
        ++normal_route_count;
      }
    }
    if (layout.normal_route_budget > normal_route_count || layout.reserved != 0) {
      return NB_REGIONAL_PROGRAM_LAYOUT_MISMATCH;
    }
    expected_scalar_offset += layout.scalar_count;
    expected_route_offset += layout.incoming_route_count;
    if (layout.dense_weight_count > UINT32_MAX - expected_dense_weight_offset) {
      return NB_REGIONAL_PROGRAM_COUNT_MISMATCH;
    }
    expected_dense_weight_offset += layout.dense_weight_count;
  }
  if (expected_scalar_offset != parameter_count || expected_route_offset != route_count) {
    return NB_REGIONAL_PROGRAM_COUNT_MISMATCH;
  }
  uint16_t previous_receiver = 0;
  uint16_t previous_sender = 0;
  uint16_t previous_token = 0;
  uint32_t expected_history_value_offset = 0;
  for (uint32_t index = 0; index < route_count; ++index) {
    const NBRegionalRoute &route = routes[index];
    const bool ordered = index == 0
        || route.receiver_module_id > previous_receiver
        || (route.receiver_module_id == previous_receiver
            && (route.sender_module_id > previous_sender
                || (route.sender_module_id == previous_sender
                    && route.sender_token > previous_token)));
    if (!ordered) {
      return NB_REGIONAL_PROGRAM_ROUTE_ORDER;
    }
    const int sender_index = module_index(descriptors, module_count, route.sender_module_id);
    const int receiver_index = module_index(descriptors, module_count, route.receiver_module_id);
    if (sender_index < 0 || receiver_index < 0
        || route.sender_module_id == route.receiver_module_id) {
      return NB_REGIONAL_PROGRAM_UNKNOWN_MODULE;
    }
    if (route.sender_token >= descriptors[sender_index].token_count) {
      return NB_REGIONAL_PROGRAM_TOKEN_RANGE;
    }
    if (!std::isfinite(route.gain)) {
      return NB_REGIONAL_PROGRAM_NONFINITE;
    }
    if (route.delay_microseconds > NB_REGIONAL_MAX_ROUTE_DELAY_MICROSECONDS) {
      return NB_REGIONAL_PROGRAM_DELAY_RANGE;
    }
    const uint32_t message_dimension = descriptors[sender_index].token_dimension;
    if (route.history_value_offset != expected_history_value_offset
        || route.message_dimension != message_dimension) {
      return NB_REGIONAL_PROGRAM_HISTORY_LAYOUT;
    }
    const uint64_t next_history_value_offset =
        static_cast<uint64_t>(expected_history_value_offset)
        + static_cast<uint64_t>(message_dimension)
            * static_cast<uint64_t>(history_capacity);
    if (next_history_value_offset > UINT32_MAX) {
      return NB_REGIONAL_PROGRAM_HISTORY_LAYOUT;
    }
    expected_history_value_offset = static_cast<uint32_t>(next_history_value_offset);
    previous_receiver = route.receiver_module_id;
    previous_sender = route.sender_module_id;
    previous_token = route.sender_token;
  }
  for (uint32_t index = 0; index < parameter_count; ++index) {
    const NBRegionalTokenParameters &value = parameters[index];
    if (!std::isfinite(value.recurrent_gain)
        || !std::isfinite(value.local_gain)
        || !std::isfinite(value.route_gain)
        || !std::isfinite(value.drive_gain)
        || !std::isfinite(value.bias)
        || !std::isfinite(value.gate_bias)
        || !std::isfinite(value.gate_recurrent_gain)
        || !std::isfinite(value.gate_input_gain)) {
      return NB_REGIONAL_PROGRAM_NONFINITE;
    }
  }
  return NB_REGIONAL_PROGRAM_VALID;
}

uint64_t nb_brain_abi_regional_program_fingerprint(
    const NBRegionalTokenLayout *layouts,
    uint32_t module_count,
    const NBRegionalRoute *routes,
    uint32_t route_count,
    const NBRegionalTokenParameters *parameters,
    uint32_t parameter_count,
    uint32_t history_capacity
) {
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_BRAIN_ABI_VERSION));
  mix_little_endian(hash, module_count);
  mix_little_endian(hash, route_count);
  mix_little_endian(hash, parameter_count);
  mix_little_endian(
      hash,
      history_capacity
  );
  mix_little_endian(
      hash,
      static_cast<uint32_t>(NB_REGIONAL_MAX_ROUTE_DELAY_MICROSECONDS)
  );
  mix_little_endian(hash, static_cast<uint32_t>(NB_REGIONAL_PROGRAM_VERSION));
  mix_little_endian(
      hash,
      static_cast<uint32_t>(NB_REGIONAL_MIN_ROUTE_PERSISTENCE_MICROSECONDS)
  );
  mix_float(hash, kRegionalRouteSalienceGain);
  mix_float(hash, kRegionalRoutePersistenceBonus);
  for (uint32_t index = 0; index < module_count; ++index) {
    const NBRegionalTokenLayout &value = layouts[index];
    mix_little_endian(hash, value.scalar_offset);
    mix_little_endian(hash, value.scalar_count);
    mix_little_endian(hash, value.parameter_offset);
    mix_little_endian(hash, value.incoming_route_offset);
    mix_little_endian(hash, value.dense_weight_offset);
    mix_little_endian(hash, value.dense_weight_count);
    mix_little_endian(hash, value.module_id);
    mix_little_endian(hash, value.token_count);
    mix_little_endian(hash, value.token_dimension);
    mix_little_endian(hash, value.incoming_route_count);
    mix_little_endian(hash, value.flags);
    mix_little_endian(hash, value.normal_route_budget);
    mix_little_endian(hash, value.reserved);
  }
  for (uint32_t index = 0; index < route_count; ++index) {
    const NBRegionalRoute &value = routes[index];
    mix_little_endian(hash, value.sender_module_id);
    mix_little_endian(hash, value.receiver_module_id);
    mix_little_endian(hash, value.sender_token);
    mix_little_endian(hash, value.flags);
    mix_little_endian(hash, value.delay_microseconds);
    mix_float(hash, value.gain);
    mix_little_endian(hash, value.history_value_offset);
    mix_little_endian(hash, value.message_dimension);
  }
  for (uint32_t index = 0; index < parameter_count; ++index) {
    const NBRegionalTokenParameters &value = parameters[index];
    mix_float(hash, value.recurrent_gain);
    mix_float(hash, value.local_gain);
    mix_float(hash, value.route_gain);
    mix_float(hash, value.drive_gain);
    mix_float(hash, value.bias);
    mix_float(hash, value.gate_bias);
    mix_float(hash, value.gate_recurrent_gain);
    mix_float(hash, value.gate_input_gain);
  }
  return hash;
}

uint64_t nb_brain_abi_regional_program_shape_fingerprint(
    const NBRegionalTokenLayout *layouts,
    uint32_t module_count,
    const NBRegionalRoute *routes,
    uint32_t route_count,
    uint32_t parameter_count,
    uint32_t history_capacity
) {
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_REGIONAL_PROGRAM_VERSION));
  mix_little_endian(hash, module_count);
  mix_little_endian(hash, route_count);
  mix_little_endian(hash, parameter_count);
  mix_little_endian(
      hash,
      history_capacity
  );
  mix_little_endian(
      hash,
      static_cast<uint32_t>(NB_REGIONAL_MAX_ROUTE_DELAY_MICROSECONDS)
  );
  mix_little_endian(
      hash,
      static_cast<uint32_t>(NB_REGIONAL_MIN_ROUTE_PERSISTENCE_MICROSECONDS)
  );
  for (uint32_t index = 0; index < module_count; ++index) {
    const NBRegionalTokenLayout &value = layouts[index];
    mix_little_endian(hash, value.scalar_offset);
    mix_little_endian(hash, value.scalar_count);
    mix_little_endian(hash, value.parameter_offset);
    mix_little_endian(hash, value.incoming_route_offset);
    mix_little_endian(hash, value.dense_weight_offset);
    mix_little_endian(hash, value.dense_weight_count);
    mix_little_endian(hash, value.module_id);
    mix_little_endian(hash, value.token_count);
    mix_little_endian(hash, value.token_dimension);
    mix_little_endian(hash, value.incoming_route_count);
    mix_little_endian(hash, value.flags);
    mix_little_endian(hash, value.normal_route_budget);
    mix_little_endian(hash, value.reserved);
  }
  for (uint32_t index = 0; index < route_count; ++index) {
    const NBRegionalRoute &value = routes[index];
    mix_little_endian(hash, value.sender_module_id);
    mix_little_endian(hash, value.receiver_module_id);
    mix_little_endian(hash, value.sender_token);
    mix_little_endian(hash, value.flags);
    mix_little_endian(hash, value.delay_microseconds);
    mix_little_endian(hash, value.history_value_offset);
    mix_little_endian(hash, value.message_dimension);
  }
  return hash;
}

uint64_t nb_brain_abi_parameter_version_fingerprint(
    const NBParameterVersionBinding *binding,
    const NBParameterComponent *components
) {
  if (binding == nullptr || (binding->component_count > 0 && components == nullptr)) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, binding->format_version);
  mix_little_endian(hash, binding->component_count);
  mix_little_endian(hash, binding->version_sequence);
  mix_little_endian(hash, binding->parent_version_fingerprint);
  mix_little_endian(hash, binding->schedule_fingerprint);
  mix_little_endian(hash, binding->regional_shape_fingerprint);
  mix_little_endian(hash, binding->regional_program_fingerprint);
  mix_little_endian(hash, binding->total_parameter_bytes);
  for (uint32_t index = 0; index < binding->component_count; ++index) {
    const NBParameterComponent &component = components[index];
    mix_little_endian(hash, component.component_kind);
    mix_little_endian(hash, component.element_type);
    mix_little_endian(hash, component.flags);
    mix_little_endian(hash, component.element_count);
    mix_little_endian(hash, component.byte_count);
    mix_little_endian(hash, component.content_fingerprint);
  }
  return hash;
}

uint32_t nb_brain_abi_validate_parameter_version(
    const NBParameterVersionBinding *binding,
    const NBParameterComponent *components
) {
  if (binding == nullptr || (binding->component_count > 0 && components == nullptr)) {
    return NB_PARAMETER_VERSION_NULL;
  }
  if (binding->format_version != NB_PARAMETER_MANIFEST_VERSION) {
    return NB_PARAMETER_VERSION_FORMAT;
  }
  if (binding->component_count == 0) {
    return NB_PARAMETER_VERSION_EMPTY;
  }
  if (binding->schedule_fingerprint == 0
      || binding->regional_shape_fingerprint == 0
      || binding->regional_program_fingerprint == 0) {
    return NB_PARAMETER_VERSION_IDENTITY;
  }
  if ((binding->version_sequence == 0 && binding->parent_version_fingerprint != 0)
      || (binding->version_sequence > 0 && binding->parent_version_fingerprint == 0)) {
    return NB_PARAMETER_VERSION_IDENTITY;
  }
  uint16_t previous_kind = 0;
  uint64_t total_bytes = 0;
  bool found_regional_operator = false;
  for (uint32_t index = 0; index < binding->component_count; ++index) {
    const NBParameterComponent &component = components[index];
    if (component.component_kind == 0
        || component.component_kind > NB_PARAMETER_COMPONENT_REGIONAL_DENSE
        || (index > 0 && component.component_kind <= previous_kind)) {
      return NB_PARAMETER_VERSION_COMPONENT_ORDER;
    }
    if (component.element_type < NB_PARAMETER_ELEMENT_FP16
        || component.element_type > NB_PARAMETER_ELEMENT_OPAQUE
        || component.element_count == 0
        || component.byte_count == 0
        || component.content_fingerprint == 0) {
      return NB_PARAMETER_VERSION_COMPONENT_VALUE;
    }
    if (component.component_kind == NB_PARAMETER_COMPONENT_REGIONAL_OPERATOR
        && component.content_fingerprint != binding->regional_program_fingerprint) {
      return NB_PARAMETER_VERSION_IDENTITY;
    }
    found_regional_operator = found_regional_operator
        || component.component_kind == NB_PARAMETER_COMPONENT_REGIONAL_OPERATOR;
    if (component.byte_count > UINT64_MAX - total_bytes) {
      return NB_PARAMETER_VERSION_BYTE_COUNT;
    }
    total_bytes += component.byte_count;
    previous_kind = component.component_kind;
  }
  if (total_bytes != binding->total_parameter_bytes) {
    return NB_PARAMETER_VERSION_BYTE_COUNT;
  }
  if (!found_regional_operator) {
    return NB_PARAMETER_VERSION_IDENTITY;
  }
  if (binding->version_fingerprint == 0
      || binding->version_fingerprint
          != nb_brain_abi_parameter_version_fingerprint(binding, components)) {
    return NB_PARAMETER_VERSION_FINGERPRINT;
  }
  return NB_PARAMETER_VERSION_VALID;
}

uint64_t nb_brain_abi_cohort_environment_fingerprint(
    const NBCohortEnvironment *environments,
    uint32_t environment_count
) {
  if (environment_count > 0 && environments == nullptr) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_DISPATCH_PLAN_VERSION));
  mix_little_endian(hash, environment_count);
  for (uint32_t index = 0; index < environment_count; ++index) {
    const NBCohortEnvironment &environment = environments[index];
    mix_little_endian(hash, environment.environment_identifier);
    mix_little_endian(hash, environment.invocation_offset);
    mix_little_endian(hash, environment.invocation_count);
    mix_little_endian(hash, environment.reserved);
    mix_little_endian(hash, environment.base_generation);
    mix_little_endian(hash, environment.base_committed_time_microseconds);
    mix_little_endian(hash, environment.target_time_microseconds);
  }
  return hash;
}

uint64_t nb_brain_abi_dispatch_plan_fingerprint(
    const NBDispatchPlanHeader *header,
    const NBDispatchGroup *groups,
    const NBDispatchEntry *entries
) {
  if (header == nullptr
      || (header->group_count > 0 && groups == nullptr)
      || (header->entry_count > 0 && entries == nullptr)) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, header->schedule_fingerprint);
  mix_little_endian(hash, header->parameter_version_fingerprint);
  mix_little_endian(hash, header->cohort_fingerprint);
  mix_little_endian(hash, header->group_count);
  mix_little_endian(hash, header->entry_count);
  mix_little_endian(hash, header->plan_version);
  mix_little_endian(hash, header->flags);
  for (uint32_t index = 0; index < header->group_count; ++index) {
    const NBDispatchGroup &group = groups[index];
    mix_little_endian(hash, group.timestamp_microseconds);
    mix_little_endian(hash, group.entry_offset);
    mix_little_endian(hash, group.entry_count);
    mix_little_endian(hash, group.module_id);
    mix_little_endian(hash, group.clock_class);
    mix_little_endian(hash, group.reserved);
  }
  for (uint32_t index = 0; index < header->entry_count; ++index) {
    const NBDispatchEntry &entry = entries[index];
    mix_little_endian(hash, entry.interrupt_mask);
    mix_little_endian(hash, entry.environment_identifier);
    mix_little_endian(hash, entry.reason_flags);
  }
  return hash;
}

uint32_t nb_brain_abi_validate_dispatch_plan(
    const NBDispatchPlanHeader *header,
    const NBDispatchGroup *groups,
    const NBDispatchEntry *entries
) {
  if (header == nullptr
      || (header->group_count > 0 && groups == nullptr)
      || (header->entry_count > 0 && entries == nullptr)) {
    return NB_DISPATCH_PLAN_NULL;
  }
  if (header->plan_version != NB_DISPATCH_PLAN_VERSION || header->flags != 0) {
    return NB_DISPATCH_PLAN_FORMAT;
  }
  if (header->schedule_fingerprint == 0
      || header->parameter_version_fingerprint == 0
      || header->cohort_fingerprint == 0) {
    return NB_DISPATCH_PLAN_IDENTITY;
  }
  uint32_t expected_entry_offset = 0;
  for (uint32_t group_index = 0; group_index < header->group_count; ++group_index) {
    const NBDispatchGroup &group = groups[group_index];
    if (group.module_id == 0 || group.entry_count == 0 || group.reserved != 0) {
      return NB_DISPATCH_PLAN_ENTRY_LAYOUT;
    }
    if (group.entry_offset != expected_entry_offset
        || group.entry_offset > header->entry_count
        || group.entry_count > header->entry_count - group.entry_offset) {
      return NB_DISPATCH_PLAN_ENTRY_LAYOUT;
    }
    if (group_index > 0) {
      const NBDispatchGroup &previous = groups[group_index - 1];
      const bool ordered = group.timestamp_microseconds > previous.timestamp_microseconds
          || (group.timestamp_microseconds == previous.timestamp_microseconds
              && (group.clock_class > previous.clock_class
                  || (group.clock_class == previous.clock_class
                      && group.module_id > previous.module_id)));
      if (!ordered) {
        return NB_DISPATCH_PLAN_GROUP_ORDER;
      }
    }
    uint32_t previous_environment = 0;
    for (uint32_t entry_index = group.entry_offset;
         entry_index < group.entry_offset + group.entry_count;
         ++entry_index) {
      const NBDispatchEntry &entry = entries[entry_index];
      if (entry_index > group.entry_offset
          && entry.environment_identifier <= previous_environment) {
        return NB_DISPATCH_PLAN_ENTRY_ORDER;
      }
      if (entry.reason_flags == 0 || (entry.reason_flags & ~3U) != 0U
          || (((entry.reason_flags & 2U) != 0U) != (entry.interrupt_mask != 0))) {
        return NB_DISPATCH_PLAN_ENTRY_VALUE;
      }
      previous_environment = entry.environment_identifier;
    }
    expected_entry_offset += group.entry_count;
  }
  if (expected_entry_offset != header->entry_count
      || (header->group_count == 0 && header->entry_count != 0)) {
    return NB_DISPATCH_PLAN_ENTRY_LAYOUT;
  }
  if (header->plan_fingerprint == 0
      || header->plan_fingerprint
          != nb_brain_abi_dispatch_plan_fingerprint(header, groups, entries)) {
    return NB_DISPATCH_PLAN_FINGERPRINT;
  }
  return NB_DISPATCH_PLAN_VALID;
}

uint64_t nb_brain_abi_dispatch_work_fingerprint(
    uint64_t plan_fingerprint,
    uint64_t parameter_version_fingerprint,
    const NBDispatchWorkItem *items,
    uint32_t item_count
) {
  if (plan_fingerprint == 0 || parameter_version_fingerprint == 0
      || (item_count > 0 && items == nullptr)) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_DISPATCH_PLAN_VERSION));
  mix_little_endian(hash, plan_fingerprint);
  mix_little_endian(hash, parameter_version_fingerprint);
  mix_little_endian(hash, item_count);
  for (uint32_t index = 0; index < item_count; ++index) {
    const NBDispatchWorkItem &item = items[index];
    mix_little_endian(hash, item.timestamp_microseconds);
    mix_little_endian(hash, item.interrupt_mask);
    mix_little_endian(hash, item.environment_identifier);
    mix_little_endian(hash, item.reason_flags);
    mix_little_endian(hash, item.module_id);
    mix_little_endian(hash, item.clock_class);
    mix_little_endian(hash, item.group_index);
  }
  return hash;
}

uint64_t nb_brain_abi_cohort_regional_state_fingerprint(
    uint64_t plan_fingerprint,
    uint64_t parameter_version_fingerprint,
    uint64_t schedule_fingerprint,
    const uint32_t *environment_identifiers,
    uint32_t environment_count,
    const NBRegionalModuleState *states,
    uint32_t module_count
) {
  if (plan_fingerprint == 0 || parameter_version_fingerprint == 0
      || schedule_fingerprint == 0 || environment_count == 0 || module_count == 0
      || environment_identifiers == nullptr || states == nullptr) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_DISPATCH_PLAN_VERSION));
  mix_little_endian(hash, plan_fingerprint);
  mix_little_endian(hash, parameter_version_fingerprint);
  mix_little_endian(hash, schedule_fingerprint);
  mix_little_endian(hash, environment_count);
  mix_little_endian(hash, module_count);
  for (uint32_t environment_index = 0;
       environment_index < environment_count;
       ++environment_index) {
    mix_little_endian(hash, environment_identifiers[environment_index]);
    for (uint32_t module_index = 0; module_index < module_count; ++module_index) {
      const NBRegionalModuleState &state = states[
          static_cast<uint64_t>(environment_index) * module_count + module_index
      ];
      mix_float(hash, state.activation);
      mix_float(hash, state.integration);
      mix_float(hash, state.interrupt_salience);
      mix_float(hash, state.phase);
      mix_little_endian(hash, state.update_count);
      mix_little_endian(hash, state.interrupt_count);
      mix_little_endian(hash, state.last_update_microseconds);
    }
  }
  return hash;
}

uint64_t nb_brain_abi_cohort_token_state_fingerprint(
    uint64_t plan_fingerprint,
    uint64_t parameter_version_fingerprint,
    uint64_t regional_program_fingerprint,
    const uint32_t *environment_identifiers,
    uint32_t environment_count,
    const float *token_values,
    uint32_t scalar_count_per_environment
) {
  if (plan_fingerprint == 0 || parameter_version_fingerprint == 0
      || regional_program_fingerprint == 0 || environment_count == 0
      || scalar_count_per_environment == 0 || environment_identifiers == nullptr
      || token_values == nullptr) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_REGIONAL_PROGRAM_VERSION));
  mix_little_endian(hash, plan_fingerprint);
  mix_little_endian(hash, parameter_version_fingerprint);
  mix_little_endian(hash, regional_program_fingerprint);
  mix_little_endian(hash, environment_count);
  mix_little_endian(hash, scalar_count_per_environment);
  for (uint32_t environment_index = 0;
       environment_index < environment_count;
       ++environment_index) {
    mix_little_endian(hash, environment_identifiers[environment_index]);
    for (uint32_t scalar_index = 0;
         scalar_index < scalar_count_per_environment;
         ++scalar_index) {
      mix_float(
          hash,
          token_values[
              static_cast<uint64_t>(environment_index)
                  * scalar_count_per_environment
              + scalar_index
          ]
      );
    }
  }
  return hash;
}

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
) {
  if (plan_fingerprint == 0 || parameter_version_fingerprint == 0
      || regional_program_fingerprint == 0 || environment_count == 0
      || route_count == 0 || history_capacity == 0 || history_scalar_count == 0
      || environment_identifiers == nullptr || history_states == nullptr
      || history_timestamps == nullptr || history_values == nullptr
      || runtime_states == nullptr) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_REGIONAL_PROGRAM_VERSION));
  mix_little_endian(hash, plan_fingerprint);
  mix_little_endian(hash, parameter_version_fingerprint);
  mix_little_endian(hash, regional_program_fingerprint);
  mix_little_endian(hash, environment_count);
  mix_little_endian(hash, route_count);
  mix_little_endian(hash, history_capacity);
  mix_little_endian(hash, history_scalar_count);
  const uint64_t timestamp_count =
      static_cast<uint64_t>(route_count) * history_capacity;
  for (uint32_t environment_index = 0;
       environment_index < environment_count;
       ++environment_index) {
    mix_little_endian(hash, environment_identifiers[environment_index]);
    const uint64_t route_base =
        static_cast<uint64_t>(environment_index) * route_count;
    const uint64_t timestamp_base =
        static_cast<uint64_t>(environment_index) * timestamp_count;
    const uint64_t value_base =
        static_cast<uint64_t>(environment_index) * history_scalar_count;
    for (uint32_t route_index = 0; route_index < route_count; ++route_index) {
      const NBRegionalRouteHistoryState &history =
          history_states[route_base + route_index];
      mix_little_endian(hash, history.next_slot);
      mix_little_endian(hash, history.count);
      mix_little_endian(hash, history.latest_timestamp_microseconds);
      const NBRegionalRouteRuntimeState &runtime =
          runtime_states[route_base + route_index];
      mix_float(hash, runtime.score);
      mix_float(hash, runtime.strength);
      mix_little_endian(hash, runtime.active);
      mix_little_endian(hash, runtime.selection_count);
      mix_little_endian(hash, runtime.last_selected_timestamp_microseconds);
      mix_little_endian(hash, runtime.switch_count);
      mix_little_endian(hash, runtime.reserved);
    }
    for (uint64_t index = 0; index < timestamp_count; ++index) {
      mix_little_endian(hash, history_timestamps[timestamp_base + index]);
    }
    for (uint32_t index = 0; index < history_scalar_count; ++index) {
      mix_float(hash, history_values[value_base + index]);
    }
  }
  return hash;
}

uint64_t nb_brain_abi_cohort_invocation_fingerprint(
    uint64_t plan_fingerprint,
    uint64_t parameter_version_fingerprint,
    const uint32_t *environment_identifiers,
    uint32_t environment_count,
    const NBDueInvocation *invocations,
    const uint32_t *invocation_counts,
    uint32_t invocation_capacity_per_environment
) {
  if (plan_fingerprint == 0 || parameter_version_fingerprint == 0
      || environment_count == 0 || invocation_capacity_per_environment == 0
      || environment_identifiers == nullptr || invocations == nullptr
      || invocation_counts == nullptr) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_DISPATCH_PLAN_VERSION));
  mix_little_endian(hash, plan_fingerprint);
  mix_little_endian(hash, parameter_version_fingerprint);
  mix_little_endian(hash, environment_count);
  mix_little_endian(hash, invocation_capacity_per_environment);
  for (uint32_t environment_index = 0;
       environment_index < environment_count;
       ++environment_index) {
    const uint32_t count = invocation_counts[environment_index];
    if (count > invocation_capacity_per_environment) {
      return 0;
    }
    mix_little_endian(hash, environment_identifiers[environment_index]);
    mix_little_endian(hash, count);
    const uint64_t base =
        static_cast<uint64_t>(environment_index)
        * invocation_capacity_per_environment;
    for (uint32_t invocation_index = 0;
         invocation_index < count;
         ++invocation_index) {
      const NBDueInvocation &invocation = invocations[base + invocation_index];
      mix_little_endian(hash, invocation.timestamp_microseconds);
      mix_little_endian(hash, invocation.interrupt_mask);
      mix_little_endian(hash, invocation.environment_identifier);
      mix_little_endian(hash, invocation.module_id);
      mix_little_endian(hash, invocation.clock_class);
      mix_little_endian(hash, invocation.reason_flags);
      mix_little_endian(hash, invocation.reserved);
    }
  }
  return hash;
}

uint64_t nb_brain_abi_joint_transaction_fingerprint(
    const NBJointTransactionToken *token
) {
  if (token == nullptr) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_JOINT_TRANSACTION_VERSION));
  mix_little_endian(hash, token->format_version);
  mix_little_endian(hash, token->environment_identifier);
  mix_little_endian(hash, token->episode_identifier);
  mix_little_endian(hash, token->control_step_identifier);
  mix_little_endian(hash, token->parameter_version_fingerprint);
  mix_little_endian(hash, token->base_brain_generation);
  mix_little_endian(hash, token->base_physics_generation);
  mix_little_endian(hash, token->committed_timestamp_microseconds);
  mix_little_endian(hash, token->target_timestamp_microseconds);
  mix_little_endian(hash, token->shadow_generation);
  mix_little_endian(hash, token->random_counter_generation);
  mix_little_endian(hash, token->flags);
  mix_little_endian(hash, token->reserved);
  return hash;
}

uint32_t nb_brain_abi_validate_joint_transaction(
    const NBJointTransactionToken *token
) {
  if (token == nullptr) {
    return NB_JOINT_TRANSACTION_NULL;
  }
  if (token->format_version != NB_JOINT_TRANSACTION_VERSION) {
    return NB_JOINT_TRANSACTION_FORMAT;
  }
  if (token->parameter_version_fingerprint == 0) {
    return NB_JOINT_TRANSACTION_IDENTITY;
  }
  if (token->target_timestamp_microseconds
      <= token->committed_timestamp_microseconds) {
    return NB_JOINT_TRANSACTION_TIME_ORDER;
  }
  if (token->base_brain_generation == UINT64_MAX
      || token->shadow_generation != token->base_brain_generation + 1) {
    return NB_JOINT_TRANSACTION_GENERATION;
  }
  if (token->flags != 0 || token->reserved != 0) {
    return NB_JOINT_TRANSACTION_FLAGS;
  }
  if (token->transaction_fingerprint == 0
      || token->transaction_fingerprint
          != nb_brain_abi_joint_transaction_fingerprint(token)) {
    return NB_JOINT_TRANSACTION_FINGERPRINT;
  }
  return NB_JOINT_TRANSACTION_VALID;
}

uint64_t nb_brain_abi_joint_substep_fingerprint(
    const NBJointSubstepToken *token
) {
  if (token == nullptr) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_JOINT_TRANSACTION_VERSION));
  mix_little_endian(hash, token->transaction_fingerprint);
  mix_little_endian(hash, token->substep_index);
  mix_little_endian(hash, token->attempt_index);
  mix_little_endian(hash, token->start_timestamp_microseconds);
  mix_little_endian(hash, token->duration_microseconds);
  mix_little_endian(hash, token->candidate_timestamp_microseconds);
  mix_little_endian(hash, token->shadow_generation);
  mix_little_endian(hash, token->random_counter_generation);
  mix_little_endian(hash, token->flags);
  mix_little_endian(hash, token->reserved);
  return hash;
}

uint32_t nb_brain_abi_validate_joint_substep(
    const NBJointTransactionToken *transaction,
    const NBJointSubstepToken *substep
) {
  if (transaction == nullptr || substep == nullptr) {
    return NB_JOINT_TRANSACTION_NULL;
  }
  const uint32_t root_validation =
      nb_brain_abi_validate_joint_transaction(transaction);
  if (root_validation != NB_JOINT_TRANSACTION_VALID) {
    return root_validation;
  }
  if (substep->transaction_fingerprint != transaction->transaction_fingerprint
      || substep->shadow_generation != transaction->shadow_generation
      || substep->random_counter_generation
          != transaction->random_counter_generation) {
    return NB_JOINT_TRANSACTION_RELATION;
  }
  if (substep->duration_microseconds == 0
      || substep->start_timestamp_microseconds
          < transaction->committed_timestamp_microseconds
      || substep->start_timestamp_microseconds
          >= transaction->target_timestamp_microseconds
      || substep->duration_microseconds
          > UINT64_MAX - substep->start_timestamp_microseconds
      || substep->candidate_timestamp_microseconds
          != substep->start_timestamp_microseconds
              + substep->duration_microseconds
      || substep->candidate_timestamp_microseconds
          > transaction->target_timestamp_microseconds) {
    return NB_JOINT_TRANSACTION_TIME_ORDER;
  }
  if (substep->flags != 0 || substep->reserved != 0) {
    return NB_JOINT_TRANSACTION_FLAGS;
  }
  if (substep->substep_fingerprint == 0
      || substep->substep_fingerprint
          != nb_brain_abi_joint_substep_fingerprint(substep)) {
    return NB_JOINT_TRANSACTION_FINGERPRINT;
  }
  return NB_JOINT_TRANSACTION_VALID;
}

uint64_t nb_brain_abi_accepted_physics_state_fingerprint(
    const NBAcceptedPhysicsStateToken *token
) {
  if (token == nullptr) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_JOINT_TRANSACTION_VERSION));
  mix_little_endian(hash, token->transaction_fingerprint);
  mix_little_endian(hash, token->substep_fingerprint);
  mix_little_endian(hash, token->physics_state_fingerprint);
  mix_little_endian(hash, token->accepted_timestamp_microseconds);
  mix_little_endian(hash, token->physics_generation);
  mix_little_endian(hash, token->environment_identifier);
  mix_little_endian(hash, token->flags);
  mix_little_endian(hash, token->reserved);
  return hash;
}

uint32_t nb_brain_abi_validate_accepted_physics_state(
    const NBJointTransactionToken *transaction,
    const NBJointSubstepToken *substep,
    const NBAcceptedPhysicsStateToken *accepted
) {
  if (transaction == nullptr || substep == nullptr || accepted == nullptr) {
    return NB_JOINT_TRANSACTION_NULL;
  }
  const uint32_t substep_validation =
      nb_brain_abi_validate_joint_substep(transaction, substep);
  if (substep_validation != NB_JOINT_TRANSACTION_VALID) {
    return substep_validation;
  }
  if (accepted->transaction_fingerprint != transaction->transaction_fingerprint
      || accepted->substep_fingerprint != substep->substep_fingerprint
      || accepted->environment_identifier
          != transaction->environment_identifier) {
    return NB_JOINT_TRANSACTION_RELATION;
  }
  if (accepted->physics_state_fingerprint == 0) {
    return NB_JOINT_TRANSACTION_IDENTITY;
  }
  if (accepted->accepted_timestamp_microseconds
      != substep->candidate_timestamp_microseconds) {
    return NB_JOINT_TRANSACTION_TIME_ORDER;
  }
  const uint64_t increment = static_cast<uint64_t>(substep->substep_index) + 1;
  if (increment > UINT64_MAX - transaction->base_physics_generation
      || accepted->physics_generation
          != transaction->base_physics_generation + increment) {
    return NB_JOINT_TRANSACTION_GENERATION;
  }
  if (accepted->flags != 0 || accepted->reserved != 0) {
    return NB_JOINT_TRANSACTION_FLAGS;
  }
  if (accepted->token_fingerprint == 0
      || accepted->token_fingerprint
          != nb_brain_abi_accepted_physics_state_fingerprint(accepted)) {
    return NB_JOINT_TRANSACTION_FINGERPRINT;
  }
  if (accepted->physics_state_fingerprint == 0) {
    return NB_JOINT_TRANSACTION_IDENTITY;
  }
  return NB_JOINT_TRANSACTION_VALID;
}

uint64_t nb_brain_abi_joint_commit_fingerprint(
    const NBJointCommitToken *token
) {
  if (token == nullptr) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_JOINT_TRANSACTION_VERSION));
  mix_little_endian(hash, token->transaction_fingerprint);
  mix_little_endian(hash, token->accepted_physics_token_fingerprint);
  mix_little_endian(hash, token->brain_generation);
  mix_little_endian(hash, token->physics_generation);
  mix_little_endian(hash, token->committed_timestamp_microseconds);
  mix_little_endian(hash, token->parameter_version_fingerprint);
  mix_little_endian(hash, token->environment_identifier);
  mix_little_endian(hash, token->flags);
  return hash;
}

uint32_t nb_brain_abi_validate_joint_commit(
    const NBJointTransactionToken *transaction,
    const NBAcceptedPhysicsStateToken *accepted,
    const NBJointCommitToken *commit
) {
  if (transaction == nullptr || accepted == nullptr || commit == nullptr) {
    return NB_JOINT_TRANSACTION_NULL;
  }
  const uint32_t root_validation =
      nb_brain_abi_validate_joint_transaction(transaction);
  if (root_validation != NB_JOINT_TRANSACTION_VALID) {
    return root_validation;
  }
  if (accepted->token_fingerprint == 0
      || accepted->token_fingerprint
          != nb_brain_abi_accepted_physics_state_fingerprint(accepted)) {
    return NB_JOINT_TRANSACTION_FINGERPRINT;
  }
  if (accepted->transaction_fingerprint != transaction->transaction_fingerprint
      || accepted->environment_identifier != transaction->environment_identifier
      || commit->transaction_fingerprint != transaction->transaction_fingerprint
      || commit->accepted_physics_token_fingerprint
          != accepted->token_fingerprint
      || commit->parameter_version_fingerprint
          != transaction->parameter_version_fingerprint
      || commit->environment_identifier != transaction->environment_identifier) {
    return NB_JOINT_TRANSACTION_RELATION;
  }
  if (accepted->accepted_timestamp_microseconds
          != transaction->target_timestamp_microseconds
      || commit->committed_timestamp_microseconds
          != transaction->target_timestamp_microseconds) {
    return NB_JOINT_TRANSACTION_TIME_ORDER;
  }
  if (commit->brain_generation != transaction->shadow_generation
      || commit->physics_generation != accepted->physics_generation
      || accepted->physics_generation <= transaction->base_physics_generation) {
    return NB_JOINT_TRANSACTION_GENERATION;
  }
  if (accepted->flags != 0 || accepted->reserved != 0 || commit->flags != 0) {
    return NB_JOINT_TRANSACTION_FLAGS;
  }
  if (commit->commit_fingerprint == 0
      || commit->commit_fingerprint
          != nb_brain_abi_joint_commit_fingerprint(commit)) {
    return NB_JOINT_TRANSACTION_FINGERPRINT;
  }
  return NB_JOINT_TRANSACTION_VALID;
}

uint64_t nb_brain_abi_protective_command_fingerprint(
    const NBProtectiveCommand *command
) {
  if (command == nullptr) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_PROTECTIVE_COMMAND_VERSION));
  mix_little_endian(hash, command->format_version);
  mix_little_endian(hash, command->flags);
  mix_little_endian(hash, command->timestamp_microseconds);
  mix_little_endian(hash, command->brain_generation);
  mix_little_endian(hash, command->interrupt_mask);
  mix_float(hash, command->withdrawal_drive);
  mix_float(hash, command->postural_stiffness);
  mix_float(hash, command->motor_inhibition);
  mix_float(hash, command->autonomic_arousal);
  mix_little_endian(hash, command->environment_identifier);
  mix_little_endian(hash, command->reserved);
  return hash;
}

uint32_t nb_brain_abi_validate_protective_command(
    const NBProtectiveCommand *command
) {
  if (command == nullptr) {
    return NB_PROTECTIVE_COMMAND_NULL;
  }
  if (command->format_version != NB_PROTECTIVE_COMMAND_VERSION) {
    return NB_PROTECTIVE_COMMAND_FORMAT;
  }
  constexpr uint32_t known_flags =
      NB_PROTECTIVE_COMMAND_FLAG_VALID
      | NB_PROTECTIVE_COMMAND_FLAG_EMERGENCY_STOP
      | NB_PROTECTIVE_COMMAND_FLAG_WITHDRAWAL
      | NB_PROTECTIVE_COMMAND_FLAG_POSTURAL_BRACE
      | NB_PROTECTIVE_COMMAND_FLAG_AUTONOMIC_AROUSAL;
  if ((command->flags & NB_PROTECTIVE_COMMAND_FLAG_VALID) == 0
      || (command->flags & ~known_flags) != 0 || command->reserved != 0) {
    return NB_PROTECTIVE_COMMAND_FLAGS;
  }
  if (command->brain_generation == 0 && command->timestamp_microseconds != 0) {
    return NB_PROTECTIVE_COMMAND_GENERATION;
  }
  const float drives[] = {
      command->withdrawal_drive,
      command->postural_stiffness,
      command->motor_inhibition,
      command->autonomic_arousal,
  };
  for (float drive : drives) {
    if (!std::isfinite(drive)) {
      return NB_PROTECTIVE_COMMAND_NONFINITE;
    }
    if (drive < 0.0F || drive > 1.0F) {
      return NB_PROTECTIVE_COMMAND_RANGE;
    }
  }
  const bool has_interrupt = command->interrupt_mask != 0;
  const bool emergency =
      (command->flags & NB_PROTECTIVE_COMMAND_FLAG_EMERGENCY_STOP) != 0;
  const bool withdrawal =
      (command->flags & NB_PROTECTIVE_COMMAND_FLAG_WITHDRAWAL) != 0;
  const bool brace =
      (command->flags & NB_PROTECTIVE_COMMAND_FLAG_POSTURAL_BRACE) != 0;
  const bool arousal =
      (command->flags & NB_PROTECTIVE_COMMAND_FLAG_AUTONOMIC_AROUSAL) != 0;
  if ((!has_interrupt && (command->flags != NB_PROTECTIVE_COMMAND_FLAG_VALID
          || command->withdrawal_drive != 0.0F
          || command->postural_stiffness != 0.0F
          || command->motor_inhibition != 0.0F
          || command->autonomic_arousal != 0.0F))
      || (emergency != (command->motor_inhibition == 1.0F))
      || (withdrawal != (command->withdrawal_drive > 0.0F))
      || (brace != (command->postural_stiffness > 0.0F))
      || (arousal != (command->autonomic_arousal > 0.0F))) {
    return NB_PROTECTIVE_COMMAND_RELATION;
  }
  if (command->command_fingerprint == 0
      || command->command_fingerprint
          != nb_brain_abi_protective_command_fingerprint(command)) {
    return NB_PROTECTIVE_COMMAND_FINGERPRINT;
  }
  return NB_PROTECTIVE_COMMAND_VALID;
}

uint64_t nb_brain_abi_motor_profile_fingerprint(
    const NBMotorChannelDescriptor *channels,
    uint32_t channel_count
) {
  if (channels == nullptr || channel_count == 0) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_MOTOR_PROFILE_VERSION));
  mix_little_endian(hash, channel_count);
  for (uint32_t index = 0; index < channel_count; ++index) {
    const NBMotorChannelDescriptor &channel = channels[index];
    mix_little_endian(hash, channel.muscle_id);
    mix_little_endian(hash, channel.flags);
    mix_float(hash, channel.resting_excitation);
    mix_float(hash, channel.withdrawal_gain);
    mix_float(hash, channel.brace_gain);
    mix_float(hash, channel.maximum_excitation);
    mix_little_endian(hash, channel.reserved0);
    mix_little_endian(hash, channel.reserved1);
  }
  return hash;
}

uint32_t nb_brain_abi_validate_motor_profile(
    const NBMotorChannelDescriptor *channels,
    uint32_t channel_count
) {
  if (channels == nullptr) {
    return NB_MOTOR_PROFILE_NULL;
  }
  if (channel_count == 0) {
    return NB_MOTOR_PROFILE_COUNT;
  }
  constexpr uint32_t known_flags =
      NB_MOTOR_CHANNEL_FLAG_VALID | NB_MOTOR_CHANNEL_FLAG_WITHDRAWAL
      | NB_MOTOR_CHANNEL_FLAG_POSTURAL_BRACE;
  for (uint32_t index = 0; index < channel_count; ++index) {
    const NBMotorChannelDescriptor &channel = channels[index];
    if ((channel.flags & NB_MOTOR_CHANNEL_FLAG_VALID) == 0
        || (channel.flags & ~known_flags) != 0 || channel.reserved0 != 0
        || channel.reserved1 != 0) {
      return NB_MOTOR_PROFILE_FLAGS;
    }
    const float values[] = {
        channel.resting_excitation,
        channel.withdrawal_gain,
        channel.brace_gain,
        channel.maximum_excitation,
    };
    for (float value : values) {
      if (!std::isfinite(value)) {
        return NB_MOTOR_PROFILE_NONFINITE;
      }
      if (value < 0.0F || value > 1.0F) {
        return NB_MOTOR_PROFILE_RANGE;
      }
    }
    const bool withdrawal =
        (channel.flags & NB_MOTOR_CHANNEL_FLAG_WITHDRAWAL) != 0;
    const bool brace =
        (channel.flags & NB_MOTOR_CHANNEL_FLAG_POSTURAL_BRACE) != 0;
    if ((!withdrawal && channel.withdrawal_gain != 0.0F)
        || (!brace && channel.brace_gain != 0.0F)
        || channel.resting_excitation > channel.maximum_excitation
        || channel.maximum_excitation == 0.0F) {
      return NB_MOTOR_PROFILE_RELATION;
    }
    for (uint32_t prior = 0; prior < index; ++prior) {
      if (channels[prior].muscle_id == channel.muscle_id) {
        return NB_MOTOR_PROFILE_DUPLICATE;
      }
    }
  }
  return NB_MOTOR_PROFILE_VALID;
}

uint64_t nb_brain_abi_motor_output_fingerprint(
    const NBMotorOutputHeader *header,
    const float *muscle_excitations
) {
  if (header == nullptr || muscle_excitations == nullptr
      || header->muscle_count == 0) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_MOTOR_OUTPUT_VERSION));
  mix_little_endian(hash, header->format_version);
  mix_little_endian(hash, header->flags);
  mix_little_endian(hash, header->timestamp_microseconds);
  mix_little_endian(hash, header->brain_generation);
  mix_little_endian(hash, header->profile_fingerprint);
  mix_little_endian(hash, header->protective_command_fingerprint);
  mix_little_endian(hash, header->muscle_count);
  mix_little_endian(hash, header->environment_identifier);
  mix_float(hash, header->motor_inhibition);
  mix_float(hash, header->autonomic_arousal);
  mix_little_endian(hash, header->actuator_command_kind);
  mix_little_endian(hash, header->reserved);
  mix_float(hash, header->output_minimum);
  mix_float(hash, header->output_maximum);
  for (uint32_t index = 0; index < header->muscle_count; ++index) {
    mix_float(hash, muscle_excitations[index]);
  }
  return hash;
}

uint32_t nb_brain_abi_validate_motor_output(
    const NBMotorOutputHeader *header,
    const float *muscle_excitations
) {
  if (header == nullptr || muscle_excitations == nullptr) {
    return NB_MOTOR_OUTPUT_NULL;
  }
  if (header->format_version != NB_MOTOR_OUTPUT_VERSION) {
    return NB_MOTOR_OUTPUT_FORMAT;
  }
  constexpr uint32_t known_flags =
      NB_MOTOR_OUTPUT_FLAG_VALID | NB_MOTOR_OUTPUT_FLAG_EMERGENCY_STOP
      | NB_MOTOR_OUTPUT_FLAG_LOCALIZED_SOURCE_INHIBITION
      | NB_MOTOR_OUTPUT_FLAG_LOCALIZED_WITHDRAWAL;
  if ((header->flags & NB_MOTOR_OUTPUT_FLAG_VALID) == 0
      || (header->flags & ~known_flags) != 0) {
    return NB_MOTOR_OUTPUT_FLAGS;
  }
  if (header->muscle_count == 0 || header->profile_fingerprint == 0
      || header->protective_command_fingerprint == 0) {
    return NB_MOTOR_OUTPUT_COUNT;
  }
  if (header->brain_generation == 0 && header->timestamp_microseconds != 0) {
    return NB_MOTOR_OUTPUT_GENERATION;
  }
  if (!std::isfinite(header->motor_inhibition)
      || !std::isfinite(header->autonomic_arousal)
      || !std::isfinite(header->output_minimum)
      || !std::isfinite(header->output_maximum)) {
    return NB_MOTOR_OUTPUT_NONFINITE;
  }
  if (header->motor_inhibition < 0.0F || header->motor_inhibition > 1.0F
      || header->autonomic_arousal < 0.0F
      || header->autonomic_arousal > 1.0F
      || header->output_minimum >= header->output_maximum) {
    return NB_MOTOR_OUTPUT_RANGE;
  }
  if (header->actuator_command_kind < 1
      || header->actuator_command_kind > 7 || header->reserved != 0) {
    return NB_MOTOR_OUTPUT_COMMAND_KIND;
  }
  const bool emergency =
      (header->flags & NB_MOTOR_OUTPUT_FLAG_EMERGENCY_STOP) != 0;
  if (emergency != (header->motor_inhibition == 1.0F)) {
    return NB_MOTOR_OUTPUT_RELATION;
  }
  for (uint32_t index = 0; index < header->muscle_count; ++index) {
    const float command = muscle_excitations[index];
    if (!std::isfinite(command)) {
      return NB_MOTOR_OUTPUT_NONFINITE;
    }
    if (command < header->output_minimum || command > header->output_maximum) {
      return NB_MOTOR_OUTPUT_RANGE;
    }
  }
  if (header->output_fingerprint == 0
      || header->output_fingerprint
          != nb_brain_abi_motor_output_fingerprint(header, muscle_excitations)) {
    return NB_MOTOR_OUTPUT_FINGERPRINT;
  }
  return NB_MOTOR_OUTPUT_VALID;
}

uint64_t nb_brain_abi_numanx_motor_candidate_fingerprint(
    const NBNumanXMotorCandidate *candidate
) {
  if (candidate == nullptr) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(
      hash,
      static_cast<uint32_t>(NB_NUMANX_MOTOR_CANDIDATE_VERSION)
  );
  mix_little_endian(hash, candidate->format_version);
  mix_little_endian(hash, candidate->flags);
  mix_little_endian(hash, candidate->transaction_fingerprint);
  mix_little_endian(hash, candidate->substep_fingerprint);
  mix_little_endian(hash, candidate->accepted_brain_timestamp_microseconds);
  mix_little_endian(hash, candidate->brain_generation);
  mix_little_endian(hash, candidate->motor_profile_fingerprint);
  mix_little_endian(hash, candidate->motor_output_header_gpu_address);
  mix_little_endian(hash, candidate->muscle_excitation_gpu_address);
  mix_little_endian(hash, candidate->random_counter_generation);
  mix_little_endian(hash, candidate->motor_output_header_byte_count);
  mix_little_endian(hash, candidate->muscle_excitation_byte_count);
  mix_little_endian(hash, candidate->muscle_count);
  mix_little_endian(hash, candidate->environment_identifier);
  mix_little_endian(hash, candidate->autonomic_command_gpu_address);
  mix_little_endian(hash, candidate->autonomic_command_byte_count);
  mix_little_endian(hash, candidate->autonomic_command_count);
  mix_little_endian(hash, candidate->active_sensing_command_gpu_address);
  mix_little_endian(hash, candidate->active_sensing_command_byte_count);
  mix_little_endian(hash, candidate->active_sensing_command_count);
  mix_little_endian(hash, candidate->actuator_command_kind);
  mix_little_endian(hash, candidate->reserved);
  mix_little_endian(hash, candidate->species_template_fingerprint);
  mix_little_endian(hash, candidate->compiled_species_template_fingerprint);
  return hash;
}

uint32_t nb_brain_abi_validate_numanx_motor_candidate(
    const NBJointTransactionToken *root,
    const NBJointSubstepToken *substep,
    const NBNumanXMotorCandidate *candidate
) {
  if (root == nullptr || substep == nullptr || candidate == nullptr) {
    return NB_NUMANX_MOTOR_CANDIDATE_NULL;
  }
  if (candidate->format_version != NB_NUMANX_MOTOR_CANDIDATE_VERSION) {
    return NB_NUMANX_MOTOR_CANDIDATE_FORMAT;
  }
  constexpr uint32_t known_flags =
      NB_NUMANX_MOTOR_CANDIDATE_FLAG_VALID
      | NB_NUMANX_MOTOR_CANDIDATE_FLAG_DECISION_SHADOW;
  if ((candidate->flags & NB_NUMANX_MOTOR_CANDIDATE_FLAG_VALID) == 0
      || (candidate->flags & ~known_flags) != 0) {
    return NB_NUMANX_MOTOR_CANDIDATE_FLAGS;
  }
  if (nb_brain_abi_validate_joint_substep(root, substep)
      != NB_JOINT_TRANSACTION_VALID) {
    return NB_NUMANX_MOTOR_CANDIDATE_IDENTITY;
  }
  if (candidate->transaction_fingerprint != root->transaction_fingerprint
      || candidate->substep_fingerprint != substep->substep_fingerprint
      || candidate->accepted_brain_timestamp_microseconds
          != substep->start_timestamp_microseconds
      || candidate->random_counter_generation
          != substep->random_counter_generation
      || candidate->environment_identifier != root->environment_identifier
      || candidate->motor_profile_fingerprint == 0
      || candidate->species_template_fingerprint == 0
      || candidate->compiled_species_template_fingerprint == 0
      || candidate->actuator_command_kind < 1
      || candidate->actuator_command_kind > 7
      || candidate->reserved != 0) {
    return NB_NUMANX_MOTOR_CANDIDATE_IDENTITY;
  }
  const bool decision_shadow =
      (candidate->flags & NB_NUMANX_MOTOR_CANDIDATE_FLAG_DECISION_SHADOW) != 0;
  if (decision_shadow && substep->substep_index != 0) {
    return NB_NUMANX_MOTOR_CANDIDATE_GENERATION;
  }
  const uint64_t expected_generation = decision_shadow
      ? root->shadow_generation
      : (substep->substep_index == 0
          ? root->base_brain_generation
          : root->shadow_generation);
  if (candidate->brain_generation != expected_generation) {
    return NB_NUMANX_MOTOR_CANDIDATE_GENERATION;
  }
  if (candidate->motor_output_header_gpu_address == 0
      || candidate->muscle_excitation_gpu_address == 0
      || candidate->autonomic_command_gpu_address == 0
      || candidate->active_sensing_command_gpu_address == 0
      || candidate->motor_output_header_gpu_address % 8 != 0
      || candidate->muscle_excitation_gpu_address % 4 != 0
      || candidate->autonomic_command_gpu_address % 4 != 0
      || candidate->active_sensing_command_gpu_address % 4 != 0) {
    return NB_NUMANX_MOTOR_CANDIDATE_ADDRESS;
  }
  const uint64_t expected_excitation_bytes =
      static_cast<uint64_t>(candidate->muscle_count) * sizeof(float);
  const uint64_t expected_autonomic_bytes =
      static_cast<uint64_t>(candidate->autonomic_command_count)
        * sizeof(NBAutonomicCommand);
  const uint64_t expected_active_sensing_bytes =
      static_cast<uint64_t>(candidate->active_sensing_command_count)
        * sizeof(NBActiveSensingCommand);
  if (candidate->motor_output_header_byte_count
          != NB_MOTOR_OUTPUT_HEADER_BYTE_COUNT
      || candidate->muscle_count == 0
      || expected_excitation_bytes > UINT32_MAX
      || candidate->muscle_excitation_byte_count != expected_excitation_bytes
      || candidate->autonomic_command_count == 0
      || expected_autonomic_bytes > UINT32_MAX
      || candidate->autonomic_command_byte_count != expected_autonomic_bytes
      || expected_active_sensing_bytes > UINT32_MAX
      || candidate->active_sensing_command_byte_count
          != expected_active_sensing_bytes) {
    return NB_NUMANX_MOTOR_CANDIDATE_SIZE;
  }
  if (candidate->candidate_fingerprint == 0
      || candidate->candidate_fingerprint
          != nb_brain_abi_numanx_motor_candidate_fingerprint(candidate)) {
    return NB_NUMANX_MOTOR_CANDIDATE_FINGERPRINT;
  }
  return NB_NUMANX_MOTOR_CANDIDATE_VALID;
}

uint64_t nb_brain_abi_numanx_sensor_packet_fingerprint(
    const NBNumanXSensorPacket *packet,
    const NBNumanXSensorChannel *channels
) {
  if (packet == nullptr
      || (packet->channel_count > 0 && channels == nullptr)) {
    return 0;
  }
  uint64_t hash = kFNVOffset;
  mix_little_endian(
      hash,
      static_cast<uint32_t>(NB_NUMANX_SENSOR_PACKET_VERSION)
  );
  mix_little_endian(hash, packet->format_version);
  mix_little_endian(hash, packet->flags);
  mix_little_endian(hash, packet->transaction_fingerprint);
  mix_little_endian(hash, packet->accepted_physics_token_fingerprint);
  mix_little_endian(hash, packet->delivery_timestamp_microseconds);
  mix_little_endian(hash, packet->physics_generation);
  mix_little_endian(hash, packet->species_template_fingerprint);
  mix_little_endian(hash, packet->sensory_profile_fingerprint);
  mix_little_endian(hash, packet->environment_identifier);
  mix_little_endian(hash, packet->channel_count);
  for (uint32_t index = 0; index < packet->channel_count; ++index) {
    const NBNumanXSensorChannel &channel = channels[index];
    mix_little_endian(hash, channel.modality);
    mix_little_endian(hash, channel.flags);
    mix_little_endian(hash, channel.gpu_address);
    mix_little_endian(hash, channel.receptor_timestamp_microseconds);
    mix_little_endian(hash, channel.byte_count);
    mix_little_endian(hash, channel.receptor_count);
    mix_little_endian(hash, channel.feature_dimension);
    mix_little_endian(hash, channel.latency_microseconds);
    mix_little_endian(hash, channel.validity_gpu_address);
    mix_little_endian(hash, channel.validity_byte_count);
    mix_little_endian(hash, channel.reserved);
  }
  return hash;
}

uint32_t nb_brain_abi_validate_numanx_sensor_packet(
    const NBJointTransactionToken *root,
    const NBAcceptedPhysicsStateToken *accepted,
    const NBNumanXSensorPacket *packet,
    const NBNumanXSensorChannel *channels
) {
  if (root == nullptr || packet == nullptr || channels == nullptr) {
    return NB_NUMANX_SENSOR_PACKET_NULL;
  }
  if (packet->format_version != NB_NUMANX_SENSOR_PACKET_VERSION) {
    return NB_NUMANX_SENSOR_PACKET_FORMAT;
  }
  constexpr uint32_t known_flags = NB_NUMANX_SENSOR_PACKET_FLAG_VALID
      | NB_NUMANX_SENSOR_PACKET_FLAG_ACCEPTED_STATE;
  if ((packet->flags & NB_NUMANX_SENSOR_PACKET_FLAG_VALID) == 0
      || (packet->flags & ~known_flags) != 0) {
    return NB_NUMANX_SENSOR_PACKET_FLAGS;
  }
  if (nb_brain_abi_validate_joint_transaction(root)
          != NB_JOINT_TRANSACTION_VALID
      || packet->transaction_fingerprint != root->transaction_fingerprint
      || packet->environment_identifier != root->environment_identifier
      || packet->species_template_fingerprint == 0
      || packet->sensory_profile_fingerprint == 0) {
    return NB_NUMANX_SENSOR_PACKET_IDENTITY;
  }
  const bool is_accepted =
      (packet->flags & NB_NUMANX_SENSOR_PACKET_FLAG_ACCEPTED_STATE) != 0;
  if (is_accepted) {
    if (accepted == nullptr
        || accepted->transaction_fingerprint != root->transaction_fingerprint
        || accepted->environment_identifier != root->environment_identifier
        || accepted->accepted_timestamp_microseconds
            != root->target_timestamp_microseconds
        || accepted->token_fingerprint == 0
        || accepted->token_fingerprint
            != nb_brain_abi_accepted_physics_state_fingerprint(accepted)
        || packet->accepted_physics_token_fingerprint
            != accepted->token_fingerprint
        || packet->delivery_timestamp_microseconds
            != accepted->accepted_timestamp_microseconds) {
      return NB_NUMANX_SENSOR_PACKET_IDENTITY;
    }
    if (packet->physics_generation != accepted->physics_generation) {
      return NB_NUMANX_SENSOR_PACKET_GENERATION;
    }
  } else {
    if (accepted != nullptr
        || packet->accepted_physics_token_fingerprint != 0
        || packet->delivery_timestamp_microseconds
            != root->committed_timestamp_microseconds) {
      return NB_NUMANX_SENSOR_PACKET_IDENTITY;
    }
    if (packet->physics_generation != root->base_physics_generation) {
      return NB_NUMANX_SENSOR_PACKET_GENERATION;
    }
  }
  if (packet->channel_count == 0 || packet->channel_count > 8) {
    return NB_NUMANX_SENSOR_PACKET_CHANNEL;
  }
  uint32_t previous_modality = 0;
  for (uint32_t index = 0; index < packet->channel_count; ++index) {
    const NBNumanXSensorChannel &channel = channels[index];
    constexpr uint32_t known_channel_flags =
        NB_NUMANX_SENSOR_CHANNEL_FLAG_VALID
          | NB_NUMANX_SENSOR_CHANNEL_FLAG_HAS_VALIDITY;
    if (channel.modality < 1 || channel.modality > 8
        || channel.modality <= previous_modality
        || (channel.flags & NB_NUMANX_SENSOR_CHANNEL_FLAG_VALID) == 0
        || (channel.flags & ~known_channel_flags) != 0
        || channel.receptor_count == 0 || channel.feature_dimension == 0) {
      return NB_NUMANX_SENSOR_PACKET_CHANNEL;
    }
    if (channel.gpu_address == 0 || channel.gpu_address % sizeof(float) != 0) {
      return NB_NUMANX_SENSOR_PACKET_ADDRESS;
    }
    const uint64_t scalar_count =
        static_cast<uint64_t>(channel.receptor_count)
          * static_cast<uint64_t>(channel.feature_dimension);
    const uint64_t expected_bytes = scalar_count * sizeof(float);
    if (expected_bytes == 0 || expected_bytes > UINT32_MAX
        || channel.byte_count != expected_bytes) {
      return NB_NUMANX_SENSOR_PACKET_SIZE;
    }
    const bool has_validity =
        (channel.flags & NB_NUMANX_SENSOR_CHANNEL_FLAG_HAS_VALIDITY) != 0;
    const uint64_t expected_validity_bytes =
        static_cast<uint64_t>(channel.receptor_count) * sizeof(uint32_t);
    if (channel.reserved != 0) {
      return NB_NUMANX_SENSOR_PACKET_FLAGS;
    }
    if (has_validity
        && (channel.validity_gpu_address == 0
          || channel.validity_gpu_address % sizeof(uint32_t) != 0)) {
      return NB_NUMANX_SENSOR_PACKET_ADDRESS;
    }
    if ((has_validity
          && (expected_validity_bytes > UINT32_MAX
            || channel.validity_byte_count != expected_validity_bytes))
        || (!has_validity
          && (channel.validity_gpu_address != 0
            || channel.validity_byte_count != 0))) {
      return has_validity
        ? NB_NUMANX_SENSOR_PACKET_SIZE : NB_NUMANX_SENSOR_PACKET_FLAGS;
    }
    if (channel.receptor_timestamp_microseconds
            > packet->delivery_timestamp_microseconds
        || packet->delivery_timestamp_microseconds
              - channel.receptor_timestamp_microseconds
            != channel.latency_microseconds) {
      return NB_NUMANX_SENSOR_PACKET_LATENCY;
    }
    previous_modality = channel.modality;
  }
  if (packet->packet_fingerprint == 0
      || packet->packet_fingerprint
          != nb_brain_abi_numanx_sensor_packet_fingerprint(packet, channels)) {
    return NB_NUMANX_SENSOR_PACKET_FINGERPRINT;
  }
  return NB_NUMANX_SENSOR_PACKET_VALID;
}
