//
//  SpatialCardGestures.swift
//  Handover_V4
//

import SwiftUI
import RealityKit

private struct SpatialCardGestureModifier: ViewModifier {
    @Environment(AppModel.self) private var appModel
    @State private var dragStartPosition: SIMD3<Float>?
    @State private var orbitDragInterpreter = OrbitDragInterpreter()

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
