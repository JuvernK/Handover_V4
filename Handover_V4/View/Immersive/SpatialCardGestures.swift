//
//  SpatialCardGestures.swift
//  Handover_V4
//

import SwiftUI
import RealityKit

private struct SpatialCardGestureModifier: ViewModifier {
    @Environment(AppModel.self) private var appModel
    @State private var dragStartPosition: SIMD3<Float>?
    @State private var orbitLastAngle: Float?

    func body(content: Content) -> some View {
        content
            .gesture(movementGesture)
    }

    private var movementGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .targetedToAnyEntity()
            .onChanged { value in
                if appModel.orbitState.isActive {
                    let point = value.convert(
                        value.location3D,
                        from: .local,
                        to: .scene
                    )
                    let localPoint = appModel.orbitGestureWorldToLocal * SIMD4<Float>(
                        Float(point.x),
                        Float(point.y),
                        Float(point.z),
                        1
                    )
                    let angle = atan2(
                        localPoint.z,
                        localPoint.x
                    )
                    if let orbitLastAngle {
                        let delta = OrbitLayoutController.normalizedAngle(
                            angle - orbitLastAngle
                        )
                        appModel.updateOrbitRotation(
                            appModel.orbitState.rotation + delta,
                            isFinal: false
                        )
                    } else {
                        // Collapse the focused card as soon as orbit motion begins.
                        appModel.updateOrbitRotation(
                            appModel.orbitState.rotation,
                            isFinal: false
                        )
                    }
                    orbitLastAngle = angle
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
                value.entity.position = dragStartPosition + translation
            }
            .onEnded { value in
                if appModel.orbitState.isActive {
                    orbitLastAngle = nil
                    appModel.updateOrbitRotation(
                        appModel.orbitState.rotation,
                        isFinal: true
                    )
                    return
                }

                dragStartPosition = nil

                guard let runtimeComponent = value.entity.components[
                    PointOfInterestRuntimeComponent.self
                ] else {
                    return
                }

                appModel.setCardPosition(
                    name: runtimeComponent.cardName,
                    position: value.entity.position,
                    syncChanges: true
                )
            }
    }
}

extension View {
    func spatialCardGestures() -> some View {
        modifier(SpatialCardGestureModifier())
    }
}
