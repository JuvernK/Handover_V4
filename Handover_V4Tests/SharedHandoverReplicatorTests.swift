import Foundation
import Testing
@testable import Handover_V4

@MainActor
struct SharedHandoverReplicatorTests {
    private let cardID = ClinicalCardID.section(.plan)

    @Test
    func localExpansionAndSelectionApplyImmediately() {
        let participant = ReplicationParticipant(id: UUID())
        let selection = makeSelection("af")

        participant.replicator.transact(
            .toggleAbbreviation(selection, in: cardID)
        )
        #expect(participant.state.abbreviationSelections[cardID] == selection)

        participant.replicator.transact(
            .setCardExpansion(cardID, isExpanded: false)
        )
        #expect(participant.state.expansionStates[cardID] == false)
        #expect(participant.state.abbreviationSelections[cardID] == nil)
    }

    @Test
    func collapseAndSelectionTombstoneTravelAtomically() throws {
        let participant = ReplicationParticipant(id: UUID(), connected: true)
        participant.replicator.transact(
            .toggleAbbreviation(makeSelection("af"), in: cardID)
        )
        participant.transport.envelopes.removeAll()

        participant.replicator.transact(
            .setCardExpansion(cardID, isExpanded: false)
        )

        let envelope = try #require(participant.transport.envelopes.first)
        #expect(envelope.facts.count == 2)
        #expect(
            envelope.facts.contains {
                $0.id == .cardExpansion(cardID)
                    && $0.value == .cardExpansion(false)
            }
        )
        #expect(
            envelope.facts.contains {
                $0.id == .abbreviationSelection(cardID)
                    && $0.value == .abbreviationSelection(nil)
            }
        )
    }

    @Test
    func concurrentAndReversedDeliveriesConverge() {
        let lowerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let higherID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let first = ReplicationParticipant(id: lowerID, connected: true)
        let second = ReplicationParticipant(id: higherID, connected: true)
        let firstSelection = makeSelection("af")
        let secondSelection = makeSelection("crrt")

        first.replicator.transact(
            .toggleAbbreviation(firstSelection, in: cardID)
        )
        second.replicator.transact(
            .toggleAbbreviation(secondSelection, in: cardID)
        )
        let firstEnvelope = first.transport.envelopes[0]
        let secondEnvelope = second.transport.envelopes[0]

        first.replicator.receive(secondEnvelope)
        first.replicator.receive(secondEnvelope)
        second.replicator.receive(firstEnvelope)
        second.replicator.receive(firstEnvelope)

        #expect(first.state.abbreviationSelections[cardID] == secondSelection)
        #expect(second.state.abbreviationSelections[cardID] == secondSelection)
    }

    @Test
    func newerSelectionStaysHiddenWhileCollapsedAndRejectsOlderState() {
        let participant = ReplicationParticipant(id: UUID())
        let writerID = UUID()
        let newerSelection = makeSelection("crrt")

        participant.replicator.receive(
            envelope(
                id: .cardExpansion(cardID),
                value: .cardExpansion(false),
                count: 1,
                participantID: writerID
            )
        )
        participant.replicator.receive(
            envelope(
                id: .abbreviationSelection(cardID),
                value: .abbreviationSelection(newerSelection),
                count: 3,
                participantID: writerID
            )
        )
        participant.replicator.receive(
            envelope(
                id: .abbreviationSelection(cardID),
                value: .abbreviationSelection(makeSelection("af")),
                count: 2,
                participantID: writerID
            )
        )

        #expect(participant.state.abbreviationSelections[cardID] == nil)
    }

    @Test
    func reconnectSendsOnlyLatestChangedFact() throws {
        let participant = ReplicationParticipant(id: UUID())
        participant.replicator.transact(
            .toggleAbbreviation(makeSelection("af"), in: cardID)
        )
        participant.replicator.transact(
            .toggleAbbreviation(makeSelection("crrt"), in: cardID)
        )

        participant.replicator.attach(participant.transport)

        let envelope = try #require(participant.transport.envelopes.first)
        #expect(envelope.facts.count == 1)
        #expect(
            envelope.facts[0].value
                == .abbreviationSelection(makeSelection("crrt"))
        )
        #expect(envelope.facts[0].version.count == 2)
    }

    @Test
    func lateJoinUsesTheSameMergeAsLiveDelivery() throws {
        let source = ReplicationParticipant(id: UUID(), connected: true)
        let lateJoiner = ReplicationParticipant(id: UUID())
        let selection = makeSelection("af")
        source.replicator.transact(
            .toggleAbbreviation(selection, in: cardID)
        )

        source.replicator.sendCurrentState(to: [lateJoiner.id])
        let snapshot = try #require(source.transport.targetedEnvelopes.first)
        lateJoiner.replicator.receive(snapshot)

        #expect(lateJoiner.state.abbreviationSelections[cardID] == selection)
    }

    private func makeSelection(
        _ glossaryEntryID: String
    ) -> AbbreviationSelection {
        AbbreviationSelection(
            textID: "plan.item.task",
            glossaryEntryID: glossaryEntryID,
            occurrenceIndex: 0
        )
    }

    private func envelope(
        id: ReplicationFactID,
        value: ReplicationFactValue,
        count: Int,
        participantID: UUID
    ) -> ReplicationEnvelope {
        ReplicationEnvelope(
            facts: [
                VersionedReplicationFact(
                    id: id,
                    value: value,
                    version: ReplicationVersion(
                        count: count,
                        participantID: participantID
                    )
                )
            ]
        )
    }
}

@MainActor
private final class ReplicationParticipant {
    let id: UUID
    let state = SharedCardState()
    let transport = RecordingReplicationTransport()
    let replicator: SharedHandoverReplicator

    init(id: UUID, connected: Bool = false) {
        self.id = id
        replicator = SharedHandoverReplicator(
            participantID: id,
            sharedCardState: state
        )
        if connected {
            replicator.attach(transport)
        }
    }
}

@MainActor
private final class RecordingReplicationTransport: ReplicationTransport {
    var envelopes: [ReplicationEnvelope] = []
    var targetedEnvelopes: [ReplicationEnvelope] = []

    func send(_ envelope: ReplicationEnvelope) {
        envelopes.append(envelope)
    }

    func send(
        _ envelope: ReplicationEnvelope,
        to participantIDs: Set<UUID>
    ) {
        targetedEnvelopes.append(envelope)
    }
}
