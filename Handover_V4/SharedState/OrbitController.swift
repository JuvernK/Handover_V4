import Foundation

enum OrbitIntent {
    case setEnabled(Bool)
    case updateRotation(Float, isFinal: Bool)
    case focusCard(named: String)
    case toggleFocusedExpansion
    case moveFocus(by: Int)
}

struct OrbitTransition {
    let state: OrbitState
    let animationDuration: TimeInterval
    let isFinal: Bool
}

@MainActor
protocol OrbitScheduledAction: AnyObject {
    func cancel()
}

@MainActor
protocol OrbitScheduling {
    func schedule(
        after delay: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> any OrbitScheduledAction
}

@MainActor
private final class TaskOrbitScheduledAction: OrbitScheduledAction {
    private let task: Task<Void, Never>

    init(
        delay: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) {
        task = Task { @MainActor in
            try? await Task.sleep(
                for: .milliseconds(Int(delay * 1_000))
            )
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel() {
        task.cancel()
    }
}

@MainActor
private struct TaskOrbitScheduler: OrbitScheduling {
    func schedule(
        after delay: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> any OrbitScheduledAction {
        TaskOrbitScheduledAction(delay: delay, action: action)
    }
}

/// Owns Orbit state transitions independently of SharePlay and RealityKit.
@MainActor
final class OrbitController {
    private let currentState: () -> OrbitState
    private let orderedCardNames: () -> [String]
    private let apply: (OrbitTransition) -> Void
    private let scheduler: any OrbitScheduling
    private var scheduledExpansion: (any OrbitScheduledAction)?

    init(
        currentState: @escaping () -> OrbitState,
        orderedCardNames: @escaping () -> [String],
        scheduler: (any OrbitScheduling)? = nil,
        apply: @escaping (OrbitTransition) -> Void
    ) {
        self.currentState = currentState
        self.orderedCardNames = orderedCardNames
        self.scheduler = scheduler ?? TaskOrbitScheduler()
        self.apply = apply
    }

    func perform(_ intent: OrbitIntent) {
        switch intent {
        case .setEnabled(let isEnabled):
            setEnabled(isEnabled)
        case .updateRotation(let rotation, let isFinal):
            updateRotation(rotation, isFinal: isFinal)
        case .focusCard(let cardName):
            focusCard(named: cardName)
        case .toggleFocusedExpansion:
            toggleFocusedExpansion()
        case .moveFocus(let offset):
            moveFocus(by: offset)
        }
    }

    private func setEnabled(_ isEnabled: Bool) {
        cancelScheduledExpansion()
        let previousState = currentState()
        let state: OrbitState

        if isEnabled {
            guard !previousState.isActive else { return }
            state = OrbitState(
                interactionMode: .orbit,
                rotation: 0,
                focusedCardName: orderedCardNames().first,
                expandedCardName: nil
            )
        } else {
            guard previousState.isActive else { return }
            state = .inactive
        }

        applyTransition(state, animationDuration: 0.45, isFinal: true)
        if isEnabled, let focusedCardName = state.focusedCardName {
            scheduleExpansion(of: focusedCardName, after: 0.45)
        }
    }

    private func updateRotation(_ rotation: Float, isFinal: Bool) {
        let names = orderedCardNames()
        guard currentState().isActive, !names.isEmpty else { return }

        cancelScheduledExpansion()
        let index = focusedIndex(for: rotation, cardCount: names.count)
        var state = currentState()
        state.expandedCardName = nil
        state.rotation = isFinal
            ? snappedRotation(
                near: rotation,
                focusedIndex: index,
                cardCount: names.count
            )
            : rotation
        state.focusedCardName = names[index]
        applyTransition(
            state,
            animationDuration: isFinal ? 0.22 : 0,
            isFinal: isFinal
        )
        if isFinal, let focusedCardName = state.focusedCardName {
            scheduleExpansion(of: focusedCardName, after: 0.22)
        }
    }

    private func focusCard(named cardName: String) {
        let names = orderedCardNames()
        guard currentState().isActive,
              let index = names.firstIndex(of: cardName) else {
            return
        }

        cancelScheduledExpansion()
        var state = currentState()
        state.expandedCardName = nil
        state.rotation = snappedRotation(
            near: state.rotation,
            focusedIndex: index,
            cardCount: names.count
        )
        state.focusedCardName = cardName
        applyTransition(state, animationDuration: 0.3, isFinal: true)
        scheduleExpansion(of: cardName, after: 0.3)
    }

    private func toggleFocusedExpansion() {
        cancelScheduledExpansion()
        var state = currentState()
        guard state.isActive, let focusedCardName = state.focusedCardName else {
            return
        }

        state.expandedCardName = state.expandedCardName == nil
            ? focusedCardName
            : nil
        applyTransition(state, animationDuration: 0.3, isFinal: true)
    }

    private func moveFocus(by offset: Int) {
        let names = orderedCardNames()
        guard currentState().isActive, !names.isEmpty else { return }

        let state = currentState()
        let currentIndex = state.focusedCardName
            .flatMap(names.firstIndex(of:))
            ?? focusedIndex(for: state.rotation, cardCount: names.count)
        let destination = positiveModulo(currentIndex + offset, names.count)
        focusCard(named: names[destination])
    }

    private func scheduleExpansion(
        of cardName: String,
        after delay: TimeInterval
    ) {
        cancelScheduledExpansion()
        scheduledExpansion = scheduler.schedule(after: delay) { [weak self] in
            guard let self else { return }
            var state = currentState()
            guard state.isActive,
                  state.focusedCardName == cardName,
                  state.expandedCardName == nil else {
                return
            }

            state.expandedCardName = cardName
            applyTransition(state, animationDuration: 0.25, isFinal: true)
            scheduledExpansion = nil
        }
    }

    private func cancelScheduledExpansion() {
        scheduledExpansion?.cancel()
        scheduledExpansion = nil
    }

    private func applyTransition(
        _ state: OrbitState,
        animationDuration: TimeInterval,
        isFinal: Bool
    ) {
        apply(
            OrbitTransition(
                state: state,
                animationDuration: animationDuration,
                isFinal: isFinal
            )
        )
    }

    private func focusedIndex(for rotation: Float, cardCount: Int) -> Int {
        let slotAngle = (2 * Float.pi) / Float(cardCount)
        return positiveModulo(Int(round(-rotation / slotAngle)), cardCount)
    }

    private func snappedRotation(
        near currentRotation: Float,
        focusedIndex: Int,
        cardCount: Int
    ) -> Float {
        let fullTurn = 2 * Float.pi
        let slotAngle = fullTurn / Float(cardCount)
        let baseRotation = -Float(focusedIndex) * slotAngle
        let turns = round((currentRotation - baseRotation) / fullTurn)
        return baseRotation + turns * fullTurn
    }

    private func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        let remainder = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }
}
