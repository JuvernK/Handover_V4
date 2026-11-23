// Flow: standalone checks -> SharedHandoverReplica + SharedHandoverSnapshot + OrbitPresentationState -> SharePlay convergence contract.
import Foundation

/// Simulated peers exchange messages by hand, covering what two headsets would do over SharePlay.
@main
struct SharedHandoverReplicaChecks {
    static func main() {
        let early = Date(timeIntervalSinceReferenceDate: 1_000)
        let late = early.addingTimeInterval(5)
        let a = UUID(), b = UUID()

        // Outside a session nothing is sent or applied.
        var idle = SharedHandoverReplica()
        precondition(idle.localChange(SharedHandoverSnapshot(mode: .orbit)) == nil)
        precondition(idle.catchUp == nil)

        // A local change is sent once; re-reading the same state sends nothing.
        var alice = SharedHandoverReplica()
        alice.begin(participant: a, joinedAt: early, snapshot: SharedHandoverSnapshot())
        let orbitEntry = SharedHandoverSnapshot(
            isImmersed: true, mode: .orbit, orbit: OrbitTarget(card: .situation, isExpanded: true))
        let first = alice.localChange(orbitEntry)!
        precondition(first.version.count == 1)
        precondition(alice.localChange(orbitEntry) == nil)

        // A late joiner adopts the group's state, even when no one has changed anything yet...
        var quietGroup = SharedHandoverReplica()
        quietGroup.begin(participant: a, joinedAt: early, snapshot: SharedHandoverSnapshot(mode: .spatial))
        var joiner = SharedHandoverReplica()
        joiner.begin(participant: b, joinedAt: late, snapshot: SharedHandoverSnapshot(mode: .dashboard))
        precondition(joiner.receive(quietGroup.catchUp!)?.mode == .spatial)
        // ...and the joiner's own catch-up never resets the people already there.
        var freshJoiner = SharedHandoverReplica()
        freshJoiner.begin(participant: b, joinedAt: late, snapshot: SharedHandoverSnapshot(mode: .dashboard))
        precondition(quietGroup.receive(freshJoiner.catchUp!) == nil)
        precondition(quietGroup.shared.mode == .spatial)

        // A joiner also inherits changes made before they arrived, without echoing them.
        var bob = SharedHandoverReplica()
        bob.begin(participant: b, joinedAt: late, snapshot: SharedHandoverSnapshot())
        precondition(bob.receive(alice.catchUp!) == orbitEntry)
        precondition(bob.localChange(orbitEntry) == nil)
        precondition(bob.receive(first) == nil)

        // Both change at once: each applies the other's message, and both settle on one winner.
        var aliceEdit = orbitEntry
        aliceEdit.orbit = OrbitTarget(card: .vitals, isExpanded: true)
        var bobEdit = orbitEntry
        bobEdit.mode = .spatial
        bobEdit.orbit = nil
        let fromAlice = alice.localChange(aliceEdit)!
        let fromBob = bob.localChange(bobEdit)!
        precondition(fromAlice.version.count == fromBob.version.count)
        _ = alice.receive(fromBob)
        _ = bob.receive(fromAlice)
        precondition(alice.shared == bob.shared && alice.shared == aliceEdit)

        // After the conflict, the next change from either side wins everywhere.
        var collapse = alice.shared
        collapse.collapsedSpatialCards = ["Vitals"]
        let next = bob.localChange(collapse)!
        precondition(alice.receive(next) == collapse)

        // Leaving stops both directions.
        bob.end()
        precondition(bob.localChange(SharedHandoverSnapshot()) == nil)
        precondition(bob.receive(next) == nil && bob.catchUp == nil)

        // Every shared fact survives the wire.
        var dashboard = DashboardPresentationState()
        dashboard.focus(.assessment)
        dashboard.setExpanded(false, for: .background)
        var order = DashboardBoardState()
        order.moveSection(.recommendation, toPositionOf: .situation)
        let full = SharedHandoverSnapshot(
            isImmersed: true, mode: .dashboard, orbit: nil,
            collapsedSpatialCards: ["Labs", "Plan"], dashboard: dashboard, dashboardOrder: order)
        let wire = SharedHandoverMessage(snapshot: full, version: next.version)
        let decoded = try! JSONDecoder().decode(SharedHandoverMessage.self, from: JSONEncoder().encode(wire))
        precondition(decoded.snapshot == full)
        precondition(!(decoded.version < next.version) && !(next.version < decoded.version))

        // Orbit shares where it is heading, and a peer's target settles with the peer's disclosure.
        var orbit = OrbitPresentationState()
        precondition(orbit.target == nil)
        orbit.enter()
        precondition(orbit.target == OrbitTarget(card: .situation, isExpanded: true))
        orbit.scrub(to: 2.4)
        precondition(orbit.target == nil)
        precondition(orbit.adopt(OrbitTarget(card: .labs, isExpanded: false)))
        precondition(orbit.target == OrbitTarget(card: .labs, isExpanded: false))
        orbit.finish(revision: orbit.revision)
        precondition(orbit.frontCard == .labs && orbit.expandedCard == nil && orbit.sourceNames.isEmpty)
        // Re-adopting the same target is a no-op, so applying a snapshot twice is harmless.
        let settledRevision = orbit.revision
        precondition(!orbit.adopt(OrbitTarget(card: .labs, isExpanded: false)) && orbit.revision == settledRevision)
        // Expanding the settled front card needs no movement.
        precondition(!orbit.adopt(OrbitTarget(card: .labs, isExpanded: true)))
        precondition(orbit.expandedCard == .labs && orbit.phase == .settled)
        // Local navigation after adopting a collapsed target expands normally again.
        _ = orbit.adopt(OrbitTarget(card: .vitals, isExpanded: false))
        orbit.step(1)
        orbit.finish(revision: orbit.revision)
        precondition(orbit.expandedCard == .infusions)
        // An inactive carousel ignores peers until the immersive scene enters it.
        orbit.leave()
        precondition(!orbit.adopt(OrbitTarget(card: .plan, isExpanded: true)) && orbit.phase == .inactive)

        print("SharePlay snapshot convergence, late-join, conflict, wire, and Orbit adoption checks passed")
    }
}
