// Flow: ImmersiveSceneController -> OrbitGeometry -> nine-card path + draggable ring.
import RealityKit
import RealityKitContent
import UIKit

/// Resolves the authored OrbitAnchor in world space; its markers control both ring and carousel.
struct OrbitGeometry {
    let path: OrbitPath
    let patientPosition: SIMD3<Float>
    static let ringName = "OrbitNavigationRing"

    init(in root: Entity) {
        let anchor = root.findEntity(named: "OrbitAnchor")
        let markers = anchor.map { Array($0.children) } ?? []
        let slots = markers.compactMap { entity -> (Int, SIMD3<Float>)? in
            guard let index = entity.components[OrbitSlotComponent.self]?.slotIndex, index >= 0 else { return nil }
            return (index, entity.position(relativeTo: nil))
        }.sorted { $0.0 < $1.0 }
        if slots.count >= 3 {
            path = OrbitPath(points: slots.map(\.1), cardCount: OrbitCard.allCases.count)
        } else {
            // Older scenes can still load; new scenes should author the component-backed markers.
            let center = anchor?.position(relativeTo: nil) ?? SIMD3<Float>(0.0574, 0.95, -2.4)
            path = OrbitPath(points: (0..<9).map { index in
                let angle = Float(index) * 2 * .pi / 9
                return center + SIMD3<Float>(-1.25 * sin(angle), 0, 1.4 * cos(angle))
            }, cardCount: OrbitCard.allCases.count)
            print("Orbit slot markers unavailable; using a generated path")
        }
        patientPosition = markers.first { $0.components[OrbitSlotComponent.self]?.slotIndex == -1 }?
            .position(relativeTo: nil) ?? (anchor?.position(relativeTo: nil) ?? .zero)
    }

    static func isRing(_ entity: Entity) -> Bool {
        var candidate: Entity? = entity
        while let current = candidate {
            if current.name == ringName { return true }
            candidate = current.parent
        }
        return false
    }

    func makeRing() -> Entity {
        let ring = Entity()
        ring.name = Self.ringName
        let segments = 96
        let material = SimpleMaterial(color: .systemCyan, isMetallic: false)
        for index in 0..<segments {
            let start = path.point(at: Double(index) * Double(OrbitCard.allCases.count) / Double(segments))
            let end = path.point(at: Double(index + 1) * Double(OrbitCard.allCases.count) / Double(segments))
            let length = simd_distance(start, end)
            let segment = ModelEntity(mesh: .generateCylinder(height: length * 1.02, radius: 0.006), materials: [material])
            segment.position = (start + end) / 2
            segment.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(end - start))
            segment.components.set(InputTargetComponent())
            segment.components.set(HoverEffectComponent())
            segment.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(0.10, length, 0.10))]))
            ring.addChild(segment)
        }
        ring.isEnabled = false
        return ring
    }
}
