import Testing
@testable import Handover_V4

struct OrbitDragInterpreterTests {
    @Test
    func movementBelowFiveDegreesProducesNoUpdates() {
        var interpreter = OrbitDragInterpreter()

        interpreter.begin(angle: 0, rotation: 1.25)
        #expect(interpreter.update(angle: 0.0855) == nil)
        #expect(interpreter.end() == nil)
    }

    @Test
    func inactiveCompletionResetsTheGesture() {
        var interpreter = OrbitDragInterpreter()

        interpreter.begin(angle: 0, rotation: 1)
        _ = interpreter.update(angle: 0.05)
        #expect(interpreter.end() == nil)

        interpreter.begin(angle: 0, rotation: 2)
        #expect(interpreter.update(angle: 0.08726646) != nil)
    }

    @Test
    func exactlyFiveDegreesActivatesWithTheFullMovement() throws {
        var interpreter = OrbitDragInterpreter()

        interpreter.begin(angle: 0, rotation: 1.25)
        let interpretedRotation = interpreter.update(angle: 0.08726646)
        let update = try #require(interpretedRotation)

        #expect(abs(update - 1.3808997) < 0.0001)
    }

    @Test
    func sixDegreesOfDragProducesNineDegreesOfOrbitRotation() throws {
        var interpreter = OrbitDragInterpreter()

        interpreter.begin(angle: 0, rotation: 0.5)
        let interpretedRotation = interpreter.update(angle: 0.10471976)

        #expect(
            abs(try #require(interpretedRotation) - 0.65707964) < 0.0001
        )
    }

    @Test
    func movementAccumulatesInBothDirections() throws {
        var clockwise = OrbitDragInterpreter()
        var counterclockwise = OrbitDragInterpreter()

        clockwise.begin(angle: 0, rotation: 0.5)
        counterclockwise.begin(angle: 0, rotation: 0.5)
        let clockwiseRotation = clockwise.update(angle: 0.10471976)
        let counterclockwiseRotation = counterclockwise.update(
            angle: -0.10471976
        )

        #expect(abs(try #require(clockwiseRotation) - 0.65707964) < 0.0001)
        #expect(
            abs(try #require(counterclockwiseRotation) - 0.34292036) < 0.0001
        )
    }

    @Test
    func movementRemainsContinuousAcrossTheAngleBoundary() throws {
        var interpreter = OrbitDragInterpreter()

        interpreter.begin(angle: 3.1241393, rotation: 0.25)
        let wrappedRotation = interpreter.update(angle: -3.054326)

        #expect(abs(try #require(wrappedRotation) - 0.40707964) < 0.0001)
    }

    @Test
    func deliberateDragCanRotateAcrossMultipleCards() throws {
        var interpreter = OrbitDragInterpreter()

        interpreter.begin(angle: 0, rotation: 0.25)
        let interpretedRotation = interpreter.update(angle: 2.4)

        #expect(abs(try #require(interpretedRotation) - 3.85) < 0.0001)
    }

    @Test
    func amplifiedMovementContinuesAndProducesAFinalRotation() throws {
        var interpreter = OrbitDragInterpreter()

        interpreter.begin(angle: 0, rotation: 1)
        _ = interpreter.update(angle: 0.10471976)
        interpreter.begin(angle: 0, rotation: 99)
        let continuedRotation = interpreter.update(angle: 0.13962634)
        let finalRotation = interpreter.end()

        #expect(abs(try #require(continuedRotation) - 1.2094395) < 0.0001)
        #expect(abs(try #require(finalRotation) - 1.2094395) < 0.0001)
        interpreter.begin(angle: 0.5, rotation: 2)
        #expect(interpreter.update(angle: 0.5) == nil)
    }
}
