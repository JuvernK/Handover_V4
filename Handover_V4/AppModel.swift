//
//  AppModel.swift
//  Handover_V4
//

import SwiftUI
import simd

/// Composes the app's feature state and preserves a small API for its views.
@MainActor
@Observable
final class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"

    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }

    var immersiveSpaceState = ImmersiveSpaceState.closed

    let handoverViewModel: HandoverViewModel
    let sharedCardState: SharedCardState
    let sharedHandoverReplicator: SharedHandoverReplicator
    let sharePlayCoordinator: SharePlayCoordinator
    let orbitController: OrbitController
    var orbitGestureWorldToLocal = matrix_identity_float4x4

    init(initialBedNumber: String = "BED-03") {
        let handoverViewModel = HandoverViewModel(
            initialBedNumber: initialBedNumber
        )
        let sharedCardState = SharedCardState()

        self.handoverViewModel = handoverViewModel
        self.sharedCardState = sharedCardState
        let sharedHandoverReplicator = SharedHandoverReplicator(
            sharedCardState: sharedCardState,
            handoverViewModel: handoverViewModel
        )
        self.sharedHandoverReplicator = sharedHandoverReplicator
        let sharePlayCoordinator = SharePlayCoordinator(
            replicator: sharedHandoverReplicator
        )
        self.sharePlayCoordinator = sharePlayCoordinator
        orbitController = OrbitController(
            currentState: { sharedCardState.orbitState },
            orderedCardNames: {
                handoverViewModel.sectionOrder.map(\.rawValue)
            },
            apply: { transition in
                sharedHandoverReplicator.transact(.setOrbit(transition))
            }
        )
        sharePlayCoordinator.startObservingSessions()
    }

    // MARK: - SharePlay presentation

    var isSharePlayActive: Bool {
        sharePlayCoordinator.isActive
    }

    var isActivatingSharePlay: Bool {
        sharePlayCoordinator.isActivating
    }

    var sharePlayErrorMessage: String? {
        get { sharePlayCoordinator.errorMessage }
        set { sharePlayCoordinator.errorMessage = newValue }
    }

    func activateSharePlay() async {
        await sharePlayCoordinator.activate()
    }

    func endSession() {
        sharePlayCoordinator.endSession()
    }

    // MARK: - Shared card state

    var cardStates: [ClinicalCardID: Bool] {
        sharedCardState.expansionStates
    }

    var cardPositions: [ClinicalCardID: SIMD3<Float>] {
        sharedCardState.positions
    }

    var abbreviationSelections: [ClinicalCardID: AbbreviationSelection] {
        sharedCardState.abbreviationSelections
    }

    func abbreviationSelection(
        for cardID: ClinicalCardID
    ) -> AbbreviationSelection? {
        abbreviationSelections[cardID]
    }

    var orbitState: OrbitState {
        sharedCardState.orbitState
    }

    var orbitAnimationDuration: TimeInterval {
        sharedCardState.orbitAnimationDuration
    }

    var orbitCardNames: [String] {
        handoverViewModel.sectionOrder.map(\.rawValue)
    }

    func setCardState(
        _ cardID: ClinicalCardID,
        isExpanded: Bool
    ) {
        sharedHandoverReplicator.transact(
            .setCardExpansion(cardID, isExpanded: isExpanded)
        )
    }

    func setCardPosition(
        _ cardID: ClinicalCardID,
        position: SIMD3<Float>
    ) {
        sharedHandoverReplicator.transact(.moveCard(cardID, to: position))
    }

    func toggleAbbreviationSelection(
        _ selection: AbbreviationSelection,
        for cardID: ClinicalCardID
    ) {
        sharedHandoverReplicator.transact(
            .toggleAbbreviation(selection, in: cardID)
        )
    }

    func setOrbitEnabled(_ isEnabled: Bool) {
        orbitController.perform(.setEnabled(isEnabled))
    }

    func updateOrbitRotation(_ rotation: Float, isFinal: Bool) {
        orbitController.perform(
            .updateRotation(rotation, isFinal: isFinal)
        )
    }

    func focusOrbitCard(named cardName: String) {
        orbitController.perform(.focusCard(named: cardName))
    }

    func toggleFocusedOrbitCardExpansion() {
        orbitController.perform(.toggleFocusedExpansion)
    }

    func moveOrbitFocus(by offset: Int) {
        orbitController.perform(.moveFocus(by: offset))
    }

    // MARK: - Shared dashboard state

    @discardableResult
    func moveDashboardSection(
        _ dragged: SectionID,
        toPositionOf destination: SectionID
    ) -> Bool {
        sharedHandoverReplicator.transact(
            .moveDashboardSection(dragged, toPositionOf: destination)
        )
    }
}
