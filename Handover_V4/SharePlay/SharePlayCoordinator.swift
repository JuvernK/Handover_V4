//
//  SharePlayCoordinator.swift
//  Handover_V4
//

import Foundation
import Observation
@preconcurrency import GroupActivities
import Combine

/// Coordinates SharePlay lifecycle and synchronizes app feature state.
@Observable
@MainActor
final class SharePlayCoordinator {
    private let handoverViewModel: HandoverViewModel
    private let sharedCardState: SharedCardState

    private var sessionController: SessionController?
    private var transport: (any SharePlayMessageTransport)?
    private var cardUpdateCounts: [ClinicalCardID: MessageUpdateCount] = [:]
    private var abbreviationUpdateCounts: [ClinicalCardID: MessageUpdateCount] = [:]
    private var disconnectedAbbreviationChanges: Set<ClinicalCardID> = []
    private var orbitUpdateCount: MessageUpdateCount?
    private var dashboardUpdateCount: MessageUpdateCount?
    private var lastOrbitBroadcastTime = Date.distantPast
    private var orbitExpansionTask: Task<Void, Never>?
    private var isObservingSessions = false

    private(set) var isActivating = false
    var errorMessage: String?

    var isActive: Bool {
        transport != nil
    }

    init(
        handoverViewModel: HandoverViewModel,
        sharedCardState: SharedCardState,
        transport: (any SharePlayMessageTransport)? = nil
    ) {
        self.handoverViewModel = handoverViewModel
        self.sharedCardState = sharedCardState
        self.transport = transport
        synchronizeExistingAbbreviationSelections()
    }

    // MARK: - Session lifecycle

    func startObservingSessions() {
        guard !isObservingSessions else { return }
        isObservingSessions = true

        Task(name: "group session observation") {
            await observeGroupSessions()
        }
    }

    func activate() async {
        guard !isActive, !isActivating else { return }

        isActivating = true
        errorMessage = nil
        defer { isActivating = false }

        let activity = SharePlayTogether()
        switch await activity.prepareForActivation() {
        case .activationPreferred:
            do {
                _ = try await activity.activate()
            } catch {
                errorMessage = "SharePlay could not be started: \(error.localizedDescription)"
            }
        case .activationDisabled:
            errorMessage = "Start or join a FaceTime call before starting SharePlay."
        case .cancelled:
            break
        @unknown default:
            errorMessage = "SharePlay is not available right now."
        }
    }

    func endSession() {
        transport?.endSession()
    }

    private func observeGroupSessions() async {
        for await session in SharePlayTogether.sessions() {
            guard let controller = await SessionController(
                session,
                coordinator: self
            ) else {
                continue
            }

            sessionController = controller
            attachTransport(controller)
            observeInvalidation(of: session)
        }
    }

    private func observeInvalidation(
        of session: GroupSession<SharePlayTogether>
    ) {
        Task.immediate(name: "session state observation") {
            for await state in session.$state.values {
                guard sessionController?.session.id == session.id else {
                    return
                }
                if case .invalidated = state {
                    sessionController = nil
                    detachTransport()
                    return
                }
            }
        }
    }

    // MARK: - Local card updates

    func setCardState(
        _ cardID: ClinicalCardID,
        isExpanded: Bool,
        syncChanges: Bool
    ) {
        let previousSelections = sharedCardState.abbreviationSelections
        sharedCardState.setExpansionState(isExpanded, for: cardID)
        recordDisconnectedAbbreviationChanges(from: previousSelections)

        if syncChanges {
            broadcastCardAction(
                .toggle(isExpanded: isExpanded),
                for: cardID
            )
        }
    }

    func setCardPosition(
        _ cardID: ClinicalCardID,
        position: SIMD3<Float>,
        syncChanges: Bool
    ) {
        sharedCardState.setPosition(position, for: cardID)

        if syncChanges {
            broadcastCardAction(.move(position: position), for: cardID)
        }
    }

    private func broadcastCardAction(
        _ action: CardAction,
        for cardID: ClinicalCardID
    ) {
        guard let updateCount = nextUpdateCount(
            after: cardUpdateCounts[cardID]
        ) else {
            return
        }

        cardUpdateCounts[cardID] = updateCount
        let message = CardSyncMessage(
            cardID: cardID,
            action: action,
            updateCount: updateCount
        )

        transport?.sendMessage(message)
    }

