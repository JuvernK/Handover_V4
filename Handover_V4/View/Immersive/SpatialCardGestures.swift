//
//  SpatialCardGestures.swift
//  Handover_V4
//

import SwiftUI
import RealityKit

private struct SpatialCardGestureModifier: ViewModifier {
    @Environment(AppModel.self) private var appModel
    @State private var dragStartPosition: SIMD3<Float>?
    // Below ImmersiveConfiguration.cardDragConfirmationDistance of movement,
    // a touch is tap jitter, not a deliberate drag. SwiftUI's DragGesture
    // minimumDistance is measured in screen points before the 3D conversion
    // below, which hand tremor during a stationary tap can cross easily.
    // This is a linear-distance sibling of OrbitDragInterpreter's angular
    // intent threshold, not a shared type: the two gestures measure
    // different things (translation vs. rotation), and folding this into
    // OrbitDragInterpreter would mean generalizing tested, working code for
    // a metric it wasn't built for. See issue #32.
    @State private var isCardDragConfirmed = false
    // The RealityKit DragGesture below and the SwiftUI Button inside the
    // card's header (SpatialCard.swift's spatialExpansionControl) are two
    // independent recognizers over the same touch, so which one "wins" a
    // given tap on the header isn't deterministic. When the drag gesture
    // wins, the Button never fires and nothing happens. Track whether the
    // touch started within the header region so this gesture can fire the
    // toggle itself as a fallback when it wins a tap. Not applied to
    // Basic Information: its expanded state has an interactive diagnosis
    // abbreviation at the top the region check isn't precise enough to
    // reliably avoid. See issue #32.
    @State private var isTapEligibleForCardToggle = false
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
                let wasStartingFresh = dragStartPosition == nil
                if dragStartPosition == nil {
                    dragStartPosition = value.entity.position
                    isTapEligibleForCardToggle = isWithinCardHandleRegion(
                        runtimeComponent: runtimeComponent,
                        entity: value.entity,
                        touchLocalPosition: value.startLocation3D
                    )
#if DEBUG
                    print(
                        "[CardDragDebug] touch started: card=\(runtimeComponent.diagnosticName), "
                            + "isTapEligibleForCardToggle=\(isTapEligibleForCardToggle)"
                    )
#endif
                }
                guard let dragStartPosition else { return }

                let translation = value.convert(
                    value.translation3D,
                    from: .local,
                    to: .scene
                )
                let distance = simd_length(translation)
#if DEBUG
                if wasStartingFresh || !isCardDragConfirmed {
                    print(
                        "[CardDragDebug] onChanged: card=\(runtimeComponent.diagnosticName), "
                            + "distance=\(distance), "
                            + "confirmedBefore=\(isCardDragConfirmed), "
                            + "threshold=\(ImmersiveConfiguration.cardDragConfirmationDistance)"
                    )
                }
#endif
                guard isCardDragConfirmed
                    || distance
                        >= ImmersiveConfiguration.cardDragConfirmationDistance
                else {
                    return
                }
                if !isCardDragConfirmed {
#if DEBUG
                    print(
                        "[CardDragDebug] drag CONFIRMED: card=\(runtimeComponent.diagnosticName), "
                            + "distance=\(distance)"
                    )
#endif
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
                let wasTapEligibleForToggle = isTapEligibleForCardToggle
                isTapEligibleForCardToggle = false

                guard let runtimeComponent = value.entity.components[
                    PointOfInterestRuntimeComponent.self
                ] else {
                    return
                }
#if DEBUG
                print(
                    "[CardDragDebug] onEnded: card=\(runtimeComponent.diagnosticName), "
                        + "wasDragConfirmed=\(wasDragConfirmed), "
                        + "wasTapEligibleForToggle=\(wasTapEligibleForToggle)"
                )
#endif

                // Movement never crossed the confirmation distance, so this
                // touch was a tap, not a drag. The card never actually
                // moved and there's no new position to commit.
                guard wasDragConfirmed else {
                    // The drag gesture won the arena for this tap instead of
                    // the header's own Button, so nothing would otherwise
                    // happen. Fire the toggle here as a fallback.
                    if wasTapEligibleForToggle, let cardID = runtimeComponent.cardID {
                        appModel.setCardState(
                            cardID,
                            isExpanded: !(appModel.cardStates[cardID] ?? true)
                        )
                    }
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
