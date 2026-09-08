// Flow: AppModel + OrbitNavigationView + ring gestures -> OrbitController -> OrbitPresentationState.
import Foundation
import Observation

/// Owns local Orbit interaction and cancellable settling, shared by all three navigation controls.
@MainActor @Observable
final class OrbitController {
    // TODO: Synchronize navigation/disclosure and late-join state only after the explicit
    // SharePlay follow-up go-ahead. See docs/orbit-source-outlines.md.
    private(set) var state = OrbitPresentationState()
    @ObservationIgnored private var completion: Task<Void, Never>?
    static let settleDuration: TimeInterval = 0.35

    func enter() { state.enter(); scheduleCompletion() }
    func leave() { completion?.cancel(); completion = nil; state.leave() }
    func scrub(to position: Double) {
        guard position.isFinite else { return }
        completion?.cancel()
        completion = nil
        state.scrub(to: position)
    }
    func snap() { state.snap(); scheduleCompletion() }
    func step(_ offset: Int) { state.step(offset); scheduleCompletion() }
    func select(_ card: OrbitCard) {
        if state.frontCard == card && state.phase == .settled {
            state.toggleFront()
        } else {
            state.focus(card)
            scheduleCompletion()
        }
    }

    private func scheduleCompletion() {
        completion?.cancel()
        let revision = state.revision
        completion = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(Self.settleDuration))
            } catch {
                return
            }
            self?.state.finish(revision: revision)
            self?.completion = nil
        }
    }
}
