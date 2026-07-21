//
//  ImmersiveConfiguration.swift
//  Handover_V4
//

import Foundation

enum ImmersiveConfiguration {
    static let sceneName = "Immersive"
    static let ambienceResourceName = "icu_ambience"

    static let collisionDepth: Float = 0.05
    static let collisionBoundsAttempts = 20
    static let collisionBoundsRetryDelay = Duration.milliseconds(100)
    static let collisionResizeDelay = Duration.milliseconds(600)
    static let remoteMovementDuration = 0.3

    static let orbitAnchorEntityName = "OrbitAnchor"
    static let patientInformationSlotEntityName = "PatientInformationSlot"
    static let orbitRingEntityName = "OrbitRing"
    static let orbitCardCount = 8
    static let orbitFallbackCenter = SIMD3<Float>(-1.385, 1.2, -0.814)
    static let orbitFallbackRadius: Float = 1.4
    static let orbitRingSegmentCount = 64
    static let orbitRingTubeRadius: Float = 0.008
    static let orbitCollisionWidth: Float = 0.12

    static func orbitSlotEntityName(_ index: Int) -> String {
        "OrbitSlot_\(index)"
    }
}
