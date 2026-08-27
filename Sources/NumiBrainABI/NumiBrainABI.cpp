#include "NumiBrainABI.h"

#include <cstddef>
#include <type_traits>

static_assert(std::is_standard_layout_v<NBModuleDescriptor>);
static_assert(sizeof(NBModuleDescriptor) == NB_MODULE_DESCRIPTOR_BYTE_COUNT);
static_assert(sizeof(NBModuleClockState) == NB_MODULE_CLOCK_STATE_BYTE_COUNT);
static_assert(sizeof(NBInterruptEvent) == NB_INTERRUPT_EVENT_BYTE_COUNT);
static_assert(sizeof(NBDueInvocation) == NB_DUE_INVOCATION_BYTE_COUNT);
static_assert(offsetof(NBModuleDescriptor, module_id) == 0);
static_assert(offsetof(NBModuleDescriptor, interrupt_mask) == 16);
static_assert(offsetof(NBModuleDescriptor, flags) == 28);

namespace {

constexpr uint64_t kFNVOffset = 0xcbf29ce484222325ULL;
constexpr uint64_t kFNVPrime = 0x100000001b3ULL;

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
