#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <cstdio>
#include <sys/sysctl.h>

int main() {
  @autoreleasepool {
    id<MTLDevice> d = MTLCreateSystemDefaultDevice();
    if (!d) return 2;
    NSMutableArray<NSString*>* families = [NSMutableArray array];
    const MTLGPUFamily apple[] = {MTLGPUFamilyApple1, MTLGPUFamilyApple2, MTLGPUFamilyApple3,
      MTLGPUFamilyApple4, MTLGPUFamilyApple5, MTLGPUFamilyApple6, MTLGPUFamilyApple7,
      MTLGPUFamilyApple8, MTLGPUFamilyApple9, MTLGPUFamilyApple10};
    for (NSUInteger i = 0; i < sizeof(apple)/sizeof(apple[0]); ++i)
      if ([d supportsFamily:apple[i]]) [families addObject:[NSString stringWithFormat:@"Apple%lu", (unsigned long)i+1]];
    char model[256] = {}; size_t length = sizeof(model);
    if (sysctlbyname("hw.model", model, &length, nullptr, 0) != 0) return 2;
    NSDictionary* record = @{
      @"device_name": d.name, @"model_identifier": [NSString stringWithUTF8String:model],
      @"os": NSProcessInfo.processInfo.operatingSystemVersionString,
      @"apple_families": families, @"metal3": @([d supportsFamily:MTLGPUFamilyMetal3]),
      @"metal4": @([d supportsFamily:MTLGPUFamilyMetal4]),
      @"mac2": @([d supportsFamily:MTLGPUFamilyMac2]), @"registry_id": @(d.registryID),
      @"unified_memory": @(d.hasUnifiedMemory), @"low_power": @(d.lowPower),
      @"removable": @(d.removable), @"headless": @(d.headless),
      @"max_threadgroup_memory_bytes": @(d.maxThreadgroupMemoryLength),
      @"max_threads_per_threadgroup": @[@(d.maxThreadsPerThreadgroup.width), @(d.maxThreadsPerThreadgroup.height), @(d.maxThreadsPerThreadgroup.depth)],
      @"max_buffer_bytes": @(d.maxBufferLength), @"recommended_working_set_bytes": @(d.recommendedMaxWorkingSetSize),
      @"current_allocated_bytes": @(d.currentAllocatedSize), @"argument_buffers_tier": @(d.argumentBuffersSupport),
      @"physical_memory_bytes": @(NSProcessInfo.processInfo.physicalMemory)
    };
    NSError* error = nil;
    NSData* json = [NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:&error];
    if (!json) { fprintf(stderr, "%s\n", error.description.UTF8String); return 2; }
    fwrite(json.bytes, 1, json.length, stdout); fputc('\n', stdout);
    return [d supportsFamily:MTLGPUFamilyMetal4] && families.count &&
      [d.name rangeOfString:@"Paravirtual" options:NSCaseInsensitiveSearch].location == NSNotFound ? 0 : 1;
  }
}
