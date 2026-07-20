//
//  SharedCardState.swift
//  Handover_V4
//

import Observation
import simd

/// Owns the spatial cards' presentation state independently of SharePlay.
@Observable
@MainActor
final class SharedCardState {
    private(set) var expansionStates: [String: Bool] = [:]
    private(set) var positions: [String: SIMD3<Float>] = [:]

    func setExpansionState(_ isExpanded: Bool, for cardName: String) {
        expansionStates[cardName] = isExpanded
    }

    func setPosition(_ position: SIMD3<Float>, for cardName: String) {
        positions[cardName] = position
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
        positions: [String: SIMD3<Float>]
    ) {
        self.expansionStates = expansionStates
        self.positions = positions
    }
}
