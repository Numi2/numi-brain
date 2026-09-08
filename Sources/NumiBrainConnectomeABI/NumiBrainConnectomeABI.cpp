#include "NumiBrainConnectomeABI.h"
#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstring>
#include <limits>
#include <unordered_set>

namespace {
constexpr uint64_t offsetBasis = 14695981039346656037ull;
constexpr uint64_t prime = 1099511628211ull;
struct Hash {
  uint64_t h = offsetBasis;
  void bytes(const void *p, size_t n) noexcept {
    const auto *b = static_cast<const unsigned char *>(p);
    for (size_t i = 0; i < n; ++i) { h ^= b[i]; h *= prime; }
  }
  template<class T> void scalar(T v) noexcept { bytes(&v, sizeof v); }
  uint64_t value() const noexcept { return h ? h : 1; }
};
template<class T> T read(const unsigned char *b, uint64_t o) noexcept {
  T v; std::memcpy(&v, b + o, sizeof v); return v;
}
bool bounded(float x, float limit = 64) noexcept {
  return std::isfinite(x) && std::abs(x) <= limit;
}
}
static_assert(sizeof(NBConnectomeNode) == 48);
static_assert(sizeof(NBConnectomeInput) == 32);
static_assert(sizeof(NBConnectomeReadout) == 16);
static_assert(sizeof(NBConnectomeDispatch) == 48);

extern "C" const char *nb_connectome_status_message(uint32_t s) {
  switch (s) {
    case 0: return "valid";
    case 1: return "missing, oversized or truncated graph";
    case 2: return "unsupported NUMICNS1 header, flags or byte order";
    case 3: return "overlapping, unaligned or out-of-range graph section";
    case 4: return "invalid, duplicate or non-finite node";
    case 5: return "invalid CSR offsets, source indices or weights";
    case 6: return "invalid label offsets";
    case 7: return "graph fingerprint mismatch";
    default: return "graph validation resource failure";
  }
}

extern "C" uint32_t nb_connectome_validate(const void *data, size_t size,
    uint64_t budget, NBConnectomeGraphView *out) {
  if (!out) return 1;
  *out = {};
  if (!data || size < 256 || size > budget) return 1;
  if constexpr (std::endian::native != std::endian::little) return 2;
  const auto *b = static_cast<const unsigned char *>(data);
  if (std::memcmp(b, "NUMICNS1", 8) || read<uint32_t>(b,8) != 256 ||
      read<uint32_t>(b,12) != 1 || read<uint32_t>(b,16) > 1 ||
      read<uint32_t>(b,20) != 0) return 2;
  std::array<uint64_t,29> q{};
  std::memcpy(q.data(), b + 24, sizeof q);
  if (!q[0] || q[0] >= UINT32_MAX || q[1] >= UINT32_MAX ||
      !q[2] || !q[3] || q[13] != size ||
      std::any_of(q.begin()+14,q.end(),[](auto v){return v != 0;})) return 2;
  const uint64_t n=q[0], e=q[1];
  const std::array<uint64_t,7> starts{q[4],q[5],q[6],q[7],q[8],q[9],q[11]};
  const std::array<uint64_t,7> lengths{n*8,n*48,(n+1)*4,e*4,e*4,q[10],q[12]};
  uint64_t end=256;
  for (size_t i=0;i<starts.size();++i) {
    if (starts[i] < end || starts[i]%64 || starts[i]>size ||
        lengths[i]>size-starts[i]) return 3;
    // Padding is outside the interchange hash. Demand its canonical value.
    for (uint64_t j=end;j<starts[i];++j) if (b[j]) return 3;
    end=starts[i]+lengths[i];
  }
  if (end != size) return 3;
  try {
    std::unordered_set<uint64_t> ids;
    ids.reserve(static_cast<size_t>(n));
    for (uint64_t i=0;i<n;++i) {
      const uint64_t id=read<uint64_t>(b,q[4]+i*8);
      const auto node=read<NBConnectomeNode>(b,q[5]+i*48);
      if (!id || !ids.insert(id).second ||
          node.identity_low != uint32_t(id) || node.identity_high != uint32_t(id>>32) ||
          !(node.alpha>0 && node.alpha<=1) || !bounded(node.bias) ||
          !bounded(node.recurrent_gain) || !bounded(node.sensory_gain) ||
          !(node.output_gain>0) || !bounded(node.output_gain) ||
          !bounded(node.legacy_clip) || !bounded(node.homeostatic_target) ||
          node.homeostatic_target != 0 || node.reserved != 0 || (node.flags & ~127u)) return 4;
    }
  } catch (...) { return 8; }
  if (read<uint32_t>(b,q[6])!=0 || read<uint32_t>(b,q[6]+n*4)!=e) return 5;
  for (uint64_t i=0;i<n;++i) {
    const uint32_t begin=read<uint32_t>(b,q[6]+i*4);
    const uint32_t stop=read<uint32_t>(b,q[6]+(i+1)*4);
    if (begin>stop || stop>e) return 5;
    double mass=0;
    uint32_t previous=0;
    for (uint32_t k=begin;k<stop;++k) {
      const auto source=read<uint32_t>(b,q[7]+uint64_t(k)*4);
      const auto weight=read<float>(b,q[8]+uint64_t(k)*4);
      if (source>=n || (k>begin && source<=previous) || !std::isfinite(weight)) return 5;
      previous=source;
      mass+=std::abs(double(weight));
    }
    // This rate backend uses bounded activity. Reject an unbounded accumulator.
    if (mass>1024) return 5;
  }
  const uint64_t labelTable=(n+1)*4;
  if (q[10]<labelTable || read<uint32_t>(b,q[9])!=0 ||
      read<uint32_t>(b,q[9]+n*4)!=q[10]-labelTable) return 6;
  Hash h;
  h.scalar(uint32_t(1)); h.scalar(read<uint32_t>(b,16)); h.scalar(q[3]);
  h.scalar(n); h.scalar(e);
  for (size_t i=0;i<5;++i) h.bytes(b+starts[i],static_cast<size_t>(lengths[i]));
  for (uint64_t i=0;i<n;++i) {
    const auto a=read<uint32_t>(b,q[9]+i*4), z=read<uint32_t>(b,q[9]+(i+1)*4);
    if (z<a || z>q[10]-labelTable) return 6;
    h.scalar(uint64_t(z-a)); h.bytes(b+q[9]+labelTable+a,z-a);
  }
  h.scalar(q[12]); h.bytes(b+q[11],static_cast<size_t>(q[12]));
  if (h.value()!=q[2]) return 7;
  *out={q[2],q[3],q[4],q[5],q[6],q[7],q[8],q[9],q[10],q[11],q[12],
        uint32_t(n),uint32_t(e),read<uint32_t>(b,16),0};
  return 0;
}

