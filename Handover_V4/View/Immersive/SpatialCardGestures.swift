//
//  SpatialCardGestures.swift
//  Handover_V4
//

import SwiftUI
import RealityKit

private struct SpatialCardGestureModifier: ViewModifier {
    @Environment(AppModel.self) private var appModel
    // Grouped so a completed or abandoned touch resets with one assignment
    // instead of several booleans that must be cleared together. See
    // CardHandleInteraction.swift for the tap-vs-drag-vs-toggle decision
    // logic this state feeds.
    @State private var touchState: CardTouchState?
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

                guard let runtimeComponent = value.entity.components[
                    PointOfInterestRuntimeComponent.self
                ] else {
                    return
                }
                let wasStartingFresh = touchState == nil
                if touchState == nil {
                    touchState = CardTouchState(
                        startPosition: value.entity.position,
                        isEligibleForToggle: isWithinCardHandleRegion(
                            runtimeComponent: runtimeComponent,
                            entity: value.entity,
                            touchLocalPosition: value.startLocation3D
                        )
                    )
#if DEBUG
                    print(
                        "[CardDragDebug] touch started: card=\(runtimeComponent.diagnosticName), "
                            + "isEligibleForToggle=\(touchState?.isEligibleForToggle ?? false)"
                    )
#endif
                }
                guard var state = touchState else { return }

                let translation = value.convert(
                    value.translation3D,
                    from: .local,
                    to: .scene
                )
                let distance = simd_length(translation)
#if DEBUG
                if wasStartingFresh || !state.isDragConfirmed {
                    print(
                        "[CardDragDebug] onChanged: card=\(runtimeComponent.diagnosticName), "
                            + "distance=\(distance), "
                            + "confirmedBefore=\(state.isDragConfirmed), "
                            + "threshold=\(ImmersiveConfiguration.cardDragConfirmationDistance)"
                    )
                }
#endif
                let wasConfirmedBefore = state.isDragConfirmed
                state.isDragConfirmed = CardHandleInteraction.isDragConfirmed(
                    distance: distance,
                    alreadyConfirmed: state.isDragConfirmed,
                    threshold: ImmersiveConfiguration.cardDragConfirmationDistance
                )
                touchState = state
                guard state.isDragConfirmed else { return }
                if !wasConfirmedBefore {
#if DEBUG
                    print(
                        "[CardDragDebug] drag CONFIRMED: card=\(runtimeComponent.diagnosticName), "
                            + "distance=\(distance)"
                    )
#endif
                }
                value.entity.position = state.startPosition + translation
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
                defer { touchState = nil }

                guard let state = touchState,
                      let runtimeComponent = value.entity.components[
                        PointOfInterestRuntimeComponent.self
                      ]
                else {
                    return
                }
#if DEBUG
                print(
                    "[CardDragDebug] onEnded: card=\(runtimeComponent.diagnosticName), "
                        + "wasDragConfirmed=\(state.isDragConfirmed), "
                        + "wasTapEligibleForToggle=\(state.isEligibleForToggle)"
                )
#endif

                let outcome = CardHandleInteraction.resolveOutcome(
                    for: state,
                    entityPosition: value.entity.position
                )
                switch outcome {
                case .moved(let position):
                    // Unknown debug POIs can still be moved locally, but
                    // have no canonical identity and therefore never cross
                    // the sync seam.
                    guard let cardID = runtimeComponent.cardID else { return }
                    appModel.setCardPosition(cardID, position: position)
                case .toggled:
                    // The drag gesture won the arena for this tap instead of
                    // the header's own Button, so nothing would otherwise
                    // happen. Fire the toggle here as a fallback.
                    guard let cardID = runtimeComponent.cardID else { return }
                    appModel.setCardState(
                        cardID,
                        isExpanded: !(appModel.cardStates[cardID] ?? true)
                    )
                case .none:
                    break
                }
            }
    }

    /// Whether a touch's start position falls within the card's Card Handle
    /// (its header bar) rather than its body. A collapsed card is a single
    /// row, so the whole thing counts, matching #28's whole-bar tap target;
    /// an expanded card only counts its header, since the body can hold its
    /// own interactive content (e.g. abbreviation capsules) that must not be
    /// mistaken for a toggle.
    ///
    /// Not applied to Basic Information: its expanded state has an
    /// interactive diagnosis abbreviation near the top of the header itself,
    /// so it keeps its existing Button-only behaviour, unchanged.
    ///
    /// CardChrome.expansionTapAreaHeight is authored in SwiftUI points, but
    /// this entity's bounds are measured in RealityKit metres, so the header
    /// height is converted using this specific card's own measured width
    /// against its known authored width (CardChrome.defaultCardWidth or
    /// .expandedCardWidth) rather than an assumed points-to-metres constant.
    /// An attachment's content renders at one uniform scale, so this ratio
    /// is exact, not approximated.
    private func isWithinCardHandleRegion(
        runtimeComponent: PointOfInterestRuntimeComponent,
        entity: Entity,
        touchLocalPosition: Point3D
    ) -> Bool {
        guard let cardID = runtimeComponent.cardID,
              case .section(let sectionID) = cardID else {
            return false
        }

        let isExpanded = appModel.cardStates[cardID] ?? true
        guard isExpanded else {
            return true
        }

        let authoredWidth = CardChrome.expandedCardWidth(for: sectionID)
        let bounds = entity.visualBounds(relativeTo: entity)
        guard bounds.extents.x > 0, authoredWidth > 0 else { return false }

        let metresPerPoint = bounds.extents.x / Float(authoredWidth)
        let headerHeight = Float(CardChrome.expansionTapAreaHeight) * metresPerPoint
        return Float(touchLocalPosition.y) >= bounds.max.y - headerHeight
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
