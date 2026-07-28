import Foundation
import Testing
@testable import Handover_V4

@MainActor
struct SharePlayAbbreviationSyncTests {
    @Test
    func localSelectionUpdatesImmediatelyAndBroadcastsWhenConnected() {
        let participantID = UUID()
        let transport = InMemorySharePlayTransport(
            localParticipantID: participantID
        )
        let state = SharedCardState()
        let coordinator = makeCoordinator(state: state, transport: transport)
        let selection = makeSelection("crrt")

        coordinator.toggleAbbreviationSelection(selection, for: "plan")

        #expect(state.abbreviationSelections["plan"] == selection)
        #expect(transport.abbreviationMessages.count == 1)
        #expect(transport.abbreviationMessages.first?.updateCount.count == 1)
        #expect(
            transport.abbreviationMessages.first?.updateCount.participant
                == participantID
        )
    }

    @Test
    func selectionRemainsFunctionalWithoutAnActiveSession() {
        let state = SharedCardState()
        let coordinator = makeCoordinator(state: state)
        let selection = makeSelection("crrt")

        coordinator.toggleAbbreviationSelection(selection, for: "plan")

        #expect(state.abbreviationSelections["plan"] == selection)
    }

    @Test
    func concurrentSelectionsConvergeUsingDeterministicLastWriterWins() {
        let first = makeParticipant()
        let second = makeParticipant()
        let firstSelection = makeSelection("af")
        let secondSelection = makeSelection("crrt")

        first.coordinator.toggleAbbreviationSelection(firstSelection, for: "plan")
        second.coordinator.toggleAbbreviationSelection(secondSelection, for: "plan")

        let firstMessage = try! #require(first.transport.abbreviationMessages.first)
        let secondMessage = try! #require(second.transport.abbreviationMessages.first)
        first.transport.deliverAbbreviationMessages(to: second.coordinator)
        second.transport.deliverAbbreviationMessages(to: first.coordinator)

        let expected = firstMessage.updateCount > secondMessage.updateCount
            ? firstSelection
            : secondSelection
        #expect(first.state.abbreviationSelections["plan"] == expected)
        #expect(second.state.abbreviationSelections["plan"] == expected)
    }

    @Test
    func movementAndOrbitCountersDoNotSupersedeAbbreviationActions() {
        let participant = makeParticipant()
        let selection = makeSelection("crrt")

        participant.coordinator.setCardPosition(
            name: "plan",
            position: .init(1, 2, 3),
            syncChanges: true
        )
        participant.coordinator.handleRemoteOrbitMessage(
            OrbitSyncMessage(
                state: OrbitState(
                    interactionMode: .orbit,
                    rotation: 0,
                    focusedCardName: "plan",
                    expandedCardName: "plan"
                ),
                updateCount: MessageUpdateCount(
                    count: 40,
                    participant: UUID()
                ),
                isFinal: true
            )
        )
        participant.coordinator.toggleAbbreviationSelection(selection, for: "plan")

        #expect(participant.transport.cardMessages.first?.updateCount.count == 1)
        #expect(
            participant.transport.abbreviationMessages.first?.updateCount.count
                == 1
        )
        #expect(participant.state.abbreviationSelections["plan"] == selection)
    }

    @Test
    func collapsedCardsClearAndRejectHiddenRemoteSelections() {
        let participant = makeParticipant()
        let selection = makeSelection("crrt")

        participant.coordinator.toggleAbbreviationSelection(selection, for: "plan")
        participant.coordinator.setCardState(
            name: "plan",
            isExpanded: false,
            syncChanges: false
        )
        participant.coordinator.handleRemoteAbbreviationMessage(
            AbbreviationSyncMessage(
                cardName: "plan",
                action: .set(selection),
                updateCount: MessageUpdateCount(
                    count: 2,
                    participant: UUID()
                )
            )
        )
        participant.coordinator.toggleAbbreviationSelection(
            makeSelection("af"),
            for: "plan"
        )

        #expect(participant.state.abbreviationSelections["plan"] == nil)
        #expect(participant.transport.abbreviationMessages.count == 1)
    }

    @Test
    func catchUpTransfersSelectionsAndConflictCounters() {
        let source = makeParticipant()
        let lateJoiner = makeParticipant()
        let firstSelection = makeSelection("af")
        let latestSelection = makeSelection("crrt")

        source.coordinator.toggleAbbreviationSelection(firstSelection, for: "plan")
        source.coordinator.toggleAbbreviationSelection(latestSelection, for: "plan")
        source.coordinator.sendCatchUp(
            to: [lateJoiner.transport.localParticipantID]
        )
        source.transport.deliverCatchUpMessages(to: lateJoiner.coordinator)

        #expect(
            lateJoiner.state.abbreviationSelections["plan"] == latestSelection
        )

        lateJoiner.coordinator.toggleAbbreviationSelection(
            makeSelection("copd"),
            for: "plan"
        )
        #expect(
            lateJoiner.transport.abbreviationMessages.last?.updateCount.count == 3
        )
    }

    @Test
    func conflictingCatchUpsConvergeRegardlessOfArrivalOrder() {
        let firstSource = makeParticipant()
        let secondSource = makeParticipant()
        let firstLateJoiner = makeParticipant()
        let secondLateJoiner = makeParticipant()
        let firstSelection = makeSelection("af")
        let secondSelection = makeSelection("crrt")

        firstSource.coordinator.toggleAbbreviationSelection(
            firstSelection,
            for: "plan"
        )
        secondSource.coordinator.toggleAbbreviationSelection(
            secondSelection,
            for: "plan"
        )
        firstSource.coordinator.sendCatchUp(
            to: [firstLateJoiner.transport.localParticipantID]
        )
        secondSource.coordinator.sendCatchUp(
            to: [firstLateJoiner.transport.localParticipantID]
        )

        firstSource.transport.deliverCatchUpMessages(
            to: firstLateJoiner.coordinator
        )
        secondSource.transport.deliverCatchUpMessages(
            to: firstLateJoiner.coordinator
        )
        secondSource.transport.deliverCatchUpMessages(
            to: secondLateJoiner.coordinator
        )
        firstSource.transport.deliverCatchUpMessages(
            to: secondLateJoiner.coordinator
        )

        let firstMessage = try! #require(
            firstSource.transport.abbreviationMessages.first
        )
        let secondMessage = try! #require(
            secondSource.transport.abbreviationMessages.first
        )
        let expected = firstMessage.updateCount > secondMessage.updateCount
            ? firstSelection
            : secondSelection
        #expect(
            firstLateJoiner.state.abbreviationSelections["plan"] == expected
        )
        #expect(
            secondLateJoiner.state.abbreviationSelections["plan"] == expected
        )
    }

    @Test
    func catchUpRejectsASelectionForACollapsedCard() {
        let lateJoiner = makeParticipant()
        let selection = makeSelection("crrt")

        lateJoiner.coordinator.applyCatchUpMessage(
            CatchUpMessage(
                allCardStates: ["plan": false],
                allCardPositions: [:],
                cardUpdateCounts: [:],
                abbreviationSelections: ["plan": selection],
                abbreviationUpdateCounts: [
                    "plan": MessageUpdateCount(
                        count: 4,
                        participant: UUID()
                    )
                ],
                orbitState: .inactive,
                orbitUpdateCount: nil,
                dashboardState: DashboardState(
                    selectedPatientID: nil,
                    sectionOrder: SectionID.defaultOrder
                ),
                dashboardUpdateCount: nil
            )
        )

        #expect(lateJoiner.state.abbreviationSelections["plan"] == nil)
        lateJoiner.coordinator.toggleAbbreviationSelection(
            makeSelection("af"),
            for: "plan"
        )
        #expect(lateJoiner.transport.abbreviationMessages.isEmpty)
    }

    private func makeParticipant() -> TestParticipant {
        let transport = InMemorySharePlayTransport(localParticipantID: UUID())
        let state = SharedCardState()
        return TestParticipant(
            coordinator: makeCoordinator(state: state, transport: transport),
            state: state,
            transport: transport
        )
    }

    private func makeCoordinator(
        state: SharedCardState,
        transport: InMemorySharePlayTransport? = nil
    ) -> SharePlayCoordinator {
        SharePlayCoordinator(
            handoverViewModel: HandoverViewModel(),
            sharedCardState: state,
            transport: transport
        )
    }

    private func makeSelection(_ glossaryEntryID: String) -> AbbreviationSelection {
        AbbreviationSelection(
            textID: "plan.item.task",
            glossaryEntryID: glossaryEntryID,
            occurrenceIndex: 0
        )
    }
}

