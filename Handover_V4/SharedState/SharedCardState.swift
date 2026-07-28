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
    private(set) var expansionStates: [String: Bool] = [:]
    private(set) var positions: [String: SIMD3<Float>] = [:]
    private(set) var abbreviationSelections: [String: AbbreviationSelection] = [:]
    private(set) var orbitState = OrbitState.inactive

    /// Controls how RealityKit presents the latest orbit state. This is local
    /// presentation metadata rather than synchronized application state.
    private(set) var orbitAnimationDuration: TimeInterval = 0

    func setExpansionState(_ isExpanded: Bool, for cardName: String) {
        expansionStates[cardName] = isExpanded
        if !isExpanded {
            abbreviationSelections.removeValue(forKey: cardName)
        }
    }

    func setPosition(_ position: SIMD3<Float>, for cardName: String) {
        positions[cardName] = position
    }

    func toggleAbbreviationSelection(
        _ selection: AbbreviationSelection,
        for cardName: String
    ) {
        if abbreviationSelections[cardName] == selection {
            abbreviationSelections.removeValue(forKey: cardName)
        } else {
            abbreviationSelections[cardName] = selection
        }
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
            abbreviationSelections.removeValue(forKey: previouslyExpandedCard)
        }
        orbitAnimationDuration = animationDuration
        orbitState = state
    }

    func apply(_ action: CardAction, to cardName: String) {
        switch action {
        case .toggle(let isExpanded):
            setExpansionState(isExpanded, for: cardName)
        case .move(let position):
            setPosition(position, for: cardName)
        }
    }

    func replaceAll(
        expansionStates: [String: Bool],
        positions: [String: SIMD3<Float>],
        orbitState: OrbitState
    ) {
        self.expansionStates = expansionStates
        self.positions = positions
        abbreviationSelections = abbreviationSelections.filter {
            expansionStates[$0.key] != false
        }
        setOrbitState(orbitState, animationDuration: 0.35)
    }
}
