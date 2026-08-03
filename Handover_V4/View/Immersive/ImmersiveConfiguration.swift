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
    static let orbitDragIntentThreshold: Float = 5 * .pi / 180

    static func orbitSlotEntityName(_ index: Int) -> String {
        "OrbitSlot_\(index)"
    }

    // MARK: - Source Coupling

    /// Authored body-region anchor on the patient (under `Root`, scale 1.0).
    static let torsoOrganAnchorName = "OrganAnchor_torso"
    /// Emissive boost applied to an equipment Source when its card is active.
    static let sourceHighlightEmissiveIntensity: Float = 6
    static let sourceHighlightAnimationDuration: TimeInterval = 0.3
    /// Edge length (metres) of an organ SF-Symbol placard.
    static let organPlacardSize: Float = 0.14
    /// Minimum halo box extent (metres) when the emissive fallback is used.
    static let sourceHaloMinimumExtent: Float = 0.05
    static let sourceHaloOpacity: CGFloat = 0.28
    static let sourceHaloEntityName = "SourceHalo"
}