@MainActor
private struct TestParticipant {
    let coordinator: SharePlayCoordinator
    let state: SharedCardState
    let transport: InMemorySharePlayTransport
}

@MainActor
private final class InMemorySharePlayTransport: SharePlayMessageTransport {
    let localParticipantID: UUID
    private(set) var cardMessages: [CardSyncMessage] = []
    private(set) var abbreviationMessages: [AbbreviationSyncMessage] = []
    private(set) var catchUpMessages: [CatchUpMessage] = []

    init(localParticipantID: UUID) {
        self.localParticipantID = localParticipantID
    }

    func endSession() {}

    func sendMessage(_ message: CardSyncMessage) {
        cardMessages.append(message)
    }

    func sendMessage(_ message: DashboardSyncMessage) {}

    func sendMessage(_ message: OrbitSyncMessage) {}

    func sendMessage(_ message: AbbreviationSyncMessage) {
        abbreviationMessages.append(message)
    }

    func sendMessage(
        _ message: CatchUpMessage,
        to participantIDs: Set<UUID>
    ) {
        catchUpMessages.append(message)
    }

    func deliverAbbreviationMessages(to coordinator: SharePlayCoordinator) {
        for message in abbreviationMessages {
            coordinator.handleRemoteAbbreviationMessage(message)
        }
    }

    func deliverCatchUpMessages(to coordinator: SharePlayCoordinator) {
        for message in catchUpMessages {
            coordinator.applyCatchUpMessage(message)
        }
    }
}
