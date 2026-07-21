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
    private var cardUpdateCounts: [String: MessageUpdateCount] = [:]
    private var orbitUpdateCount: MessageUpdateCount?
    private var dashboardUpdateCount: MessageUpdateCount?
    private var lastOrbitBroadcastTime = Date.distantPast
    private var orbitExpansionTask: Task<Void, Never>?
    private var isObservingSessions = false

    private(set) var isActivating = false
    var errorMessage: String?

    var isActive: Bool {
        sessionController != nil
    }

    init(
        handoverViewModel: HandoverViewModel,
        sharedCardState: SharedCardState
    ) {
        self.handoverViewModel = handoverViewModel
        self.sharedCardState = sharedCardState
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
        sessionController?.endSession()
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
                    return
                }
            }
        }
    }

    // MARK: - Local card updates

    func setCardState(name: String, isExpanded: Bool, syncChanges: Bool) {
        sharedCardState.setExpansionState(isExpanded, for: name)

        if syncChanges {
            broadcastCardAction(
                .toggle(isExpanded: isExpanded),
                for: name
            )
        }
    }

    func setCardPosition(
        name: String,
        position: SIMD3<Float>,
        syncChanges: Bool
    ) {
        sharedCardState.setPosition(position, for: name)

        if syncChanges {
            broadcastCardAction(.move(position: position), for: name)
        }
    }

    private func broadcastCardAction(_ action: CardAction, for cardName: String) {
        guard let updateCount = nextUpdateCount(
            after: cardUpdateCounts[cardName]
        ) else {
            return
        }

        cardUpdateCounts[cardName] = updateCount
        let message = CardSyncMessage(
            cardName: cardName,
            action: action,
            updateCount: updateCount
        )

        Task {
            await sessionController?.sendMessage(message)
        }
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
        sharedCardState.setOrbitState(state, animationDuration: animationDuration)

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
        Task {
            await sessionController?.sendMessage(message)
        }
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
        handoverViewModel.selectPatient(byID: id)

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

        Task {
            await sessionController?.sendMessage(message)
        }
    }

    private func nextUpdateCount(
        after existingCount: MessageUpdateCount?
    ) -> MessageUpdateCount? {
        guard let participantID = sessionController?.session.localParticipant.id else {
            return nil
        }

        return MessageUpdateCount(
            count: (existingCount?.count ?? 0) + 1,
            participant: participantID
        )
    }

    // MARK: - Remote updates

    func handleRemoteCardMessage(_ message: CardSyncMessage) {
        if let existingCount = cardUpdateCounts[message.cardName],
           message.updateCount <= existingCount {
            return
        }

        cardUpdateCounts[message.cardName] = message.updateCount
        sharedCardState.apply(message.action, to: message.cardName)
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
            handoverViewModel.applyDashboardState(dashboardState)
        case .selectedPatient(let id):
            handoverViewModel.selectPatient(byID: id)
        case .sectionOrder(let sectionOrder):
            handoverViewModel.applySectionOrder(sectionOrder)
        }
    }

    func applyCatchUpMessage(_ message: CatchUpMessage) {
        sharedCardState.replaceAll(
            expansionStates: message.allCardStates,
            positions: message.allCardPositions,
            orbitState: message.orbitState
        )
        cardUpdateCounts = message.cardUpdateCounts
        orbitUpdateCount = message.orbitUpdateCount
        dashboardUpdateCount = message.dashboardUpdateCount
        handoverViewModel.applyDashboardState(message.dashboardState)
    }

    func makeCatchUpMessage() -> CatchUpMessage {
        CatchUpMessage(
            allCardStates: sharedCardState.expansionStates,
            allCardPositions: sharedCardState.positions,
            cardUpdateCounts: cardUpdateCounts,
            orbitState: sharedCardState.orbitState,
            orbitUpdateCount: orbitUpdateCount,
            dashboardState: DashboardState(
                selectedPatientID: handoverViewModel.patient?.id,
                sectionOrder: handoverViewModel.sectionOrder
            ),
            dashboardUpdateCount: dashboardUpdateCount
        )
    }
}
