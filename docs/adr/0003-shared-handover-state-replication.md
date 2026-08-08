# State-oriented Shared Handover State replication

Status: accepted

`SharePlayCoordinator` currently mixes SharePlay lifecycle, domain behavior,
version ordering, disconnected replay, and late-join merging. Shared Handover
State will instead converge through a deep `SharedHandoverReplicator` module:
callers perform synchronous main-actor updates through controlled
`SharedHandoverTransaction` operations, while `HandoverViewModel` and
`SharedCardState` retain ownership of their values. Live updates and late-join
snapshots use the same order-independent, duplicate-safe merge policy;
independently mergeable facts have independent logical versions, participant
identity breaks equal-version ties, related consequences apply atomically, and
cleared values retain versioned tombstones. Any participant may write, temporary
disconnection retains only each fact's latest value, and versions remain
in-memory for the app lifetime.

The SharePlay seam carries one domain-blind `ReplicationEnvelope` through the
production and in-memory transport adapters. Attaching or detaching an adapter
automatically changes reconciliation behavior, late joining remains
peer-to-peer, and transient Orbit changes may be coalesced while settled state
is sent immediately. The fixed Study Patient is outside Shared Handover State,
so obsolete runtime patient-selection synchronization will be removed. Orbit
state transitions move out of `SharePlayCoordinator` as the minimum extraction
needed to keep domain behavior outside replication; broader Orbit interaction
and RealityKit restructuring remains separate work.

Action-oriented replication, raw mutable shared state, per-domain transport
messages, and host-authoritative catch-up were rejected because they expose
replication mechanics, permit invalid state, widen the transport interface, or
reduce peer convergence. Synchronization tests will use the replicator
interface; domain invariants and SharePlay lifecycle remain separate test
surfaces.