    // MARK: - Local abbreviation updates

    func toggleAbbreviationSelection(
        _ selection: AbbreviationSelection,
        for cardID: ClinicalCardID
    ) {
        guard let action = sharedCardState.toggleAbbreviationSelection(
            selection,
            for: cardID
        ) else {
            return
        }

        guard transport != nil else {
            disconnectedAbbreviationChanges.insert(cardID)
            return
        }

        guard let updateCount = nextUpdateCount(
            after: abbreviationUpdateCounts[cardID]
        ) else {
            return
        }

        abbreviationUpdateCounts[cardID] = updateCount
        transport?.sendMessage(
            AbbreviationSyncMessage(
                cardID: cardID,
                action: action,
                updateCount: updateCount
            )
        )
    }

    // MARK: - Local orbit updates

    func setOrbitEnabled(_ isEnabled: Bool, orderedCardNames: [String]) {
#if DEBUG
        print(
            "[OrbitDebug] setOrbitEnabled(\(isEnabled)); "
                + "orderedCards=\(orderedCardNames), "
                + "previousState=\(sharedCardState.orbitState.interactionMode)"
        )
#endif
        orbitExpansionTask?.cancel()
        let state: OrbitState
        if isEnabled {
            guard !sharedCardState.orbitState.isActive else { return }
            state = OrbitState(
                interactionMode: .orbit,
                rotation: 0,
                focusedCardName: orderedCardNames.first,
                expandedCardName: nil
            )
        } else {
            guard sharedCardState.orbitState.isActive else { return }
            state = .inactive
        }

        applyLocalOrbitState(state, animationDuration: 0.45, isFinal: true)
        if isEnabled, let focusedCardName = state.focusedCardName {
            scheduleExpansion(of: focusedCardName, after: 0.45)
        }
    }

    func updateOrbitRotation(
        _ rotation: Float,
        orderedCardNames: [String],
        isFinal: Bool
    ) {
        guard sharedCardState.orbitState.isActive,
              !orderedCardNames.isEmpty else {
            return
        }

        orbitExpansionTask?.cancel()
        let index = focusedIndex(for: rotation, cardCount: orderedCardNames.count)
        var state = sharedCardState.orbitState
        state.expandedCardName = nil
        state.rotation = isFinal
            ? snappedRotation(
                near: rotation,
                focusedIndex: index,
                cardCount: orderedCardNames.count
            )
            : rotation
        state.focusedCardName = orderedCardNames[index]
        applyLocalOrbitState(
            state,
            animationDuration: isFinal ? 0.22 : 0,
            isFinal: isFinal
        )
        if isFinal, let focusedCardName = state.focusedCardName {
            scheduleExpansion(of: focusedCardName, after: 0.22)
        }
    }

    func focusOrbitCard(named cardName: String, orderedCardNames: [String]) {
        guard sharedCardState.orbitState.isActive,
              let index = orderedCardNames.firstIndex(of: cardName) else {
            return
        }

        orbitExpansionTask?.cancel()
        var state = sharedCardState.orbitState
        state.expandedCardName = nil
        state.rotation = snappedRotation(
            near: state.rotation,
            focusedIndex: index,
            cardCount: orderedCardNames.count
        )
        state.focusedCardName = cardName
        applyLocalOrbitState(state, animationDuration: 0.3, isFinal: true)
        scheduleExpansion(of: cardName, after: 0.3)
    }

    func toggleFocusedOrbitCardExpansion() {
        orbitExpansionTask?.cancel()
        var state = sharedCardState.orbitState
        guard state.isActive, let focusedCardName = state.focusedCardName else {
            return
        }

        state.expandedCardName = state.expandedCardName == nil
            ? focusedCardName
            : nil
        applyLocalOrbitState(state, animationDuration: 0.3, isFinal: true)
    }

