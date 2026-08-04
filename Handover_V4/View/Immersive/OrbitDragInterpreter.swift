//
//  OrbitDragInterpreter.swift
//  Handover_V4
//

struct OrbitDragInterpreter {
    private var startRotation: Float?
    private var previousAngle: Float?
    private var accumulatedMovement: Float = 0
    private var hasActivatedDrag = false

    mutating func begin(angle: Float, rotation: Float) {
        guard previousAngle == nil else { return }

        startRotation = rotation
        previousAngle = angle
    }

    mutating func update(angle: Float) -> Float? {
        guard let previousAngle else {
            return nil
        }

        accumulatedMovement += OrbitLayoutController.normalizedAngle(
            angle - previousAngle
        )
        self.previousAngle = angle

        let reachedIntentThreshold = abs(accumulatedMovement)
            >= ImmersiveConfiguration.orbitDragIntentThreshold
        guard hasActivatedDrag || reachedIntentThreshold else {
            return nil
        }

        hasActivatedDrag = true
        return startRotation.map { $0 + accumulatedMovement }
    }

    mutating func end() -> Float? {
        defer { reset() }
        guard hasActivatedDrag else { return nil }
        return startRotation.map { $0 + accumulatedMovement }
    }

    mutating func reset() {
        startRotation = nil
        previousAngle = nil
        accumulatedMovement = 0
        hasActivatedDrag = false
    }
}
