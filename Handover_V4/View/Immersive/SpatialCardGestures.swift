//
//  SpatialCardGestures.swift
//  Handover_V4
//

import SwiftUI
import RealityKit

private struct SpatialCardGestureModifier: ViewModifier {
    @Environment(AppModel.self) private var appModel
    @State private var dragStartPosition: SIMD3<Float>?
    @State private var isCardDragConfirmed = false
    @State private var orbitDragInterpreter = OrbitDragInterpreter()

    /// Real-world movement (metres) required before a touch on a card is
    /// treated as a deliberate drag rather than tap jitter. SwiftUI's
    /// DragGesture minimumDistance is measured in screen points before the
    /// 3D conversion below, which can be crossed by hand tremor during a
    /// stationary tap; this re-checks against the converted, physically
    /// meaningful translation. See issue #32.
    private let cardDragConfirmationDistance: Float = 0.02

    func body(content: Content) -> some View {
        content
            .gesture(movementGesture)
    }

    private var movementGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .targetedToAnyEntity()
            .onChanged { value in
                if appModel.orbitState.isActive {
                    let startPoint = value.convert(
                        value.startLocation3D,
                        from: .local,
                        to: .scene
                    )
                    let point = value.convert(
                        value.location3D,
                        from: .local,
                        to: .scene
                    )
                    orbitDragInterpreter.begin(
                        angle: orbitAngle(for: startPoint),
                        rotation: appModel.orbitState.rotation
                    )
                    if let rotation = orbitDragInterpreter.update(
                        angle: orbitAngle(for: point)
                    ) {
                        appModel.updateOrbitRotation(
                            rotation,
                            isFinal: false
                        )
                    }
                    return
                }

                guard value.entity.components[
                    PointOfInterestRuntimeComponent.self
                ] != nil else {
                    return
                }
                if dragStartPosition == nil {
                    dragStartPosition = value.entity.position
                }
                guard let dragStartPosition else { return }

                let translation = value.convert(
                    value.translation3D,
                    from: .local,
                    to: .scene
                )
                guard isCardDragConfirmed
                    || simd_length(translation) >= cardDragConfirmationDistance
                else {
                    return
                }
                isCardDragConfirmed = true
                value.entity.position = dragStartPosition + translation
            }
            .onEnded { value in
                if appModel.orbitState.isActive {
                    if let rotation = orbitDragInterpreter.end() {
                        appModel.updateOrbitRotation(
                            rotation,
                            isFinal: true
                        )
                    }
                    return
                }

                orbitDragInterpreter.reset()
                dragStartPosition = nil
                let wasDragConfirmed = isCardDragConfirmed
                isCardDragConfirmed = false

                // Movement never crossed the confirmation distance, so this
                // touch was a tap, not a drag -- the card never actually
                // moved and there's no new position to commit.
                guard wasDragConfirmed else { return }

                guard let runtimeComponent = value.entity.components[
                    PointOfInterestRuntimeComponent.self
                ] else {
                    return
                }

                // Unknown debug POIs can still be moved locally, but have no
                // canonical identity and therefore never cross the sync seam.
                guard let cardID = runtimeComponent.cardID else { return }
                appModel.setCardPosition(
                    cardID,
                    position: value.entity.position
                )
            }
    }

    private func orbitAngle(for point: SIMD3<Float>) -> Float {
        let localPoint = appModel.orbitGestureWorldToLocal * SIMD4<Float>(
            Float(point.x),
            Float(point.y),
            Float(point.z),
            1
        )
        return atan2(localPoint.z, localPoint.x)
    }
}

extension View {
    func spatialCardGestures() -> some View {
        modifier(SpatialCardGestureModifier())
    }
}