extern "C" uint64_t nb_connectome_binding_fingerprint(uint64_t graph,
  uint64_t species, uint64_t sensory, uint64_t version, uint32_t nodes,
  uint32_t scalars, uint32_t receptors, uint32_t channels, uint32_t nominal,
  uint32_t integration, const NBConnectomeInput *inputs, uint32_t ni,
  const NBConnectomeReadout *outputs, uint32_t no) {
  if constexpr (std::endian::native != std::endian::little) return 0;
  if (!graph || !species || !sensory || !version || !nodes || !scalars || !receptors ||
      !channels || channels>256 || !nominal || !integration || integration>nominal ||
      !ni || ni>65536 || !no || no>65536 || !inputs || !outputs) return 0;
  Hash h;
  h.scalar(uint64_t(0x4e42434e53000001ull));
  for (auto v:{graph,species,sensory,version}) h.scalar(v);
  for (auto v:{nodes,scalars,receptors,channels,nominal,integration,ni,no}) h.scalar(v);
  for (uint32_t i=0;i<ni;++i) {
    const auto &x=inputs[i];
    if (x.node>=nodes || x.scalar>=scalars || x.receptor>=receptors || x.reserved ||
        !bounded(x.weight) || !bounded(x.scale) || !bounded(x.bias) ||
        !(x.clip>0) || !bounded(x.clip) || (i && x.node<inputs[i-1].node)) return 0;
    h.bytes(&x,sizeof x);
  }
  std::array<bool,256> covered{};
  for (uint32_t i=0;i<no;++i) {
    const auto &x=outputs[i];
    if (x.node>=nodes || x.channel>=channels || x.reserved || !bounded(x.weight) ||
        (i && x.channel<outputs[i-1].channel)) return 0;
    covered[x.channel]=true;
    h.bytes(&x,sizeof x);
  }
  for (uint32_t i=0;i<channels;++i) if (!covered[i]) return 0;
  return h.value();
}

extern "C" uint64_t nb_connectome_decoder_fingerprint(uint64_t graph,
    uint64_t topology, uint64_t species, uint32_t kind, uint32_t channels,
    uint32_t actuators, const float *weights, uint32_t nw,
    const float *biases, uint32_t nb, float limit) {
  if constexpr (std::endian::native != std::endian::little) return 0;
  if (!graph || !topology || !species || kind < 1 || kind > 7 || !channels ||
      channels > 256 || !actuators || actuators > 4096 ||
      uint64_t(channels)*actuators != nw || nb != actuators ||
      !weights || !biases || !(limit > 0) || !bounded(limit,16)) return 0;
  Hash h;
  h.scalar(uint64_t(0x4e42434e53444501ull));
  for (auto v : {graph,topology,species}) h.scalar(v);
  for (auto v : {kind,channels,actuators,nw,nb}) h.scalar(v);
  h.scalar(limit);
  for (uint32_t i=0;i<nw;++i) {
    if (!bounded(weights[i])) return 0;
    h.scalar(weights[i]);
  }
  for (uint32_t i=0;i<nb;++i) {
    if (!bounded(biases[i],16)) return 0;
    h.scalar(biases[i]);
  }
  return h.value();
}

extern "C" uint64_t nb_connectome_hash_update(uint64_t state, const void *bytes, size_t count) {
  Hash hash; hash.h = state;
  if (bytes) hash.bytes(bytes, count);
  return hash.h;
}
