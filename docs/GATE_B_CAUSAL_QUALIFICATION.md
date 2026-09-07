# Gate B causal qualification path

The existing MLX Gate B evaluator now has a verifier-issued qualification path
instead of leaving its metrics as detached inspectable values.

`MLXGateBCausalQualification.verify` first runs the complete content-addressed
Gate C capture verifier, then requires the live immutable `MetalLearningBatch`
to be exactly the learning-batch artifact/fingerprint retained by that native
capture and the requested species template. It reruns intact, ablated,
value-shuffled and timestamp-shifted policy-head evaluations for every frozen
required modality over a held-out generation interval.

A frozen protocol requires minimum transition coverage, maximum intact action
MSE and minimum action change under each causal intervention class. Missing
modalities/interventions, weak effects, wrong generation range, a foreign live
batch, or a detached capture fail before any authority is returned.

The resulting `MLXGateBCausalQualificationReceipt` is non-serializable and can
only be created by live recomputation. The accompanying content-addressed
artifact is inspectable evidence but cannot be decoded into authority.

This establishes current-source Gate B causal evidence for the learned one-step
belief/policy head. It remains distinct from Gate D physical task success and
does not by itself prove general embodied intelligence, long-horizon memory, or
cross-embodiment transfer.
