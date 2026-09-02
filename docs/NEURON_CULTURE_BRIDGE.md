# Optional Neuron-Culture Controller Bridge

NumiBrain can consume accepted virtual-microelectrode-array activity from the
Numi Lab neuron-culture simulator through an optional typed controller bridge.
The bridge is deliberately outside the default mesoscale brain graph.

The native culture runtime remains owned by Numi Lab/NumanX. It advances a
synthetic LIF/STDP/depression network, virtual MEA, phase field, and tubulin
field in private prepared state. This NumiBrain module receives only copied,
content-addressed electrode spike counts for one exact joint transaction.

`NeuronCultureControllerBridge` then:

1. validates the culture, controller, frame, and joint-root identities;
2. prepares a bounded population action without publishing it;
3. publishes only after the same joint root is accepted; or
4. discards the prepared action when that root is rejected.

The included 60-electrode decoder is an explicit deterministic experimental
policy for the synthetic Potter-style layout. It is not an anatomical claim,
a biological calibration, or a learned policy. The bridge does not expose
Metal buffers, culture state, plasticity authority, or a host-side physics
token. Direct zero-copy GPU integration remains a later versioned interop step.

Focused qualification:

```sh
swift test --filter NeuronCultureControllerBridgeTests
```

This proves typed identity checks, prepared-state nonpublication, exact-root
acceptance, rejection, and deterministic replay in NumiBrainCore. It does not
prove wet-lab neural culture behavior, hardware MEA compatibility, or embodied
task advantage.
