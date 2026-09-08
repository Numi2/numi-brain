# Native body topology and connectome ownership

A robot may consist of one rigid body with independent effectors and no
body-to-body joints. `NumanXJointTopologyCatalog` now represents that tree as
one body and an empty joint array. `SpeciesBodyTopology` requires a nonempty
body tree with exactly bodyCount-1 joints. A multi-body disconnected catalog,
empty body and fabricated singleton joint remain errors.

The neural arena retains zero logical joint records. It reserves aligned
bindable padding only; the padding is not counted as anatomy or belief.
Accepted-consequence encoding omits zero-sized joint dispatch. Memory capture
permits the empty joint section while preserving the other required sections.
Innate state already derives joint and muscle beliefs from the real catalogs
and therefore creates none for a jointless, non-muscular body.

The low-level connectome hook and prepared-neural restore now validate the
binding's species fingerprint against the owning cognitive arena BEFORE
returning cached output, encoding or mutating restore state. Different bodies
with the same tensor dimensions cannot transplant a connectome participant.
The species identity includes the exact joint-catalog and morphology identity.
Existing normal factory checks remain in force.

`ConnectomeBodyContractTests` covers exact singleton compilation/round trip,
logical empty arena state, absence of invented joint/muscle beliefs, same-shape
foreign-species rejection and invalid topology/count rejection. This authored
fixture has four current-command channels. It is NOT identified as PX4, a
flight simulator or successful quadrotor control.

The six owning source modifications were prepared from a plain reviewed diff
and matched exact final hashes in run 34185282668. They are published here as
ordinary source; the temporary preparation diff/workflow is removed. No code
materialization is required before a package build. Test presence and source
publication do not establish a passing Apple test or a real robot outcome.
