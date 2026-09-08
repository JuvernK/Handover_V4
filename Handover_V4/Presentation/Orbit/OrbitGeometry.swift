// Flow: ImmersiveSceneController -> OrbitGeometry -> nine-card path + draggable ring.
import RealityKit
import UIKit

/// Uniform nine-slot ellipse using the reference scene's room-centered Orbit placement.
/// Basic Information has a separate elevated position so it stays visible during rotation.
enum OrbitGeometry {
    static let center = SIMD3<Float>(0.0574, 0.95, -2.4)
    static let patientPosition = SIMD3<Float>(0.0574, 2.05, -2.4)
    static let ringName = "OrbitNavigationRing"

    static func point(at position: Double) -> SIMD3<Float> {
        let angle = Float(position) * 2 * .pi / Float(OrbitCard.allCases.count)
        return center + SIMD3<Float>(-1.25 * sin(angle), 0, 1.4 * cos(angle))
    }

    static func isRing(_ entity: Entity) -> Bool {
        var candidate: Entity? = entity
        while let current = candidate {
            if current.name == ringName { return true }
            candidate = current.parent
        }
        return false
    }

    static func makeRing() -> Entity {
        let ring = Entity()
        ring.name = ringName
        let segments = 96
        let material = SimpleMaterial(color: .systemCyan, isMetallic: false)
        for index in 0..<segments {
            let start = point(at: Double(index) * Double(OrbitCard.allCases.count) / Double(segments))
            let end = point(at: Double(index + 1) * Double(OrbitCard.allCases.count) / Double(segments))
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

/// Unwraps ring angles across the back seam, rejecting small pinch jitter until movement is deliberate.
struct OrbitRingDrag {
    private var previousAngle: Double?
    private var startPosition = 0.0
    private var movement = 0.0
    private(set) var isDragging = false

    mutating func update(point: SIMD3<Float>, position: Double) -> Double? {
        let offset = point - OrbitGeometry.center
        guard abs(offset.x) + abs(offset.z) > 0.01 else { return nil }
        let angle = atan2(Double(-offset.x / 1.25), Double(offset.z / 1.4))
        guard let previousAngle else {
            self.previousAngle = angle
            startPosition = position
            return nil
        }
        let delta = atan2(sin(angle - previousAngle), cos(angle - previousAngle))
        movement += delta
        self.previousAngle = angle
        guard isDragging || abs(movement) > 0.05 else { return nil }
        isDragging = true
        return startPosition - movement * Double(OrbitCard.allCases.count) / (2 * .pi)
    }
}
