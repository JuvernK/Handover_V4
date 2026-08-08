import Foundation
import Testing
@testable import Handover_V4

@MainActor
struct OrbitControllerTests {
    @Test
    func enablementAndDelayedExpansionPreserveExistingBehavior() {
        let harness = OrbitHarness(cardNames: ["vitals", "plan"])

        harness.controller.perform(.setEnabled(true))

        #expect(harness.state.isActive)
        #expect(harness.state.rotation == 0)
        #expect(harness.state.focusedCardName == "vitals")
        #expect(harness.state.expandedCardName == nil)

        harness.scheduler.runAll()
        #expect(harness.state.expandedCardName == "vitals")

        harness.controller.perform(.setEnabled(false))
        #expect(harness.state == .inactive)
    }

    @Test
    func settledRotationSnapsFocusAndThenExpandsIt() {
        let harness = OrbitHarness(
            cardNames: ["vitals", "plan", "labs", "systems"]
        )
        harness.controller.perform(.setEnabled(true))
        harness.scheduler.runAll()

        harness.controller.perform(
            .updateRotation(-Float.pi / 2 + 0.08, isFinal: true)
        )

        #expect(harness.state.focusedCardName == "plan")
        #expect(abs(harness.state.rotation + Float.pi / 2) < 0.0001)
        #expect(harness.state.expandedCardName == nil)

        harness.scheduler.runAll()
        #expect(harness.state.expandedCardName == "plan")
    }

    @Test
    func navigationDirectFocusAndExpansionToggleShareOneTransitionPath() {
        let harness = OrbitHarness(
            cardNames: ["vitals", "plan", "labs"]
        )
        harness.controller.perform(.setEnabled(true))

        harness.controller.perform(.moveFocus(by: -1))
        #expect(harness.state.focusedCardName == "labs")

        harness.controller.perform(.focusCard(named: "plan"))
        #expect(harness.state.focusedCardName == "plan")

        harness.controller.perform(.toggleFocusedExpansion)
        #expect(harness.state.expandedCardName == "plan")
        harness.controller.perform(.toggleFocusedExpansion)
        #expect(harness.state.expandedCardName == nil)
    }

    @Test
    func newerActionCancelsEarlierDelayedExpansion() {
        let harness = OrbitHarness(cardNames: ["vitals", "plan"])

        harness.controller.perform(.setEnabled(true))
        harness.controller.perform(.focusCard(named: "plan"))
        harness.scheduler.runAll()

        #expect(harness.state.focusedCardName == "plan")
        #expect(harness.state.expandedCardName == "plan")
        #expect(harness.scheduler.cancelledActionCount == 1)
    }
}

@MainActor
private final class OrbitHarness {
    private final class StateBox {
        var value = OrbitState.inactive
    }

    private let stateBox = StateBox()
    let scheduler = ManualOrbitScheduler()
    let controller: OrbitController

    var state: OrbitState {
        stateBox.value
    }

    init(cardNames: [String]) {
        let stateBox = stateBox
        controller = OrbitController(
            currentState: { stateBox.value },
            orderedCardNames: { cardNames },
            scheduler: scheduler
        ) { transition in
            stateBox.value = transition.state
        }
    }
}

@MainActor
private final class ManualOrbitScheduler: OrbitScheduling {
    private var actions: [ManualOrbitScheduledAction] = []
    private var nextActionIndex = 0

    var cancelledActionCount: Int {
        actions.count(where: \.isCancelled)
    }

    func schedule(
        after delay: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> any OrbitScheduledAction {
        let scheduledAction = ManualOrbitScheduledAction(action: action)
        actions.append(scheduledAction)
        return scheduledAction
    }

    func runAll() {
        let pending = actions.dropFirst(nextActionIndex)
        nextActionIndex = actions.count
        for action in pending {
            action.run()
        }
    }
}

@MainActor
private final class ManualOrbitScheduledAction: OrbitScheduledAction {
    private let action: @MainActor () -> Void
    private(set) var isCancelled = false

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    func cancel() {
        isCancelled = true
    }

    func run() {
        guard !isCancelled else { return }
        action()
    }
}
