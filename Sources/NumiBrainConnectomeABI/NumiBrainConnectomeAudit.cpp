#include "NumiBrainConnectomeAudit.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>

namespace {
template<class T> T read(const unsigned char *bytes, uint64_t offset) noexcept {
  T value; std::memcpy(&value, bytes + offset, sizeof value); return value;
}
constexpr uint32_t missing = UINT32_MAX;
bool finite(float value) noexcept { return std::isfinite(value) && std::abs(value) <= 64; }
}

extern "C" uint32_t nb_connectome_audit(const void *data, size_t byte_count,
  uint64_t maximum_graph_bytes, uint64_t maximum_scratch_bytes,
  const NBConnectomeInput *inputs, uint32_t ni,
  const NBConnectomeReadout *outputs, uint32_t no, uint32_t nc,
  uint32_t *input_hops, uint32_t *output_hops, uint32_t *channel_hops,
  NBConnectomeAuditSummary *summary) {
  if (!summary) return 100;
  *summary = {};
  if (!ni || ni > 65536 || !no || no > 65536 || !nc || nc > 256 ||
      !inputs || !outputs || !input_hops || !output_hops || !channel_hops) return 100;
  NBConnectomeGraphView graph{};
  const uint32_t status = nb_connectome_validate(data, byte_count, maximum_graph_bytes, &graph);
  if (status) return status;
  const auto *bytes = static_cast<const unsigned char *>(data);
  const uint32_t n = graph.node_count, e = graph.edge_count;
  const uint64_t scratch = (uint64_t(n)*5 + 1 + uint64_t(e))*sizeof(uint32_t);
  if (scratch > maximum_scratch_bytes) return 101;
  auto node = [&](uint32_t i) { return read<NBConnectomeNode>(bytes, graph.nodes_offset + uint64_t(i)*48); };
  auto offset = [&](uint32_t i) { return read<uint32_t>(bytes, graph.offsets_offset + uint64_t(i)*4); };
  auto source = [&](uint32_t k) { return read<uint32_t>(bytes, graph.sources_offset + uint64_t(k)*4); };
  auto weight = [&](uint32_t k) { return read<float>(bytes, graph.weights_offset + uint64_t(k)*4); };
  auto input_active = [&](uint32_t k) {
    const auto &x = inputs[k];
    return x.weight != 0 && x.scale != 0 && node(x.node).sensory_gain != 0;
  };
  for (uint32_t k=0; k<ni; ++k) {
    const auto &x=inputs[k];
    if (x.node>=n || x.reserved || !finite(x.weight) || !finite(x.scale) ||
        !finite(x.bias) || !finite(x.clip) || x.clip<=0 || !(node(x.node).flags & 17u)) return 100;
  }
  for (uint32_t k=0; k<no; ++k) {
    const auto &x=outputs[k];
    if (x.node>=n || x.channel>=nc || x.reserved || !finite(x.weight) ||
        !(node(x.node).flags & 10u)) return 100;
  }
  try {
    // A single transpose is reused by a multi-source forward BFS. Reverse
    // traversal uses the original incoming CSR; neither traversal recurses.
    std::vector<uint32_t> out_offsets(uint64_t(n)+1, 0), targets(e), cursor(n);
    std::vector<uint32_t> forward(n, missing), backward(n, missing), queue(n);
    uint32_t effective=0;
    for (uint32_t dst=0; dst<n; ++dst) {
      if (node(dst).recurrent_gain == 0) continue;
      for (uint32_t k=offset(dst); k<offset(dst+1); ++k) if (weight(k)!=0) {
        ++out_offsets[source(k)+1]; ++effective;
      }
    }
    for (uint32_t i=0; i<n; ++i) {
      out_offsets[i+1] += out_offsets[i]; cursor[i]=out_offsets[i];
    }
    for (uint32_t dst=0; dst<n; ++dst) {
      if (node(dst).recurrent_gain == 0) continue;
      for (uint32_t k=offset(dst); k<offset(dst+1); ++k) if (weight(k)!=0)
        targets[cursor[source(k)]++]=dst;
    }
    NBConnectomeAuditSummary result{};
    result.graph_fingerprint=graph.fingerprint; result.scratch_bytes=scratch;
    result.effective_edges=effective;
    uint32_t head=0, tail=0;
    for (uint32_t k=0; k<ni; ++k) if (input_active(k)) {
      ++result.active_inputs;
      const uint32_t i=inputs[k].node;
      if (forward[i]==missing) { forward[i]=0; queue[tail++]=i; }
    }
    while (head<tail) {
      const uint32_t i=queue[head++];
      for (uint32_t k=out_offsets[i]; k<out_offsets[i+1]; ++k) {
        const uint32_t dst=targets[k];
        if (forward[dst]==missing) { forward[dst]=forward[i]+1; queue[tail++]=dst; }
      }
    }
    result.reachable_nodes=tail;
    head=tail=0;
    for (uint32_t k=0; k<no; ++k) if (outputs[k].weight != 0) {
      ++result.active_readouts;
      const uint32_t i=outputs[k].node;
      if (backward[i]==missing) { backward[i]=0; queue[tail++]=i; }
    }
    while (head<tail) {
      const uint32_t dst=queue[head++];
      if (node(dst).recurrent_gain == 0) continue;
      for (uint32_t k=offset(dst); k<offset(dst+1); ++k) if (weight(k)!=0) {
        const uint32_t src=source(k);
        if (backward[src]==missing) { backward[src]=backward[dst]+1; queue[tail++]=src; }
      }
    }
    std::fill_n(channel_hops,nc,missing);
    for (uint32_t k=0; k<ni; ++k) {
      input_hops[k]=input_active(k) ? backward[inputs[k].node] : missing;
      result.useful_inputs += input_hops[k]!=missing;
    }
    for (uint32_t k=0; k<no; ++k) {
      output_hops[k]=outputs[k].weight!=0 ? forward[outputs[k].node] : missing;
      if (output_hops[k]!=missing) {
        ++result.reachable_readouts;
        result.maximum_finite_readout_hops=std::max(result.maximum_finite_readout_hops,output_hops[k]);
        auto &hops=channel_hops[outputs[k].channel]; hops=std::min(hops,output_hops[k]);
      }
    }
    for (uint32_t k=0; k<nc; ++k) result.reachable_channels += channel_hops[k]!=missing;
    *summary=result;
    return 0;
  } catch (...) { return 102; }
}
