// Flow: Reality Composer Pro OrbitAnchor -> OrbitSlotComponent -> app OrbitGeometry.
import RealityKit

/// Marks authored carousel control points; -1 is the separate patient-information position.
public struct OrbitSlotComponent: Component, Codable {
    public var slotIndex: Int = 0

    public init() {}
}
