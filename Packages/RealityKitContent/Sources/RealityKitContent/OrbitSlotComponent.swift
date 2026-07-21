//
//  OrbitSlotComponent.swift
//  RealityKitContent
//

import RealityKit

/// Keeps authored Orbit slot transforms available in the compiled scene.
/// `slotIndex == -1` identifies the central Patient Information position.
public struct OrbitSlotComponent: Component, Codable {
    public var slotIndex: Int = 0

    public init(slotIndex: Int = 0) {
        self.slotIndex = slotIndex
    }
}
