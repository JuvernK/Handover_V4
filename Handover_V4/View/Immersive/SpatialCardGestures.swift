//
//  SpatialCardGestures.swift
//  Handover_V4
//

import SwiftUI
import RealityKit

private struct SpatialCardGestureModifier: ViewModifier {
    @Environment(AppModel.self) private var appModel
    @State private var dragStartPosition: SIMD3<Float>?

    func body(content: Content) -> some View {
        content
            .gesture(expansionGesture)
            .gesture(movementGesture)
    }

    private var expansionGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                guard let runtimeComponent = value.entity.components[
                    PointOfInterestRuntimeComponent.self
                ] else {
                    return
                }

                let cardName = runtimeComponent.cardName
                let isExpanded = appModel.cardStates[cardName] ?? true

                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    appModel.setCardState(
                        name: cardName,
                        isExpanded: !isExpanded,
                        syncChanges: true
                    )
                }
            }
    }

    private var movementGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .targetedToAnyEntity()
            .onChanged { value in
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
