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
}
