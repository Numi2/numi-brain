// Diagnostic-only compilation of the exact kernels requested by the native
// MetalWorld initializer. It does not modify shaders or replace physics.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <cstdio>

static bool emit(NSString* prefix, NSDictionary* record) {
  NSError* error = nil;
  NSData* bytes = [NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingSortedKeys error:&error];
  if (bytes == nil) { fprintf(stderr, "diagnostic JSON error: %s\n", error.description.UTF8String); return false; }
  fprintf(stdout, "%s ", prefix.UTF8String);
  fwrite(bytes.bytes, 1, bytes.length, stdout);
  fputc('\n', stdout); fflush(stdout);
  return true;
}
int main(int argc, char** argv) {
  @autoreleasepool {
    if (argc != 3) { fprintf(stderr, "usage: numilab_pipeline_probe METALLIB KERNEL_NAMES.txt\n"); return 2; }
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) { fprintf(stderr, "no Metal device\n"); return 2; }
    emit(@"NUMILAB_DEVICE", @{
      @"name": device.name, @"registry_id": @(device.registryID),
      @"metal4": @([device supportsFamily:MTLGPUFamilyMetal4]),
      @"unified_memory": @(device.hasUnifiedMemory),
      @"max_threadgroup_memory": @(device.maxThreadgroupMemoryLength)
    });
    NSError* error = nil;
    NSString* names = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]
      encoding:NSUTF8StringEncoding error:&error];
    if (names == nil || names.length > 65536) { fprintf(stderr, "invalid kernel-name input\n"); return 2; }
    id<MTLLibrary> library = [device newLibraryWithURL:[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]] error:&error];
    if (library == nil) { fprintf(stderr, "library load failed: %s\n", error.description.UTF8String); return 2; }
    NSMutableSet<NSString*>* seen = [NSMutableSet set];
    NSUInteger failed = 0;
    for (NSString* raw in [names componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
      @autoreleasepool {
        NSString* name = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length == 0) continue;
        NSCharacterSet* allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789_"];
        if (![name hasPrefix:@"mr_"] || name.length > 256 || [name rangeOfCharacterFromSet:allowed.invertedSet].location != NSNotFound ||
            [seen containsObject:name] || seen.count >= 256) {
          fprintf(stderr, "malformed or duplicate kernel name\n"); return 2;
        }
        [seen addObject:name];
        id<MTLFunction> function = [library newFunctionWithName:name];
        NSError* pipelineError = nil;
        // Identical pipeline-creation overload to the pinned MetalWorld owner.
        id<MTLComputePipelineState> pipeline = function == nil ? nil :
          [device newComputePipelineStateWithFunction:function error:&pipelineError];
        NSMutableDictionary* record = [@{@"kernel":name, @"present":@(function != nil), @"success":@(pipeline != nil)} mutableCopy];
        if (pipeline != nil) {
          record[@"thread_execution_width"] = @(pipeline.threadExecutionWidth);
          record[@"max_threads"] = @(pipeline.maxTotalThreadsPerThreadgroup);
          record[@"static_threadgroup_memory"] = @(pipeline.staticThreadgroupMemoryLength);
        } else {
          ++failed;
          record[@"error_domain"] = pipelineError.domain ?: @"missing_function";
          record[@"error_code"] = @(pipelineError.code);
          record[@"description"] = pipelineError.description ?: @"function missing from metallib";
          record[@"user_info"] = pipelineError.userInfo.description ?: @"";
        }
        if (!emit(@"NUMILAB_PIPELINE", record)) return 2;
      }
    }
    emit(@"NUMILAB_PIPELINE_SUMMARY", @{@"requested":@(seen.count), @"failed":@(failed), @"physics_executed":@NO});
    return seen.count > 0 && failed == 0 ? 0 : 1;
  }
}
