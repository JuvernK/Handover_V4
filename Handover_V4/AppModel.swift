//
//  AppModel.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//

import SwiftUI
import GroupActivities
import Combine

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed

    let handoverViewModel: HandoverViewModel
    let patients = PatientDataLoader.loadOrEmpty()
    var isActivatingSharePlay = false
    var sharePlayErrorMessage: String?

    init(initialBedNumber: String = "BED-02") {
        handoverViewModel = HandoverViewModel(initialBedNumber: initialBedNumber)
//        // Temporary debug code to test decoding
//        print("Loaded \(patients.count) patients")
//        for p in patients {
//            print("• \(p.bedNumber): \(p.name) — \(p.initials)")
//        }
        Task(name: "group session observation") {
            await observeGroupSessions()
        }
    }

    // MARK: - Set up SharePlay
    private var sessionController: SessionController?

    /// Returns whether a SharePlay session is currently active.
    var isSharePlayActive: Bool {
        sessionController != nil
    }

    /// Ends the current SharePlay session if one is active.
    func endSession() {
        sessionController?.endSession()
    }

    /// Starts the SharePlay group activity. In FaceTime this joins the active call;
    /// outside FaceTime the system may ask the user how they want to share.
    func activateSharePlay() async {
        guard !isSharePlayActive, !isActivatingSharePlay else { return }

        isActivatingSharePlay = true
        sharePlayErrorMessage = nil
        defer { isActivatingSharePlay = false }

        let activity = SharePlayTogether()
        switch await activity.prepareForActivation() {
        case .activationPreferred:
            do {
                _ = try await activity.activate()
            } catch {
                sharePlayErrorMessage = "SharePlay could not be started: \(error.localizedDescription)"
            }

        case .activationDisabled:
            sharePlayErrorMessage = "Start or join a FaceTime call before starting SharePlay."

        case .cancelled:
            break

        @unknown default:
            sharePlayErrorMessage = "SharePlay is not available right now."
        }
    }

    /// Observes the life cycle of SharePlay group sessions.
    /// This method listens for new `SharePlayTogether` sessions and manages their life cycles.
    /// The method runs continuously in a background task and the system calls it only once during initialization.
    private func observeGroupSessions() async {
        for await session in SharePlayTogether.sessions() {
            let sessionController = await SessionController(session, appModel: self)
            guard let sessionController else { // Safely store session
                continue
            }
            self.sessionController = sessionController

            // Create a task to observe the group session state and clear the
            // session controller when the group session invalidates.
            Task.immediate(name: "session state observation") {
                for await state in session.$state.values {
                    // Safety check for active session before new one created
                    guard self.sessionController?.session.id == session.id else {
                        return
                    }
                    if case .invalidated = state {
                        self.sessionController = nil
                        return
                    }
                }
            }
        }
    }

    // MARK: - Card State Management

    // State Dictionaries
    // TODO: Reconcile spatial disclosure with the future shared presentation state so participants see matching card states.
    var cardStates: [String: Bool] = [:]
    var cardPositions: [String: SIMD3<Float>] = [:]

    // update counts to prevent race conditions
    private var cardUpdateCounts: [String: MessageUpdateCount] = [:]
    private var dashboardUpdateCount: MessageUpdateCount?

    var currentDashboardState: DashboardState {
        DashboardState(
            selectedPatientID: handoverViewModel.patient?.id,
            sectionOrder: handoverViewModel.sectionOrder
        )
    }

    func makeCatchUpMessage() -> CatchUpMessage {
        CatchUpMessage(
            allCardStates: cardStates,
            allCardPositions: cardPositions,
            cardUpdateCounts: cardUpdateCounts,
            dashboardState: currentDashboardState,
            dashboardUpdateCount: dashboardUpdateCount
        )
    }

    // MARK: - Local Updates  (SELF)
    func setCardState(name: String, isExpanded: Bool, syncChanges: Bool) {
        cardStates[name] = isExpanded

        if syncChanges {
            incrementAndBroadcast(name: name, action: .toggle(isExpanded: isExpanded))
        }
    }

    func setCardPosition(name: String, position: SIMD3<Float>, syncChanges: Bool) {
        cardPositions[name] = position

        if syncChanges {
            incrementAndBroadcast(name: name, action: .move(position: position))
        }
    }

    // Helper to handle the counter logic and send the message
    /// Seal message and counter into CardSyncMessage type and send via SessionController
    private func incrementAndBroadcast(name: String, action: CardAction) {

        guard let newUpdateCount = nextUpdateCount(after: cardUpdateCounts[name]) else { return }
        cardUpdateCounts[name] = newUpdateCount // Save our new count locally

        let message = CardSyncMessage(cardName: name, action: action, updateCount: newUpdateCount)

        Task {
            await sessionController?.sendMessage(message)
        }
    }

    @discardableResult
    func moveDashboardSection(_ dragged: SectionID, toPositionOf destination: SectionID, syncChanges: Bool) -> Bool {
        guard handoverViewModel.moveSection(dragged, toPositionOf: destination) else { return false }

        if syncChanges {
            incrementAndBroadcastDashboard(action: .sectionOrder(handoverViewModel.sectionOrder))
        }

        return true
    }

    func selectPatient(id: String, syncChanges: Bool) {
        handoverViewModel.selectPatient(byID: id)

        if syncChanges {
            incrementAndBroadcastDashboard(action: .selectedPatient(id: id))
        }
    }

    private func incrementAndBroadcastDashboard(action: DashboardAction) {
        guard let newUpdateCount = nextUpdateCount(after: dashboardUpdateCount) else { return }
        dashboardUpdateCount = newUpdateCount

        let message = DashboardSyncMessage(action: action, updateCount: newUpdateCount)

        Task {
            await sessionController?.sendMessage(message)
        }
    }

    private func nextUpdateCount(after existingCount: MessageUpdateCount?) -> MessageUpdateCount? {
        guard let participantId = sessionController?.session.localParticipant.id else { return nil }

        return MessageUpdateCount(
            count: (existingCount?.count ?? 0) + 1,
            participant: participantId
        )
    }

    // MARK: - Remote Updates (Changes Other Participant)
    func handleRemoteSyncMessage(_ message: CardSyncMessage) {
        // 1. Check for race conditions. Ignore if our local record is newer than the incoming message.
        if let existingCount = cardUpdateCounts[message.cardName], message.updateCount <= existingCount {
            return
        }

        // 2. It's a valid new update. Save the new high score.
        cardUpdateCounts[message.cardName] = message.updateCount

        // 3. Apply the state change
        switch message.action {
        case .toggle(let isExpanded):
            cardStates[message.cardName] = isExpanded
        case .move(let position):
            cardPositions[message.cardName] = position
        }
    }

    func handleRemoteDashboardSyncMessage(_ message: DashboardSyncMessage) {
        if let existingCount = dashboardUpdateCount, message.updateCount <= existingCount {
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

    /// Replaces all card states (used for catch-up when joining late)
    func replaceAllSharedState(
        states: [String: Bool],
        positions: [String: SIMD3<Float>],
        cardUpdateCounts: [String: MessageUpdateCount],
        dashboardState: DashboardState,
        dashboardUpdateCount: MessageUpdateCount?
    ) {
        cardStates = states
        cardPositions = positions
        self.cardUpdateCounts = cardUpdateCounts
        self.dashboardUpdateCount = dashboardUpdateCount
        handoverViewModel.applyDashboardState(dashboardState)
    }
}
