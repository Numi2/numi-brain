#include "NumiBrainABI.h"

#include <cstddef>
#include <cmath>
#include <cstring>
#include <type_traits>

static_assert(std::is_standard_layout_v<NBModuleDescriptor>);
static_assert(sizeof(NBModuleDescriptor) == NB_MODULE_DESCRIPTOR_BYTE_COUNT);
static_assert(sizeof(NBModuleClockState) == NB_MODULE_CLOCK_STATE_BYTE_COUNT);
static_assert(sizeof(NBInterruptEvent) == NB_INTERRUPT_EVENT_BYTE_COUNT);
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

size_t nb_brain_abi_interrupt_event_size(void) {
  return sizeof(NBInterruptEvent);
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

uint32_t nb_brain_abi_validate_regional_program(
    const NBModuleDescriptor *descriptors,
    const NBRegionalTokenLayout *layouts,
    uint32_t module_count,
    const NBRegionalRoute *routes,
    uint32_t route_count,
    const NBRegionalTokenParameters *parameters,
    uint32_t parameter_count
) {
  if (module_count == 0 || descriptors == nullptr || layouts == nullptr
      || parameter_count == 0 || parameters == nullptr
      || (route_count > 0 && routes == nullptr)) {
    return NB_REGIONAL_PROGRAM_NULL;
  }
  uint32_t expected_scalar_offset = 0;
  uint32_t expected_route_offset = 0;
  for (uint32_t index = 0; index < module_count; ++index) {
    const NBModuleDescriptor &descriptor = descriptors[index];
    const NBRegionalTokenLayout &layout = layouts[index];
    const uint64_t scalar_count = static_cast<uint64_t>(descriptor.token_count)
        * static_cast<uint64_t>(descriptor.token_dimension);
    if (scalar_count > UINT32_MAX
        || layout.module_id != descriptor.module_id
        || layout.token_count != descriptor.token_count
        || layout.token_dimension != descriptor.token_dimension
        || layout.scalar_offset != expected_scalar_offset
        || layout.parameter_offset != expected_scalar_offset
        || layout.scalar_count != scalar_count
        || layout.incoming_route_offset != expected_route_offset) {
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
            * static_cast<uint64_t>(NB_REGIONAL_ROUTE_HISTORY_CAPACITY);
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
    uint32_t parameter_count
) {
  uint64_t hash = kFNVOffset;
  mix_little_endian(hash, static_cast<uint32_t>(NB_BRAIN_ABI_VERSION));
  mix_little_endian(hash, module_count);
  mix_little_endian(hash, route_count);
  mix_little_endian(hash, parameter_count);
  mix_little_endian(
      hash,
      static_cast<uint32_t>(NB_REGIONAL_ROUTE_HISTORY_CAPACITY)
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
