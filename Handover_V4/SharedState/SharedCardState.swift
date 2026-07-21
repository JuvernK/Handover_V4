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
    private(set) var orbitState = OrbitState.inactive

    /// Controls how RealityKit presents the latest orbit state. This is local
    /// presentation metadata rather than synchronized application state.
    private(set) var orbitAnimationDuration: TimeInterval = 0

    func setExpansionState(_ isExpanded: Bool, for cardName: String) {
        expansionStates[cardName] = isExpanded
    }

    func setPosition(_ position: SIMD3<Float>, for cardName: String) {
        positions[cardName] = position
    }

    func setOrbitState(_ state: OrbitState, animationDuration: TimeInterval) {
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
        setOrbitState(orbitState, animationDuration: 0.35)
    }
}
