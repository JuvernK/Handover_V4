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
    let sharePlayCoordinator: SharePlayCoordinator
    var orbitGestureWorldToLocal = matrix_identity_float4x4

    init(initialBedNumber: String = "BED-03") {
        let handoverViewModel = HandoverViewModel(
            initialBedNumber: initialBedNumber
        )
        let sharedCardState = SharedCardState()

        self.handoverViewModel = handoverViewModel
        self.sharedCardState = sharedCardState
        sharePlayCoordinator = SharePlayCoordinator(
            handoverViewModel: handoverViewModel,
            sharedCardState: sharedCardState
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

    var cardStates: [String: Bool] {
        sharedCardState.expansionStates
    }

    var cardPositions: [String: SIMD3<Float>] {
        sharedCardState.positions
    }

    var abbreviationSelections: [String: AbbreviationSelection] {
        sharedCardState.abbreviationSelections
    }

    func abbreviationSelection(for section: SectionID) -> AbbreviationSelection? {
        abbreviationSelections[section.rawValue]
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

    func setCardState(name: String, isExpanded: Bool, syncChanges: Bool) {
        sharePlayCoordinator.setCardState(
            name: name,
            isExpanded: isExpanded,
            syncChanges: syncChanges
        )
    }

    func setCardPosition(
        name: String,
        position: SIMD3<Float>,
        syncChanges: Bool
    ) {
        sharePlayCoordinator.setCardPosition(
            name: name,
            position: position,
            syncChanges: syncChanges
        )
    }

    func toggleAbbreviationSelection(
        _ selection: AbbreviationSelection,
        for section: SectionID
    ) {
        sharedCardState.toggleAbbreviationSelection(
            selection,
            for: section.rawValue
        )
    }

    func setOrbitEnabled(_ isEnabled: Bool) {
        sharePlayCoordinator.setOrbitEnabled(
            isEnabled,
            orderedCardNames: orbitCardNames
        )
    }

    func updateOrbitRotation(_ rotation: Float, isFinal: Bool) {
        sharePlayCoordinator.updateOrbitRotation(
            rotation,
            orderedCardNames: orbitCardNames,
            isFinal: isFinal
        )
    }

    func focusOrbitCard(named cardName: String) {
        sharePlayCoordinator.focusOrbitCard(
            named: cardName,
            orderedCardNames: orbitCardNames
        )
    }

    func toggleFocusedOrbitCardExpansion() {
        sharePlayCoordinator.toggleFocusedOrbitCardExpansion()
    }

    func moveOrbitFocus(by offset: Int) {
        sharePlayCoordinator.moveOrbitFocus(
            by: offset,
            orderedCardNames: orbitCardNames
        )
    }

    // MARK: - Shared dashboard state

    @discardableResult
    func moveDashboardSection(
        _ dragged: SectionID,
        toPositionOf destination: SectionID,
        syncChanges: Bool
    ) -> Bool {
        sharePlayCoordinator.moveDashboardSection(
            dragged,
            toPositionOf: destination,
            syncChanges: syncChanges
        )
    }

    func selectPatient(id: String, syncChanges: Bool) {
        sharePlayCoordinator.selectPatient(
            id: id,
            syncChanges: syncChanges
        )
    }
}
