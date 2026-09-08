// Deliberately synthetic owner: faults exercise only the production bridge ABI.
// This file never enters a production target or claims to simulate body physics.
#ifdef NUMIBRAIN_TEST_REAL_NATIVE_HEADER
#include <metalrobo/c_api.h>
#else
#include "NativeNumiLabTestABI.h"
#endif
#include <math.h>
#include <stdlib.h>
#include <string.h>

struct MRTaskRolloutHandle {
  MRTaskRolloutLayoutC layout;
  MRTaskActionBindingC bindings[2];
  int fault;
  uint64_t calls;
  uint64_t revision;
};

void* fixture_create(void) {
  MRTaskRolloutHandle* h = calloc(1, sizeof(*h));
  if (!h) return NULL;
  h->layout.environment_count=1; h->layout.nq=2; h->layout.nv=2; h->layout.action_count=2;
  h->layout.run_fingerprint=11; h->layout.world_fingerprint=12; h->layout.task_fingerprint=13;
  h->layout.action_fingerprint=14; h->layout.robot_fingerprint=15; h->layout.sensor_fingerprint=16;
  for (uint32_t i=0; i<2; ++i) {
    MRTaskActionBindingC* b=&h->bindings[i];
    b->action_index=i; b->dof_index=i; b->q_index=i; b->v_index=i;
    b->normalized_scale=0.5f; b->lower_target=-1; b->upper_target=1;
  }
  return h;
}
void fixture_destroy(void* h) { free(h); }
void fixture_fault(void* p, int fault) { ((MRTaskRolloutHandle*)p)->fault=fault; }
uint64_t fixture_calls(void* p) { return ((MRTaskRolloutHandle*)p)->calls; }
uint64_t fixture_revision(void* p) { return ((MRTaskRolloutHandle*)p)->revision; }
void fixture_mutate(void* p, int field, uint64_t value) {
  MRTaskRolloutHandle* h=p;
  switch(field) {
    case 0: h->layout.run_fingerprint=value; break;
    case 1: h->layout.nq=(uint32_t)value; break;
    case 2: h->layout.sensor_fingerprint=value; break;
    case 3: h->layout.submission_count=value; break;
    case 4: h->layout.submitted_control_steps=value; break;
    case 5: h->layout.completed_environment_steps=value; break;
    case 6: h->layout.environment_count=(uint32_t)value; break;
    case 7: h->bindings[0].normalized_scale=(float)value; break;
    case 8: h->bindings[0].flags=(uint32_t)value; break;
    case 9: h->bindings[0].reserved0=(uint32_t)value; break;
    case 10: h->bindings[0].normalized_scale=NAN; break;
    case 11: h->bindings[0].action_index=(uint32_t)value; break;
    case 12: h->layout.action_count=(uint32_t)value; break;
    case 13: h->layout.observation_fingerprint=value; break;
    case 14: h->layout.maximum_episode_steps=(uint32_t)value; break;
  }
}
MRTaskRolloutLayoutC mr_task_rollout_layout(const MRTaskRolloutHandle* h) { return h->layout; }
size_t mr_task_rollout_action_binding_count(const MRTaskRolloutHandle* h) { return h->fault==14 ? 1 : 2; }
int mr_task_rollout_copy_action_bindings(const MRTaskRolloutHandle* h, MRTaskActionBindingC* output, size_t n) {
  if (h->fault==13 || n!=2) return -9;
  memcpy(output,h->bindings,2*sizeof(*output));return 0;
}
#ifndef NUMIBRAIN_TEST_MISSING_SYMBOL
uint64_t mr_task_rollout_resident_state_fingerprint(MRTaskRolloutHandle* h) {
  if (h->fault==11) ++h->layout.submission_count;
  return h->fault==12 ? 0 : 1000+h->layout.completed_environment_steps;
}
#endif
const char* mr_last_error(void) { return "synthetic native failure after mutation"; }
int mr_task_rollout_advance(MRTaskRolloutHandle* h, const float* actions, size_t n,
  const uint32_t* resets, size_t nr, uint32_t steps, uint64_t revision, uint32_t finalPolicy,
  MRTaskRolloutAdvanceC* out) {
  if (n!=2 || !actions || resets || nr || steps!=1 || finalPolicy) return -77;
  ++h->calls; h->revision=revision;
  ++h->layout.submission_count; ++h->layout.submitted_control_steps;
  if (h->fault!=2) ++h->layout.completed_environment_steps;
  memset(out,0,sizeof(*out));out->control_step_count=1;out->successful_environment_steps=1;
  out->gpu_milliseconds=0.25;out->submission_milliseconds=0.5;
  switch(h->fault) {
    case 1: return -7;
    case 3: out->failed_environment_steps=1;break;
    case 4: out->host_requested_resets=1;break;
    case 5: out->gpu_milliseconds=NAN;break;
    case 6: out->submission_milliseconds=INFINITY;break;
    case 7: out->first_gpu_status_code=1;break;
    case 8: out->control_step_count=2;break;
    case 9: ++h->layout.sensor_fingerprint;break;
    case 10: h->bindings[0].normalized_scale+=0.125f;break;
    case 15: out->gpu_milliseconds=-1;break;
    case 16: out->successful_environment_steps=2;break;
    case 17: ++h->layout.nq;break;
  }
  return 0;
}
