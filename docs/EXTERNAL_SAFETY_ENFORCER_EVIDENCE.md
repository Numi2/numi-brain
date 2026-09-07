# Authenticated external safety-enforcer evidence

Status: verifier and evidence contract implemented; no hardware enforcer is
claimed to be connected or qualified.

Gate F previously had only UUID/file-lock coordination for watchdog handoff.
Those primitives are useful against accidental local races but do not
authenticate the producer of an `externalActuatorsInhibited` claim.

`BrainSignedExternalSafetyStop` now carries a detached Ed25519 signature over
canonical stop payload bytes. The verifier accepts authority only from an
independently configured SHA-256 of the Ed25519 public key; a public key embedded
in the record cannot authorize itself. The signed payload binds the exact
watchdog request, source revision, scenario identifier, supervisor monotonic
stop-start time, enforcer UUID, external-actuator-inhibition effect, completion
time, terminal evidence artifact, and three distinct settled measurement
artifacts: force, thermal and actuator.

Each measurement carries an explicit unit, sample count, settled monotonic time,
settled value, frozen safe limit and raw-evidence SHA. The verifier requires all
three classes, safe settled values, unique raw evidence, bounded stop latency,
and bounded post-stop measurement age. Changing any signed field invalidates the
signature.

A successful `BrainExternalSafetyStopReceipt` means: the canonical record was
signed by the pinned key and satisfies the declared numeric/time contract. It
does **not** prove the private key is hardware-isolated, that sensors are
calibrated, that raw evidence really came from a physical transducer, or that an
actuator was electrically/mechanically inhibited. Those claims require a real
independent enforcer adapter, calibration chain and deployment fault campaign.
The all-gates verifier therefore still does not mint Gate F from this component
alone.
