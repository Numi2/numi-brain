# Sensor-to-motor connectivity preflight

`numi-brain-connectome validate-controller GRAPH SPEC BODY PARAMETER_HEX` now
reports shortest recurrent paths from active sensory projections to descending
readouts, minimum distance per channel, unused inputs and disconnected outputs.
It also reports decoder actuator rows that cannot receive a sensory-dependent
feature. `audit-controller` accepts the same arguments and exits unsuccessfully
when any channel or actuator row has no structural sensor path. This strict
preflight is for a proposed fully sensor-driven controller, not a prohibition
on explicitly identified ablation experiments or body-local reflex systems.

The native C++ audit validates the original graph and respects edge direction,
zero connection weights, zero destination recurrent gains, zero input weights,
zero input scales, zero sensory gains and zero readout weights. Affine biases
are not sensory information. Negative weights still permit influence. It never
invents edges or treats an unconnected motor output as connected because its
bias generates a nonzero command.

One outgoing CSR transpose plus two multi-source breadth-first traversals give
O(neurons + connections + projections) work. Traversal scratch is explicitly
budgeted as `4 * (5 * neurons + 1 + connections)` bytes, excluding the original
graph and validator allocations. Projection distances follow the compiled
binding's canonical order. An absent path is encoded as JSON null. A distance
is a hop count, NOT a physiological delay or an estimate of control quality.

A structural path does not prove useful effective influence. Saturation,
readout cancellation, poor encoding, dynamics, body mechanics and task behavior
still require execution and causal intervention tests. Audit JSON confers no
runtime or policy-admission authority.

## Executed checks

Twelve portable native tests cover direction, negative/zero weights and gains,
multiple inputs/readouts, zero-hop paths, disabled channels, invalid roles,
corruption and exact scratch budgets. The actual Swift graph and audit sources
were compiled, linked against the native library and executed on Linux.
Package-level Swift tests are also included for Apple execution.

The full audited pack was traversed from all annotated sensory/ascending nodes
to all annotated motor/descending nodes, not from an invented robot mapping:

- 166,700 graph nodes and 25,582,938 executable edges.
- 19,791 active sensory/ascending input nodes.
- 2,147 active motor/descending nodes; all structurally reachable.
- 19,510 inputs can reach at least one selected output; 281 cannot.
- Traversal scratch: 105,665,756 bytes.

Exact graph identity and observed diagnostic timing are in
`evidence/connectome-connectivity/full-graph.json`. Timing is one Linux
cold-path audit observation, not GPU throughput or physical task evidence.
