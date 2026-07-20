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
    private var dashboardUpdateCount: MessageUpdateCount?
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
            positions: message.allCardPositions
        )
        cardUpdateCounts = message.cardUpdateCounts
        dashboardUpdateCount = message.dashboardUpdateCount
        handoverViewModel.applyDashboardState(message.dashboardState)
    }

    func makeCatchUpMessage() -> CatchUpMessage {
        CatchUpMessage(
            allCardStates: sharedCardState.expansionStates,
            allCardPositions: sharedCardState.positions,
            cardUpdateCounts: cardUpdateCounts,
            dashboardState: DashboardState(
                selectedPatientID: handoverViewModel.patient?.id,
                sectionOrder: handoverViewModel.sectionOrder
            ),
            dashboardUpdateCount: dashboardUpdateCount
        )
    }
}
