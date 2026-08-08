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

    @Test
    func localPositionAppliesImmediatelyAndSendsCanonicalFact() throws {
        let participant = ReplicationParticipant(id: UUID(), connected: true)
        let position = SIMD3<Float>(0.25, 1.1, -0.4)

        participant.replicator.transact(.moveCard(cardID, to: position))

        #expect(participant.state.positions[cardID] == position)
        let fact = try #require(participant.transport.envelopes.first?.facts.first)
        #expect(fact.id == .cardPosition(cardID))
        #expect(fact.value == .cardPosition(position))
    }

    @Test
    func moveAndCollapseConvergeWhenDeliveredInReverseOrder() {
        let mover = ReplicationParticipant(id: UUID(), connected: true)
        let collapser = ReplicationParticipant(id: UUID(), connected: true)
        let receiver = ReplicationParticipant(id: UUID())
        let position = SIMD3<Float>(-0.2, 0.8, 0.35)

        mover.replicator.transact(.moveCard(cardID, to: position))
        collapser.replicator.transact(
            .setCardExpansion(cardID, isExpanded: false)
        )

        receiver.replicator.receive(collapser.transport.envelopes[0])
        receiver.replicator.receive(mover.transport.envelopes[0])

        #expect(receiver.state.positions[cardID] == position)
        #expect(receiver.state.expansionStates[cardID] == false)
    }

    @Test
    func staleDuplicateAndReversedPositionsAreRejected() {
        let participant = ReplicationParticipant(id: UUID())
        let writerID = UUID()
        let oldPosition = SIMD3<Float>(0, 0, 0)
        let latestPosition = SIMD3<Float>(1, 2, 3)
        let latest = envelope(
            id: .cardPosition(cardID),
            value: .cardPosition(latestPosition),
            count: 2,
            participantID: writerID
        )

        participant.replicator.receive(latest)
        participant.replicator.receive(latest)
        participant.replicator.receive(
            envelope(
                id: .cardPosition(cardID),
                value: .cardPosition(oldPosition),
                count: 1,
                participantID: writerID
            )
        )

        #expect(participant.state.positions[cardID] == latestPosition)
    }

    @Test
    func reconnectAndLateJoinSendOnlyLatestPosition() throws {
        let source = ReplicationParticipant(id: UUID())
        let lateJoiner = ReplicationParticipant(id: UUID())
        let latestPosition = SIMD3<Float>(0.6, 0.7, -0.8)

        source.replicator.transact(
            .moveCard(cardID, to: SIMD3<Float>(0.1, 0.2, 0.3))
        )
        source.replicator.transact(.moveCard(cardID, to: latestPosition))
        source.replicator.attach(source.transport)

        let reconnect = try #require(source.transport.envelopes.first)
        #expect(reconnect.facts.count == 1)
        #expect(reconnect.facts[0].value == .cardPosition(latestPosition))
        #expect(reconnect.facts[0].version.count == 2)

        source.replicator.sendCurrentState(to: [lateJoiner.id])
        let snapshot = try #require(source.transport.targetedEnvelopes.first)
        lateJoiner.replicator.receive(snapshot)
        #expect(lateJoiner.state.positions[cardID] == latestPosition)
    }

    @Test
    func dashboardReorderConvergesAndRemainsIndependent() {
        let first = ReplicationParticipant(id: UUID(), connected: true)
        let second = ReplicationParticipant(id: UUID(), connected: true)
        let receiver = ReplicationParticipant(id: UUID())
        let position = SIMD3<Float>(0.4, 0.5, 0.6)

        first.replicator.transact(
            .moveDashboardSection(.vitals, toPositionOf: .labs)
        )
        second.replicator.transact(.moveCard(cardID, to: position))

        receiver.replicator.receive(second.transport.envelopes[0])
        receiver.replicator.receive(first.transport.envelopes[0])

        #expect(receiver.viewModel.sectionOrder == first.viewModel.sectionOrder)
        #expect(receiver.state.positions[cardID] == position)
    }

    @Test
    func staleDuplicateAndReversedDashboardOrdersAreRejected() {
        let participant = ReplicationParticipant(id: UUID())
        let writerID = UUID()
        let oldOrder = SectionID.defaultOrder
        let latestOrder = Array(SectionID.defaultOrder.reversed())
        let latest = envelope(
            id: .dashboardOrder,
            value: .dashboardOrder(latestOrder),
            count: 2,
            participantID: writerID
        )

        participant.replicator.receive(latest)
        participant.replicator.receive(latest)
        participant.replicator.receive(
            envelope(
                id: .dashboardOrder,
                value: .dashboardOrder(oldOrder),
                count: 1,
                participantID: writerID
            )
        )

        #expect(participant.viewModel.sectionOrder == latestOrder)
    }

    @Test
    func reconnectAndLateJoinSendOnlyLatestDashboardOrder() throws {
        let source = ReplicationParticipant(id: UUID())
        let lateJoiner = ReplicationParticipant(id: UUID())

        source.replicator.transact(
            .moveDashboardSection(.vitals, toPositionOf: .labs)
        )
        source.replicator.transact(
            .moveDashboardSection(.plan, toPositionOf: .infusions)
        )
        let latestOrder = source.viewModel.sectionOrder
        source.replicator.attach(source.transport)

        let reconnect = try #require(source.transport.envelopes.first)
        #expect(reconnect.facts.count == 1)
        #expect(reconnect.facts[0].value == .dashboardOrder(latestOrder))
        #expect(reconnect.facts[0].version.count == 2)

        source.replicator.sendCurrentState(to: [lateJoiner.id])
        let snapshot = try #require(source.transport.targetedEnvelopes.first)
        lateJoiner.replicator.receive(snapshot)
        #expect(lateJoiner.viewModel.sectionOrder == latestOrder)
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
    let viewModel: HandoverViewModel
    let transport = RecordingReplicationTransport()
    let replicator: SharedHandoverReplicator

    init(id: UUID, connected: Bool = false) {
        self.id = id
        let viewModel = HandoverViewModel(
            initialBedNumber: "BED-03",
            patientLoader: EmptyPatientLoader()
        )
        self.viewModel = viewModel
        replicator = SharedHandoverReplicator(
            participantID: id,
            sharedCardState: state,
            handoverViewModel: viewModel
        )
        if connected {
            replicator.attach(transport)
        }
    }
}

private struct EmptyPatientLoader: PatientLoading {
    func loadPatients() throws -> [Patient] { [] }
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
