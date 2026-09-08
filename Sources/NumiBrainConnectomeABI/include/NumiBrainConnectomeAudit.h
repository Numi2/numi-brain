#ifndef NUMIBRAIN_CONNECTOME_AUDIT_H
#define NUMIBRAIN_CONNECTOME_AUDIT_H
#include "NumiBrainConnectomeABI.h"
#ifdef __cplusplus
extern "C" {
#endif

/* Cold-path structural audit, not an inference or controllability certificate.
 * Distances count recurrent edges; UINT32_MAX denotes no path. Zero-length
 * paths are allowed when one node has both input and output roles. Nonzero
 * weights/gains permit a path but do not prove useful, unsaturated influence.
 * Per-channel distances are the minimum among that channel's active readouts.
 * A zero input weight/scale/sensory gain, readout weight or recurrent gain
 * removes the corresponding executable path; affine bias is not a sensor. */
typedef struct NBConnectomeAuditSummary {
  uint64_t graph_fingerprint, scratch_bytes;
  uint32_t effective_edges, active_inputs, active_readouts;
  uint32_t reachable_nodes, useful_inputs, reachable_readouts;
  uint32_t reachable_channels, maximum_finite_readout_hops;
} NBConnectomeAuditSummary;

/* Caller owns arrays of input_count, readout_count and channel_count uint32s.
 * They must be distinct from graph/input/readout/summary storage. On failure
 * summary is zero and array contents are not to be consumed. scratch budget
 * bounds the traversal vectors, excluding the graph validator's allocations.
 * Status: 0 success, 100 invalid args/projections, 101 scratch budget,
 * 102 allocation failure; 1..8 retain graph validation meanings. */
uint32_t nb_connectome_audit(const void *bytes, size_t byte_count,
  uint64_t maximum_graph_bytes, uint64_t maximum_scratch_bytes,
  const NBConnectomeInput *inputs, uint32_t input_count,
  const NBConnectomeReadout *readouts, uint32_t readout_count,
  uint32_t channel_count, uint32_t *input_hops_to_readout,
  uint32_t *readout_hops_from_input, uint32_t *channel_hops_from_input,
  NBConnectomeAuditSummary *summary);
#ifdef __cplusplus
}
#endif
#endif
