// Flow: ImmersiveView -> ImmersiveSceneController -> OrbitGeometry + SourceOutlineController + RealityKit attachments.
import RealityKit
import RealityKitContent
import Observation

/// Owns one immersive scene's transient entities; authored POIs and SharePlay positions stay intact.
@MainActor @Observable
final class ImmersiveSceneController {
    private(set) var pointsOfInterest: [Entity] = []
    @ObservationIgnored private var cards: [String: Entity] = [:]
    @ObservationIgnored private var homes: [String: SIMD3<Float>] = [:]
    @ObservationIgnored private var collisionBounds: [String: BoundingBox] = [:]
    @ObservationIgnored private var ring: Entity?
    @ObservationIgnored private var geometry: OrbitGeometry?
    @ObservationIgnored private var outlines = SourceOutlineController()
    @ObservationIgnored private var displayedPosition: Double = 0
    @ObservationIgnored private var movementStart: Double = 0
    @ObservationIgnored private var movementTime: Double = 0
    @ObservationIgnored private var lastRevision = -1

    /// Discover existing POIs after loading, avoiding dependence on component-add event timing.
    func prepare(_ root: Entity) -> Entity {
        var pending = [root]
        var points = [Entity]()
        while let entity = pending.popLast() {
            if let poi = entity.components[PointOfInterestComponent.self] {
                entity.components.set(PointOfInterestRuntimeComponent(attachmentTag: entity.id, cardName: poi.name))
                points.append(entity)
                homes[poi.name] = entity.position(relativeTo: nil)
            }
            pending.append(contentsOf: entity.children)
        }
        pointsOfInterest = points
        outlines.prepare(in: root)
        let geometry = OrbitGeometry(in: root)
        self.geometry = geometry
        let ring = geometry.makeRing()
        self.ring = ring
        return ring
    }

    /// Attach to scene root to avoid inheriting the ICU asset's hundredth-scale transform.
    func register(_ attachment: Entity, name: String) {
        guard cards[name] == nil else { return }
        cards[name] = attachment
        attachment.components.set(BillboardComponent())
        if name != "Basic_Information" {
            attachment.components.set(InputTargetComponent())
            attachment.components.set(HoverEffectComponent())
        }
        attachment.position = homes[name] ?? .zero
    }

    /// Advance only navigation transforms; measured collision bounds follow SwiftUI disclosure size.
    func update(deltaTime: Double, appModel: AppModel) {
        guard let geometry else { return }
        let state = appModel.orbit.state
        let isOrbit = appModel.presentationMode == .orbit
        ring?.isEnabled = isOrbit
        if state.revision != lastRevision {
            lastRevision = state.revision
            movementStart = displayedPosition
            // Equivalent turns keep scrubbing continuous at the nine-to-one seam.
            let count = Double(OrbitCard.allCases.count)
            movementStart += ((state.position - movementStart) / count).rounded() * count
            movementTime = 0
        }
        movementTime += deltaTime
        if state.phase == .scrubbing {
            displayedPosition = state.position
        } else {
            let progress = min(1, movementTime / OrbitController.settleDuration)
            let eased = progress * progress * (3 - 2 * progress)
            displayedPosition = movementStart + (state.position - movementStart) * eased
        }
        for (name, card) in cards {
            card.isEnabled = appModel.presentationMode != .dashboard
            guard card.isEnabled else { continue }
            if isOrbit, let clinicalCard = OrbitCard(rawValue: name),
               let index = OrbitCard.allCases.firstIndex(of: clinicalCard) {
                card.position = geometry.path.point(at: Double(index) - displayedPosition) + SIMD3<Float>(0, 0.08, 0)
                let focused = state.frontCard == clinicalCard
                card.scale = SIMD3<Float>(repeating: focused ? 1 : 0.72)
                card.components.set(OpacityComponent(opacity: state.expandedCard == nil || focused ? 1 : 0.3))
            } else {
                card.position = isOrbit ? geometry.patientPosition : (appModel.cardPositions[name] ?? homes[name] ?? .zero)
                card.scale = .one
                card.components.set(OpacityComponent(opacity: 1))
            }
            guard name != "Basic_Information" else { continue }
            let bounds = card.visualBounds(relativeTo: card)
            guard bounds.extents.x > 0, bounds.extents.y > 0,
                  bounds.extents.x.isFinite, bounds.extents.y.isFinite else { continue }
            if collisionBounds[name] != bounds {
                let shape = ShapeResource.generateBox(size: SIMD3<Float>(bounds.extents.x, bounds.extents.y, 0.05))
                    .offsetBy(translation: bounds.center)
                card.components.set(CollisionComponent(shapes: [shape]))
                collisionBounds[name] = bounds
            }
        }
        switch appModel.presentationMode {
        case .dashboard: outlines.show([])
        case .orbit:
            // Rendering can start after the state timer; never highlight before the geometry arrives.
            outlines.show(abs(displayedPosition - state.position) < 0.001 ? state.sourceNames : [])
        case .spatial:
            outlines.show(Set(OrbitCard.allCases.filter { appModel.isCardExpanded($0.rawValue) }.flatMap(\.equipmentNames)))
        }
    }

    /// Uses the actual authored curve, including its translation, rotation, and scale.
    func ringPosition(nearest point: SIMD3<Float>) -> Double? {
        geometry?.path.position(nearest: point)
    }

    func clear() {
        outlines.clear()
        cards.removeAll()
        homes.removeAll()
        collisionBounds.removeAll()
        pointsOfInterest.removeAll()
        ring = nil
        geometry = nil
        lastRevision = -1
    }
}
