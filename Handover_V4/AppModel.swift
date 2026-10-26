// Flow: LauncherView + ImmersiveView + PatientDashboardView -> AppModel -> OrbitController + SharedHandoverReplica -> SessionController.
//
//  AppModel.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//

import Foundation
import GroupActivities
import Observation
import Combine

/// Owns what the handover shows and keeps it identical for every SharePlay participant.
///
/// Views change state here directly. Any change to `currentSnapshot` is noticed through
/// observation and sent to peers, so call sites need no SharePlay code; snapshots from
/// peers are applied through the same properties.
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

    /// Whether the ICU should be open. ToggleImmersiveSpaceButton opens or dismisses
    /// the space to match, so a peer entering or leaving brings everyone along.
    var wantsImmersion = false

    var presentationMode = PresentationMode.dashboard {
        didSet {
            guard oldValue != presentationMode else { return }
            enter(presentationMode)
        }
    }
    let orbit = OrbitController()
    /// Spatial cards default to expanded; only collapsed ones are recorded.
    var collapsedSpatialCards: Set<String> = []
    var dashboard = DashboardPresentationState()
    var dashboardOrder = DashboardBoardState()

    let handoverViewModel: HandoverViewModel
    let patients = PatientDataLoader.loadOrEmpty()

    init(initialBedNumber: String = "BED-02") {
        handoverViewModel = HandoverViewModel(initialBedNumber: initialBedNumber)
        Task(name: "group session observation") {
            await observeGroupSessions()
        }
        observeLocalChanges()
    }

    // MARK: - Presentation

    /// Every entry into a mode starts from its own disclosure: Spatial and Dashboard fully
    /// expanded, Orbit on Situation. The person switching shares the result, so peers
    /// receive the reset rather than each resetting on join.
    private func enter(_ mode: PresentationMode) {
        if mode == .orbit {
            orbit.enter()
        } else {
            orbit.leave()
        }
        switch mode {
        case .spatial: collapsedSpatialCards = []
        case .dashboard: dashboard = DashboardPresentationState()
        case .orbit: break
        }
    }

    /// Basic Information is always open; Orbit shows only its front card.
    func isCardExpanded(_ name: String) -> Bool {
        if name == "Basic_Information" { return true }
        if presentationMode == .orbit {
            return orbit.state.expandedCard?.rawValue == name
        }
        return !collapsedSpatialCards.contains(name)
    }

    func setSpatialCard(_ name: String, isExpanded: Bool) {
        if isExpanded {
            collapsedSpatialCards.remove(name)
        } else {
            collapsedSpatialCards.insert(name)
        }
    }

    /// SBAR rail: expands every card in the group if any are collapsed, otherwise collapses them all.
    func toggleSBARGroup(_ group: SBARGroup) {
        toggleSpatialCards(group.poiNames)
    }

    /// SBAR rail's ALL button: same all-or-nothing rule across every Spatial card group.
    /// Basic Information isn't part of any group, so it's untouched.
    func toggleAllSpatialCards() {
        toggleSpatialCards(SBARGroup.allCases.flatMap(\.poiNames))
    }

    private func toggleSpatialCards(_ names: [String]) {
        let allExpanded = collapsedSpatialCards.isDisjoint(with: names)
        for name in names {
            setSpatialCard(name, isExpanded: !allExpanded)
        }
    }

    /// Called once the ICU geometry exists. Orbit starts on Situation, or joins the
    /// card the group is already on so opening the space never moves anyone else.
    func immersiveSceneDidLoad() {
        guard presentationMode == .orbit else { return }
        orbit.enter()
        if replica.isActive, let target = replica.shared.orbit {
            orbit.adopt(target)
        }
    }

    /// Records the space closing. Closing it from outside the app counts as everyone leaving,
    /// while a close this app requested has already updated `wantsImmersion`.
    func immersiveSpaceDidClose() {
        if immersiveSpaceState == .open {
            wantsImmersion = false
        }
        immersiveSpaceState = .closed
    }

    // MARK: - SharePlay

    private var sessionController: SessionController?
    private var replica = SharedHandoverReplica()
    var isActivatingSharePlay = false
    var sharePlayErrorMessage: String?

    var isSharePlayActive: Bool {
        sessionController != nil
    }

    /// The facts peers share, read from live state. An Orbit drag that has not been released
    /// keeps the last shared card, so peers move only once a card is chosen.
    var currentSnapshot: SharedHandoverSnapshot {
        SharedHandoverSnapshot(
            isImmersed: wantsImmersion,
            mode: presentationMode,
            orbit: presentationMode == .orbit ? (orbit.state.target ?? replica.shared.orbit) : nil,
            collapsedSpatialCards: collapsedSpatialCards,
            dashboard: dashboard,
            dashboardOrder: dashboardOrder
        )
    }

    var catchUpMessage: SharedHandoverMessage? {
        replica.catchUp
    }

    /// Leaves SharePlay on this device; the others carry on together.
    func leaveSharePlay() {
        sessionController?.leave()
    }

    /// Starts the group activity. Outside a FaceTime call, visionOS offers the Share menu,
    /// including nearby sharing with people in the same room.
    func activateSharePlay() async {
        guard !isSharePlayActive, !isActivatingSharePlay else { return }
        isActivatingSharePlay = true
        sharePlayErrorMessage = nil
        defer { isActivatingSharePlay = false }

        do {
            _ = try await SharePlayTogether().activate()
        } catch {
            sharePlayErrorMessage = "SharePlay could not be started: \(error.localizedDescription)"
        }
    }

    /// Applies a peer's snapshot when it is newer than this device's.
    func receive(_ message: SharedHandoverMessage) {
        guard let snapshot = replica.receive(message) else { return }
        wantsImmersion = snapshot.isImmersed
        // Set the mode first: entering it resets disclosure, which the snapshot then overrides.
        presentationMode = snapshot.mode
        collapsedSpatialCards = snapshot.collapsedSpatialCards
        dashboard = snapshot.dashboard
        dashboardOrder = snapshot.dashboardOrder
        if let target = snapshot.orbit {
            orbit.adopt(target)
        }
    }

    /// Sends local changes whenever the snapshot's inputs change. `Observations` delivers one
    /// value per main-actor transaction, so a mode switch and its resets go out as one snapshot.
    private func observeLocalChanges() {
        let snapshots = Observations { [weak self] in self?.currentSnapshot }
        Task { [weak self] in
            for await snapshot in snapshots {
                guard let self, let snapshot else { return }
                if let message = replica.localChange(snapshot) {
                    sessionController?.send(message)
                }
            }
        }
    }

    /// Listens for `SharePlayTogether` sessions for the app's lifetime, whether started here,
    /// from the Share menu, or by a nearby participant.
    private func observeGroupSessions() async {
        for await session in SharePlayTogether.sessions() {
            // Begin before the controller joins, so a catch-up that arrives right away is applied.
            replica.begin(participant: session.localParticipant.id, joinedAt: .now, snapshot: currentSnapshot)
            guard let sessionController = await SessionController(session, appModel: self) else {
                replica.end()
                continue
            }
            self.sessionController = sessionController

            Task.immediate(name: "session state observation") {
                for await state in session.$state.values {
                    guard self.sessionController?.session.id == session.id else {
                        return
                    }
                    if case .invalidated = state {
                        self.sessionController = nil
                        self.replica.end()
                        return
                    }
                }
            }
        }
    }
}
