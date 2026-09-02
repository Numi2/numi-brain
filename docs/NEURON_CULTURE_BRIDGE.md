# Optional Neuron-Culture Controller Bridge

NumiBrain can consume accepted virtual-microelectrode-array activity from the
Numi Lab neuron-culture simulator through an optional typed controller bridge.
The bridge is deliberately outside the default mesoscale brain graph.

The native culture runtime remains owned by Numi Lab/NumanX. It advances a
synthetic LIF/STDP/depression network, virtual MEA, phase field, and tubulin
field in private prepared state. Two deliberately separate paths exist:

- `NeuronCultureControllerBridge` is the copied-frame CPU/test oracle. It:

1. validates the culture, controller, frame, and joint-root identities;
2. prepares a bounded population action without publishing it;
3. publishes only after the same joint root is accepted; or
4. discards the prepared action when that root is rejected.

- the production NumanX path imports an accepted-only, retained Metal lease
  through additive runtime configuration v2 and aggregate snapshot v4. Root
  *N* waits for the exact culture event accepted at *N-1*, validates its
  60-electrode `UInt32` range and transaction generation without reading the
  payload on the host, and applies a bounded population-vector overlay before
  the ordinary motor-ready gate fingerprints the final 416-muscle command.
  The root-*N* NHCNT support consequences separately prepare culture *N+1*.

The included 60-electrode decoder is an explicit deterministic experimental
policy for the synthetic Potter-style layout. It is not an anatomical claim,
a biological calibration, or a learned policy. The public controller does not
expose culture plasticity authority or a host-side physics token; the native
lease is phase-limited and retained internally through terminal publication.

Focused qualification:

```sh
swift test --filter NeuronCultureControllerBridgeTests
swift test --filter MetalNumanXBridgeV1EndToEndTests/testRealFullBodyBrainProposalApplyAndJointPublication
```

Together these qualify typed identity checks, prepared-state nonpublication,
one-root causal delay, accepted aggregate publication, rejection, retry, and
deterministic replay. They do not prove wet-lab neural culture behavior,
hardware MEA compatibility, biological calibration, or embodied task
advantage.
