// Flow: AppModel + OrbitNavigationView + ring gestures -> OrbitController -> OrbitPresentationState.
import Foundation
import Observation

/// Owns Orbit interaction and cancellable settling for the navigation controls and SharePlay peers.
@MainActor @Observable
final class OrbitController {
    private(set) var state = OrbitPresentationState()
    @ObservationIgnored private var completion: Task<Void, Never>?
    static let settleDuration: TimeInterval = 0.35

    /// Start a fresh carousel entry on Situation, initially collapsed.
    func enter() { state.enter(); scheduleCompletion() }
    /// Cancel pending expansion when another mode or scene takes over.
    func leave() { completion?.cancel(); completion = nil; state.leave() }
    /// Continuous input suppresses disclosure and source outlines until release.
    func scrub(to position: Double) {
        guard position.isFinite else { return }
        completion?.cancel()
        completion = nil
        state.scrub(to: position)
    }
    /// Release continuous input onto the nearest clinical card.
    func snap() { state.snap(); scheduleCompletion() }
    /// Move by clinical reading order, wrapping across either end.
    func step(_ offset: Int) { state.step(offset); scheduleCompletion() }
    /// A front-card tap toggles disclosure; other cards navigate to the reading position.
    func select(_ card: OrbitCard) {
        if state.frontCard == card && state.phase == .settled {
            state.toggleFront()
        } else {
            state.focus(card)
            scheduleCompletion()
        }
    }

    /// Follow a SharePlay peer's settled or settling card without echoing it back.
    func adopt(_ target: OrbitTarget) {
        if state.adopt(target) { scheduleCompletion() }
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
