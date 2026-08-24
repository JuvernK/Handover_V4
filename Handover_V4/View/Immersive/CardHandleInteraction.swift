//
//  CardHandleInteraction.swift
//  Handover_V4
//

import Foundation

/// Per-touch state for a Spatial Card's Card Handle, tracked from a touch's
/// first movement to its end. Grouped into one value so a completed or
/// abandoned touch is cleared with a single assignment.
struct CardTouchState {
    let startPosition: SIMD3<Float>
    let isEligibleForToggle: Bool
    var isDragConfirmed = false
}

/// What a Spatial Card's touch should do once it ends.
enum CardTouchOutcome: Equatable {
    case moved(SIMD3<Float>)
    case toggled
    case none
}

/// Pure tap-vs-drag-vs-toggle decision logic for the Card Handle, factored
/// out of `SpatialCardGestureModifier` so it can be exercised without a live
/// gesture, entity, or `AppModel`.
enum CardHandleInteraction {
    /// Whether accumulated movement is enough to treat this touch as a
    /// deliberate drag rather than tap jitter. Latches: once confirmed, stays
    /// confirmed even if `distance` later drops back below `threshold`.
    static func isDragConfirmed(
        distance: Float,
        alreadyConfirmed: Bool,
        threshold: Float
    ) -> Bool {
        alreadyConfirmed || distance >= threshold
    }

    /// Resolves what a completed touch should do: a confirmed drag commits
    /// its new position, an unconfirmed drag that started inside the Card
    /// Handle strip falls back to toggling expansion (the drag gesture won
    /// the tap arena against the header's own Button), anything else is a
    /// no-op.
    static func resolveOutcome(
        for state: CardTouchState,
        entityPosition: SIMD3<Float>
    ) -> CardTouchOutcome {
        if state.isDragConfirmed {
            return .moved(entityPosition)
        }
        if state.isEligibleForToggle {
            return .toggled
        }
        return .none
    }
}