    func moveOrbitFocus(by offset: Int, orderedCardNames: [String]) {
        guard sharedCardState.orbitState.isActive,
              !orderedCardNames.isEmpty else {
            return
        }

        let currentIndex = sharedCardState.orbitState.focusedCardName
            .flatMap(orderedCardNames.firstIndex(of:))
            ?? focusedIndex(
                for: sharedCardState.orbitState.rotation,
                cardCount: orderedCardNames.count
            )
        let destination = positiveModulo(currentIndex + offset, orderedCardNames.count)
        focusOrbitCard(named: orderedCardNames[destination], orderedCardNames: orderedCardNames)
    }

    private func scheduleExpansion(of cardName: String, after delay: TimeInterval) {
        orbitExpansionTask?.cancel()
        orbitExpansionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(delay * 1_000)))
            guard !Task.isCancelled, let self else { return }

            var state = sharedCardState.orbitState
            guard state.isActive,
                  state.focusedCardName == cardName,
                  state.expandedCardName == nil else {
                return
            }

            state.expandedCardName = cardName
            applyLocalOrbitState(
                state,
                animationDuration: 0.25,
                isFinal: true
            )
        }
    }

    private func applyLocalOrbitState(
        _ state: OrbitState,
        animationDuration: TimeInterval,
        isFinal: Bool
    ) {
        let previousSelections = sharedCardState.abbreviationSelections
        sharedCardState.setOrbitState(state, animationDuration: animationDuration)
        recordDisconnectedAbbreviationChanges(from: previousSelections)

        let now = Date()
        guard isFinal || now.timeIntervalSince(lastOrbitBroadcastTime) >= 0.05 else {
            return
        }
        lastOrbitBroadcastTime = now
        broadcastOrbitState(state, isFinal: isFinal)
    }

    private func broadcastOrbitState(_ state: OrbitState, isFinal: Bool) {
        guard let updateCount = nextUpdateCount(after: orbitUpdateCount) else {
            return
        }

        orbitUpdateCount = updateCount
        let message = OrbitSyncMessage(
            state: state,
            updateCount: updateCount,
            isFinal: isFinal
        )
        transport?.sendMessage(message)
    }

    private func focusedIndex(for rotation: Float, cardCount: Int) -> Int {
        let slotAngle = (2 * Float.pi) / Float(cardCount)
        return positiveModulo(Int(round(-rotation / slotAngle)), cardCount)
    }

    private func snappedRotation(
        near currentRotation: Float,
        focusedIndex: Int,
        cardCount: Int
    ) -> Float {
        let fullTurn = 2 * Float.pi
        let slotAngle = fullTurn / Float(cardCount)
        let baseRotation = -Float(focusedIndex) * slotAngle
        let turns = round((currentRotation - baseRotation) / fullTurn)
        return baseRotation + turns * fullTurn
    }

    private func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        let remainder = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }

    // MARK: - Local dashboard updates

    @discardableResult
    func moveDashboardSection(
        _ dragged: SectionID,
        toPositionOf destination: SectionID,
        syncChanges: Bool
    ) -> Bool {
        guard handoverViewModel.moveSection(
            dragged,
            toPositionOf: destination
        ) else {
            return false
        }

        if syncChanges {
            broadcastDashboardAction(
                .sectionOrder(handoverViewModel.sectionOrder)
            )
        }
        return true
    }

    func selectPatient(id: String, syncChanges: Bool) {
        let previousSelections = sharedCardState.abbreviationSelections
        selectPatientAndClearAbbreviations(id: id)
        recordDisconnectedAbbreviationChanges(from: previousSelections)

        if syncChanges {
            broadcastDashboardAction(.selectedPatient(id: id))
        }
    }

    private func broadcastDashboardAction(_ action: DashboardAction) {
        guard let updateCount = nextUpdateCount(
            after: dashboardUpdateCount
        ) else {
            return
        }

        dashboardUpdateCount = updateCount
        let message = DashboardSyncMessage(
            action: action,
            updateCount: updateCount
        )

        transport?.sendMessage(message)
    }

    private func nextUpdateCount(
        after existingCount: MessageUpdateCount?
    ) -> MessageUpdateCount? {
        guard let participantID = transport?.localParticipantID else {
            return nil
        }

        return MessageUpdateCount(
            count: (existingCount?.count ?? 0) + 1,
            participant: participantID
        )
    }

    func attachTransport(_ transport: any SharePlayMessageTransport) {
        self.transport = transport
        synchronizeExistingAbbreviationSelections()
    }

    func detachTransport() {
        transport = nil
    }

    private func synchronizeExistingAbbreviationSelections() {
        guard let participantID = transport?.localParticipantID else { return }

        let cardIDs = Set(sharedCardState.abbreviationSelections.keys)
            .union(disconnectedAbbreviationChanges)
        for cardID in cardIDs {
            let wasChangedWhileDisconnected =
                disconnectedAbbreviationChanges.contains(cardID)
            guard wasChangedWhileDisconnected
                    || abbreviationUpdateCounts[cardID] == nil else {
                continue
            }

            let updateCount = MessageUpdateCount(
                count: (abbreviationUpdateCounts[cardID]?.count ?? 0) + 1,
                participant: participantID
            )
            abbreviationUpdateCounts[cardID] = updateCount
            transport?.sendMessage(
                AbbreviationSyncMessage(
                    cardID: cardID,
                    action: .set(
                        sharedCardState.abbreviationSelections[cardID]
                    ),
                    updateCount: updateCount
                )
            )
            disconnectedAbbreviationChanges.remove(cardID)
        }
    }

    private func recordDisconnectedAbbreviationChanges(
        from previousSelections: [ClinicalCardID: AbbreviationSelection]
    ) {
        guard transport == nil else { return }

        let cardIDs = Set(previousSelections.keys)
            .union(sharedCardState.abbreviationSelections.keys)
        for cardID in cardIDs
        where previousSelections[cardID]
            != sharedCardState.abbreviationSelections[cardID] {
            disconnectedAbbreviationChanges.insert(cardID)
        }
    }

    // MARK: - Remote updates

    func handleRemoteCardMessage(_ message: CardSyncMessage) {
        if let existingCount = cardUpdateCounts[message.cardID],
           message.updateCount <= existingCount {
            return
        }

        cardUpdateCounts[message.cardID] = message.updateCount
        sharedCardState.apply(message.action, to: message.cardID)
    }

    func handleRemoteAbbreviationMessage(
        _ message: AbbreviationSyncMessage
    ) {
        if let existingCount = abbreviationUpdateCounts[message.cardID],
           message.updateCount <= existingCount {
            return
        }

        abbreviationUpdateCounts[message.cardID] = message.updateCount
        sharedCardState.apply(message.action, to: message.cardID)
    }

    func handleRemoteOrbitMessage(_ message: OrbitSyncMessage) {
        if let existingCount = orbitUpdateCount,
           message.updateCount <= existingCount {
            return
        }

        orbitUpdateCount = message.updateCount
        sharedCardState.setOrbitState(
            message.state,
            animationDuration: message.isFinal ? 0.22 : 0.08
        )
    }

    func handleRemoteDashboardMessage(_ message: DashboardSyncMessage) {
        if let existingCount = dashboardUpdateCount,
           message.updateCount <= existingCount {
            return
        }

        dashboardUpdateCount = message.updateCount

        switch message.action {
        case .state(let dashboardState):
            let previousPatientID = handoverViewModel.patient?.id
            handoverViewModel.applyDashboardState(dashboardState)
            clearAbbreviationsIfPatientChanged(from: previousPatientID)
        case .selectedPatient(let id):
            selectPatientAndClearAbbreviations(id: id)
        case .sectionOrder(let sectionOrder):
            handoverViewModel.applySectionOrder(sectionOrder)
        }
    }

    func applyCatchUpMessage(_ message: CatchUpMessage) {
        let cardSnapshot = mergedCardSnapshot(with: message)
        let orbitSnapshot = mergedOrbitSnapshot(with: message)
        let changesPatient = message.dashboardState.selectedPatientID.map {
            $0 != handoverViewModel.patient?.id
        } ?? false
        let abbreviationSnapshot = mergedAbbreviationSnapshot(
            with: message,
            preservingCurrentState: !changesPatient
        )
        handoverViewModel.applyDashboardState(message.dashboardState)
        sharedCardState.replaceAll(
            expansionStates: cardSnapshot.expansionStates,
            positions: cardSnapshot.positions,
            abbreviationSelections: abbreviationSnapshot.selections,
            orbitState: orbitSnapshot.state
        )
        cardUpdateCounts = cardSnapshot.updateCounts
        abbreviationUpdateCounts = abbreviationSnapshot.updateCounts
        orbitUpdateCount = orbitSnapshot.updateCount
        dashboardUpdateCount = message.dashboardUpdateCount
    }

    func sendCatchUp(to participantIDs: Set<Participant.ID>) {
        guard !participantIDs.isEmpty else { return }
        transport?.sendMessage(
            makeCatchUpMessage(),
            to: participantIDs
        )
    }

    func makeCatchUpMessage() -> CatchUpMessage {
        CatchUpMessage(
            allCardStates: sharedCardState.expansionStates,
            allCardPositions: sharedCardState.positions,
            cardUpdateCounts: cardUpdateCounts,
            abbreviationSelections: sharedCardState.abbreviationSelections,
            abbreviationUpdateCounts: abbreviationUpdateCounts,
            orbitState: sharedCardState.orbitState,
            orbitUpdateCount: orbitUpdateCount,
            dashboardState: DashboardState(
                selectedPatientID: handoverViewModel.patient?.id,
                sectionOrder: handoverViewModel.sectionOrder
            ),
            dashboardUpdateCount: dashboardUpdateCount
        )
    }

    private func mergedAbbreviationSnapshot(
        with message: CatchUpMessage,
        preservingCurrentState: Bool
    ) -> (
        selections: [ClinicalCardID: AbbreviationSelection],
        updateCounts: [ClinicalCardID: MessageUpdateCount]
    ) {
        var selections = preservingCurrentState
            ? sharedCardState.abbreviationSelections
            : [:]
        var updateCounts = preservingCurrentState
            ? abbreviationUpdateCounts
            : [:]

        for (cardID, incomingCount) in message.abbreviationUpdateCounts {
            if let currentCount = updateCounts[cardID],
               incomingCount <= currentCount {
                continue
            }

            updateCounts[cardID] = incomingCount
            selections[cardID] = message.abbreviationSelections[cardID]
        }

        return (selections, updateCounts)
    }

    private func mergedCardSnapshot(
        with message: CatchUpMessage
    ) -> (
        expansionStates: [ClinicalCardID: Bool],
        positions: [ClinicalCardID: SIMD3<Float>],
        updateCounts: [ClinicalCardID: MessageUpdateCount]
    ) {
        var expansionStates = sharedCardState.expansionStates
        var positions = sharedCardState.positions
        var updateCounts = cardUpdateCounts

        for (cardID, incomingCount) in message.cardUpdateCounts {
            if let currentCount = updateCounts[cardID],
               incomingCount <= currentCount {
                continue
            }

            updateCounts[cardID] = incomingCount
            expansionStates[cardID] = message.allCardStates[cardID]
            positions[cardID] = message.allCardPositions[cardID]
        }

        for (cardID, isExpanded) in message.allCardStates
        where updateCounts[cardID] == nil
            && expansionStates[cardID] == nil {
            expansionStates[cardID] = isExpanded
        }
        for (cardID, position) in message.allCardPositions
        where updateCounts[cardID] == nil
            && positions[cardID] == nil {
            positions[cardID] = position
        }

        return (expansionStates, positions, updateCounts)
    }

    private func mergedOrbitSnapshot(
        with message: CatchUpMessage
    ) -> (state: OrbitState, updateCount: MessageUpdateCount?) {
        guard let incomingCount = message.orbitUpdateCount else {
            return orbitUpdateCount == nil
                ? (message.orbitState, nil)
                : (sharedCardState.orbitState, orbitUpdateCount)
        }
        if let currentCount = orbitUpdateCount,
           incomingCount <= currentCount {
            return (sharedCardState.orbitState, orbitUpdateCount)
        }
        return (message.orbitState, incomingCount)
    }

    private func selectPatientAndClearAbbreviations(id: String) {
        let previousPatientID = handoverViewModel.patient?.id
        handoverViewModel.selectPatient(byID: id)
        clearAbbreviationsIfPatientChanged(from: previousPatientID)
    }

    private func clearAbbreviationsIfPatientChanged(
        from previousPatientID: String?
    ) {
        if handoverViewModel.patient?.id != previousPatientID {
            sharedCardState.clearAbbreviationSelections()
        }
    }
}
