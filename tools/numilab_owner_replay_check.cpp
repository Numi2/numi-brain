// Real pinned NumiLab integration check, not a replacement physics backend.
#include <metalrobo/c_api.h>
#include "NumiBrainNumiLabBridgeABI.h"
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
void require(bool ok, const std::string& reason) { if (!ok) throw std::runtime_error(reason); }
void check(int status, NBNumiLabBorrowedRollout* bridge) {
  if (status != 0) {
    const char* error = nb_numilab_borrowed_rollout_last_error(bridge);
    throw std::runtime_error(error && *error ? error : "native bridge operation failed");
  }
}
struct Run {
  NBNumiLabRolloutIdentityV1 origin{};
  std::vector<uint64_t> digests;
  std::vector<float> finalQ;
  std::string device;
};
Run execute(uint32_t source, const char* library, const char* metallib, bool altered) {
  MRRunManifestC manifest{};
  manifest.source = source;
  manifest.surface = MR_LOCOMOTION_SURFACE_GROUND;
  manifest.task = MR_UNITREE_G1_TASK_VELOCITY;
  manifest.profile.environment_count = 1;
  manifest.profile.physics_substeps = 1;
  manifest.profile.velocity_iterations = 16;
  manifest.profile.final_velocity_iterations = 32;
  manifest.profile.control_timestep_seconds = 0.001f;
  manifest.profile.seed = 0x4e554d49;
  manifest.metallib_path = metallib;
  using World = std::unique_ptr<MRTaskRolloutHandle, decltype(&mr_task_rollout_destroy)>;
  World world(mr_create_task_rollout(&manifest), &mr_task_rollout_destroy);
  require(bool(world), std::string("native construction failed: ") + mr_last_error());
  require(mr_task_rollout_set_state_readback(world.get(), 1) == 0, "inspection readback setup failed");
  std::array<char,1024> error{};
  using Bridge = std::unique_ptr<NBNumiLabBorrowedRollout, decltype(&nb_numilab_borrowed_rollout_destroy)>;
  Bridge bridge(nb_numilab_borrowed_rollout_open(library, world.get(), error.data(), error.size()),
    &nb_numilab_borrowed_rollout_destroy);
  require(bool(bridge), std::string("bridge admission failed: ") + error.data());
  Run result;
  check(nb_numilab_borrowed_rollout_identity(bridge.get(), &result.origin), bridge.get());
  require(result.origin.environment_count == 1 && result.origin.action_count > 0 &&
    result.origin.submitted_control_steps == 0 && result.origin.completed_environment_steps == 0 &&
    result.origin.submission_count == 0, "native rollout is not fresh");
  const size_t count = nb_numilab_borrowed_rollout_action_binding_count(bridge.get());
  require(count == result.origin.action_count, "live action table differs from layout");
  std::vector<NBNumiLabActionBindingV1> bindings(count);
  check(nb_numilab_borrowed_rollout_copy_action_bindings(bridge.get(), bindings.data(), count), bridge.get());
  std::vector<float> actions(count, 0.0f);
  for (uint64_t step = 0; step < 4; ++step) {
    // Declared test commands, not a trained policy or task-success benchmark.
    actions[0] = (altered ? -1.0f : 1.0f) * (0.01f * float(step + 1));
    NBNumiLabAdvanceResultV1 advance{};
    check(nb_numilab_borrowed_rollout_advance(bridge.get(), actions.data(), actions.size(),
      100 + step, &advance), bridge.get());
    require(advance.control_step_count == 1 && advance.successful_environment_steps == 1 &&
      advance.failed_environment_steps == 0, "native solver did not accept one clean step");
    const uint64_t digest = nb_numilab_borrowed_rollout_resident_state_fingerprint(bridge.get());
    require(digest != 0, nb_numilab_borrowed_rollout_last_error(bridge.get()));
    require(nb_numilab_borrowed_rollout_resident_state_fingerprint(bridge.get()) == digest,
      "idle fingerprint inspection changed state identity");
    result.digests.push_back(digest);
    NBNumiLabRolloutIdentityV1 after{};
    check(nb_numilab_borrowed_rollout_identity(bridge.get(), &after), bridge.get());
    require(after.submission_count == step + 1 && after.submitted_control_steps == step + 1 &&
      after.completed_environment_steps == step + 1, "accepted native counters diverged");
  }
  const MRTaskRolloutLayoutC layout = mr_task_rollout_layout(world.get());
  const size_t qCount = size_t(layout.environment_count) * layout.nq;
  const float* q = mr_task_rollout_final_q(world.get());
  require(q && qCount > 0, "native final state readback is unavailable");
  result.finalQ.assign(q, q + qCount);
  for (float value : result.finalQ) require(std::isfinite(value), "native final state is nonfinite");
  const char* device = mr_task_rollout_device_name(world.get());
  result.device = device ? device : "unreported";
  return result;
}
bool sameOrigin(const NBNumiLabRolloutIdentityV1& a, const NBNumiLabRolloutIdentityV1& b) {
  return a.environment_count == b.environment_count && a.action_count == b.action_count &&
    a.run_fingerprint == b.run_fingerprint && a.world_fingerprint == b.world_fingerprint &&
    a.task_fingerprint == b.task_fingerprint && a.action_fingerprint == b.action_fingerprint &&
    a.robot_fingerprint == b.robot_fingerprint && a.submitted_control_steps == b.submitted_control_steps &&
    a.completed_environment_steps == b.completed_environment_steps && a.submission_count == b.submission_count;
}
}
int main(int argc, char** argv) {
  try {
    require(argc == 3, "usage: numilab_owner_replay_check LIBRARY METALLIB");
    const std::array<std::pair<const char*,uint32_t>,3> robots{{
      {"franka",MR_RUN_SOURCE_FRANKA_PICK_PLACE}, {"g1",MR_RUN_SOURCE_UNITREE_G1}, {"x500",MR_RUN_SOURCE_PX4_X500}}};
    for (const auto& [robot,source] : robots) {
      const Run original = execute(source, argv[1], argv[2], false);
      const Run replay = execute(source, argv[1], argv[2], false);
      const Run altered = execute(source, argv[1], argv[2], true);
      require(sameOrigin(original.origin, replay.origin) && sameOrigin(original.origin, altered.origin),
        "fresh native run identities differ");
      require(original.digests == replay.digests, "resident digest replay differs for " + std::string(robot));
      require(original.finalQ.size() == replay.finalQ.size() &&
        std::memcmp(original.finalQ.data(), replay.finalQ.data(), original.finalQ.size()*sizeof(float)) == 0,
        "native q readback replay differs for " + std::string(robot));
      require(original.digests != altered.digests, "changed commands did not change continuation state");
      std::cout << "NUMILAB_NATIVE_REPLAY {\"robot\":" << std::quoted(robot)
        << ",\"device\":" << std::quoted(original.device)
        << ",\"accepted_steps_per_run\":4,\"runs\":3,\"run_fingerprint\":" << std::quoted(std::to_string(original.origin.run_fingerprint))
        << ",\"final_digest\":" << std::quoted(std::to_string(original.digests.back()))
        << ",\"q_scalars\":" << original.finalQ.size()
        << ",\"digest_replay_exact\":true,\"q_replay_exact\":true,\"changed_command_changes_digest\":true"
        << ",\"brain_root_executed\":false,\"learned_task_qualified\":false}" << std::endl;
    }
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "native owner replay failed: " << error.what() << std::endl;
    return 1;
  }
}
