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

        coordinator.toggleAbbreviationSelection(selection, for: .section(.plan))

        #expect(state.abbreviationSelections[.section(.plan)] == selection)
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

        coordinator.toggleAbbreviationSelection(selection, for: .section(.plan))

        #expect(state.abbreviationSelections[.section(.plan)] == selection)
    }

    @Test
    func concurrentSelectionsConvergeUsingDeterministicLastWriterWins() {
        let first = makeParticipant()
        let second = makeParticipant()
        let firstSelection = makeSelection("af")
        let secondSelection = makeSelection("crrt")

        first.coordinator.toggleAbbreviationSelection(firstSelection, for: .section(.plan))
        second.coordinator.toggleAbbreviationSelection(secondSelection, for: .section(.plan))

        let firstMessage = try! #require(first.transport.abbreviationMessages.first)
        let secondMessage = try! #require(second.transport.abbreviationMessages.first)
        first.transport.deliverAbbreviationMessages(to: second.coordinator)
        second.transport.deliverAbbreviationMessages(to: first.coordinator)

        let expected = firstMessage.updateCount > secondMessage.updateCount
            ? firstSelection
            : secondSelection
        #expect(first.state.abbreviationSelections[.section(.plan)] == expected)
        #expect(second.state.abbreviationSelections[.section(.plan)] == expected)
    }

    @Test
    func movementAndOrbitCountersDoNotSupersedeAbbreviationActions() {
        let participant = makeParticipant()
        let selection = makeSelection("crrt")

        participant.coordinator.setCardPosition(
            .section(.plan),
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
        participant.coordinator.toggleAbbreviationSelection(selection, for: .section(.plan))

        #expect(participant.transport.cardMessages.first?.updateCount.count == 1)
        #expect(
            participant.transport.abbreviationMessages.first?.updateCount.count
                == 1
        )
        #expect(participant.state.abbreviationSelections[.section(.plan)] == selection)
    }

    @Test
    func collapsedCardsClearAndRejectHiddenRemoteSelections() {
        let participant = makeParticipant()
        let selection = makeSelection("crrt")

        participant.coordinator.toggleAbbreviationSelection(selection, for: .section(.plan))
        participant.coordinator.setCardState(
            .section(.plan),
            isExpanded: false,
            syncChanges: false
        )
        participant.coordinator.handleRemoteAbbreviationMessage(
            AbbreviationSyncMessage(
                cardID: .section(.plan),
                action: .set(selection),
                updateCount: MessageUpdateCount(
                    count: 2,
                    participant: UUID()
                )
            )
        )
        participant.coordinator.toggleAbbreviationSelection(
            makeSelection("af"),
            for: .section(.plan)
        )

        #expect(participant.state.abbreviationSelections[.section(.plan)] == nil)
        #expect(participant.transport.abbreviationMessages.count == 1)
    }

    @Test
    func catchUpTransfersSelectionsAndConflictCounters() {
        let source = makeParticipant()
        let lateJoiner = makeParticipant()
        let firstSelection = makeSelection("af")
        let latestSelection = makeSelection("crrt")

        source.coordinator.toggleAbbreviationSelection(firstSelection, for: .section(.plan))
        source.coordinator.toggleAbbreviationSelection(latestSelection, for: .section(.plan))
        source.coordinator.sendCatchUp(
            to: [lateJoiner.transport.localParticipantID]
        )
        source.transport.deliverCatchUpMessages(to: lateJoiner.coordinator)

        #expect(
            lateJoiner.state.abbreviationSelections[.section(.plan)] == latestSelection
        )

        lateJoiner.coordinator.toggleAbbreviationSelection(
            makeSelection("copd"),
            for: .section(.plan)
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
            for: .section(.plan)
        )
        secondSource.coordinator.toggleAbbreviationSelection(
            secondSelection,
            for: .section(.plan)
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
            firstLateJoiner.state.abbreviationSelections[.section(.plan)] == expected
        )
        #expect(
            secondLateJoiner.state.abbreviationSelections[.section(.plan)] == expected
        )
    }

    @Test
    func preSessionSelectionIsAnnouncedAndConvergesOnJoin() {
        let existingParticipant = makeParticipant()
        let existingSelection = makeSelection("crrt")
        existingParticipant.coordinator.toggleAbbreviationSelection(
            existingSelection,
            for: .section(.plan)
        )

        let joiningState = SharedCardState()
        let joiningSelection = makeSelection("af")
        joiningState.toggleAbbreviationSelection(
            joiningSelection,
            for: .section(.plan)
        )
        let joiningTransport = InMemorySharePlayTransport(
            localParticipantID: UUID()
        )
        let joiningCoordinator = makeCoordinator(
            state: joiningState,
            transport: joiningTransport
        )

        joiningTransport.deliverAbbreviationMessages(
            to: existingParticipant.coordinator
        )
        existingParticipant.coordinator.sendCatchUp(
            to: [joiningTransport.localParticipantID]
        )
        existingParticipant.transport.deliverCatchUpMessages(
            to: joiningCoordinator
        )

        #expect(joiningTransport.abbreviationMessages.count == 1)
        #expect(
            joiningState.abbreviationSelections[.section(.plan)]
                == existingParticipant.state.abbreviationSelections[.section(.plan)]
        )
    }

    @Test
    func disconnectedReplacementAndCollapseAreAnnouncedOnRejoin() {
        let participant = makeParticipant()
        let peer = makeParticipant()
        let replacement = makeSelection("crrt")

        participant.coordinator.toggleAbbreviationSelection(
            makeSelection("af"),
            for: .section(.plan)
        )
        participant.transport.deliverAbbreviationMessages(
            to: peer.coordinator
        )

        participant.coordinator.detachTransport()
        participant.coordinator.toggleAbbreviationSelection(
            replacement,
            for: .section(.plan)
        )
        let replacementTransport = InMemorySharePlayTransport(
            localParticipantID: UUID()
        )
        participant.coordinator.attachTransport(replacementTransport)
        replacementTransport.deliverAbbreviationMessages(to: peer.coordinator)

        #expect(
            replacementTransport.abbreviationMessages.first?.action
                == .set(replacement)
        )
        #expect(
            replacementTransport.abbreviationMessages.first?.updateCount.count
                == 2
        )
        #expect(peer.state.abbreviationSelections[.section(.plan)] == replacement)

        participant.coordinator.detachTransport()
        participant.coordinator.setCardState(
            .section(.plan),
            isExpanded: false,
            syncChanges: true
        )
        let collapseTransport = InMemorySharePlayTransport(
            localParticipantID: UUID()
        )
        participant.coordinator.attachTransport(collapseTransport)
        collapseTransport.deliverAbbreviationMessages(to: peer.coordinator)

        #expect(
            collapseTransport.abbreviationMessages.first?.action == .set(nil)
        )
        #expect(
            collapseTransport.abbreviationMessages.first?.updateCount.count == 3
        )
        #expect(peer.state.abbreviationSelections[.section(.plan)] == nil)
    }

    @Test
    func cardCollapseCatchUpsConvergeRegardlessOfArrivalOrder() {
        let collapsedSource = makeParticipant()
        let expandedSource = makeParticipant()
        let firstLateJoiner = makeParticipant()
        let secondLateJoiner = makeParticipant()
        let expandedSelection = makeSelection("crrt")

        collapsedSource.coordinator.toggleAbbreviationSelection(
            makeSelection("af"),
            for: .section(.plan)
        )
        collapsedSource.coordinator.setCardState(
            .section(.plan),
            isExpanded: false,
            syncChanges: true
        )
        expandedSource.coordinator.setCardState(
            .section(.plan),
            isExpanded: true,
            syncChanges: true
        )
        expandedSource.coordinator.toggleAbbreviationSelection(
            expandedSelection,
            for: .section(.plan)
        )
        collapsedSource.coordinator.sendCatchUp(
            to: [firstLateJoiner.transport.localParticipantID]
        )
        expandedSource.coordinator.sendCatchUp(
            to: [firstLateJoiner.transport.localParticipantID]
        )

        collapsedSource.transport.deliverCatchUpMessages(
            to: firstLateJoiner.coordinator
        )
        expandedSource.transport.deliverCatchUpMessages(
            to: firstLateJoiner.coordinator
        )
        expandedSource.transport.deliverCatchUpMessages(
            to: secondLateJoiner.coordinator
        )
        collapsedSource.transport.deliverCatchUpMessages(
            to: secondLateJoiner.coordinator
        )

        #expect(
            firstLateJoiner.state.expansionStates[.section(.plan)]
                == secondLateJoiner.state.expansionStates[.section(.plan)]
        )
        #expect(
            firstLateJoiner.state.abbreviationSelections[.section(.plan)]
                == secondLateJoiner.state.abbreviationSelections[.section(.plan)]
        )
    }

    @Test
    func patientChangingCatchUpDoesNotRestoreOldPatientSelection() {
        let lateJoiner = makeParticipant(initialBedNumber: "BED-01")
        let source = makeParticipant(initialBedNumber: "BED-02")
        let incomingSelection = makeSelection("crrt")

        lateJoiner.coordinator.toggleAbbreviationSelection(
            makeSelection("af"),
            for: .section(.plan)
        )
        lateJoiner.coordinator.toggleAbbreviationSelection(
            makeSelection("copd"),
            for: .section(.plan)
        )
        source.coordinator.toggleAbbreviationSelection(
            incomingSelection,
            for: .section(.plan)
        )
        source.coordinator.sendCatchUp(
            to: [lateJoiner.transport.localParticipantID]
        )
        source.transport.deliverCatchUpMessages(to: lateJoiner.coordinator)

        #expect(
            lateJoiner.handoverViewModel.patient?.id
                == source.handoverViewModel.patient?.id
        )
        #expect(
            lateJoiner.state.abbreviationSelections[.section(.plan)]
                == incomingSelection
        )
    }

    @Test
    func catchUpRejectsASelectionForACollapsedCard() {
        let lateJoiner = makeParticipant()
        let selection = makeSelection("crrt")

        lateJoiner.coordinator.applyCatchUpMessage(
            CatchUpMessage(
                allCardStates: [.section(.plan): false],
                allCardPositions: [:],
                cardUpdateCounts: [:],
                abbreviationSelections: [.section(.plan): selection],
                abbreviationUpdateCounts: [
                    .section(.plan): MessageUpdateCount(
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

        #expect(lateJoiner.state.abbreviationSelections[.section(.plan)] == nil)
        lateJoiner.coordinator.toggleAbbreviationSelection(
            makeSelection("af"),
            for: .section(.plan)
        )
        #expect(lateJoiner.transport.abbreviationMessages.isEmpty)
    }

    private func makeParticipant(
        initialBedNumber: String = "BED-01"
    ) -> TestParticipant {
        let transport = InMemorySharePlayTransport(localParticipantID: UUID())
        let state = SharedCardState()
        let handoverViewModel = HandoverViewModel(
            initialBedNumber: initialBedNumber
        )
        return TestParticipant(
            coordinator: SharePlayCoordinator(
                handoverViewModel: handoverViewModel,
                sharedCardState: state,
                transport: transport
            ),
            handoverViewModel: handoverViewModel,
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
    let handoverViewModel: HandoverViewModel
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
