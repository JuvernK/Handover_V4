//
//  SharedCardState.swift
//  Handover_V4
//

import Foundation
import Observation
import simd

enum CardInteractionMode: Codable, Equatable {
    case normal
    case orbit
}

struct OrbitState: Codable, Equatable {
    var interactionMode: CardInteractionMode = .normal
    var rotation: Float = 0
    var focusedCardName: String?
    var expandedCardName: String?

    var isActive: Bool {
        interactionMode == .orbit
    }

    static let inactive = OrbitState()
}

/// Owns the spatial cards' presentation state independently of SharePlay.
@Observable
@MainActor
final class SharedCardState {
    private(set) var expansionStates: [ClinicalCardID: Bool] = [:]
    private(set) var positions: [ClinicalCardID: SIMD3<Float>] = [:]
    private(set) var abbreviationSelections: [ClinicalCardID: AbbreviationSelection] = [:]
    private(set) var orbitState = OrbitState.inactive

    /// Controls how RealityKit presents the latest orbit state. This is local
    /// presentation metadata rather than synchronized application state.
    private(set) var orbitAnimationDuration: TimeInterval = 0

    func setExpansionState(_ isExpanded: Bool, for cardID: ClinicalCardID) {
        expansionStates[cardID] = isExpanded
        if !isExpanded {
            abbreviationSelections.removeValue(forKey: cardID)
        }
    }

    func setPosition(_ position: SIMD3<Float>, for cardID: ClinicalCardID) {
        positions[cardID] = position
    }

    @discardableResult
    func toggleAbbreviationSelection(
        _ selection: AbbreviationSelection,
        for cardID: ClinicalCardID
    ) -> AbbreviationAction? {
        guard isCardExpanded(cardID) else { return nil }

        let action = AbbreviationAction.set(
            abbreviationSelections[cardID] == selection ? nil : selection
        )
        apply(action, to: cardID)
        return action
    }

    func apply(_ action: AbbreviationAction, to cardID: ClinicalCardID) {
        switch action {
        case .set(let selection):
            setAbbreviationSelection(selection, for: cardID)
        }
    }

    func setAbbreviationSelection(
        _ selection: AbbreviationSelection?,
        for cardID: ClinicalCardID
    ) {
        guard isCardExpanded(cardID) else {
            abbreviationSelections.removeValue(forKey: cardID)
            return
        }
        abbreviationSelections[cardID] = selection
    }

    func clearAbbreviationSelections() {
        abbreviationSelections.removeAll()
    }

    func setOrbitState(_ state: OrbitState, animationDuration: TimeInterval) {
        if state.isActive && !orbitState.isActive {
            abbreviationSelections.removeAll()
        } else if
            let previouslyExpandedCard = orbitState.expandedCardName,
            state.expandedCardName != previouslyExpandedCard
        {
            if let cardID = ClinicalCardID(canonicalName: previouslyExpandedCard) {
                abbreviationSelections.removeValue(forKey: cardID)
            }
        }
        orbitAnimationDuration = animationDuration
        orbitState = state
    }

    func isCardExpanded(_ cardID: ClinicalCardID) -> Bool {
        if orbitState.isActive {
            return cardID == .basicInformation
                || orbitState.expandedCardName == cardID.canonicalName
        }
        return expansionStates[cardID] ?? true
    }
}
