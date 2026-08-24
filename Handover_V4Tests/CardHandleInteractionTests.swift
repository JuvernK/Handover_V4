import Testing
@testable import Handover_V4

struct CardHandleInteractionTests {
    // MARK: - isDragConfirmed

    @Test
    func distanceBelowThresholdIsNotConfirmed() {
        #expect(
            CardHandleInteraction.isDragConfirmed(
                distance: 0.01,
                alreadyConfirmed: false,
                threshold: 0.02
            ) == false
        )
    }

    @Test
    func distanceAtThresholdConfirms() {
        #expect(
            CardHandleInteraction.isDragConfirmed(
                distance: 0.02,
                alreadyConfirmed: false,
                threshold: 0.02
            )
        )
    }

    @Test
    func distanceAboveThresholdConfirms() {
        #expect(
            CardHandleInteraction.isDragConfirmed(
                distance: 0.05,
                alreadyConfirmed: false,
                threshold: 0.02
            )
        )
    }

    @Test
    func onceConfirmedStaysConfirmedEvenIfDistanceDropsBack() {
        #expect(
            CardHandleInteraction.isDragConfirmed(
                distance: 0.001,
                alreadyConfirmed: true,
                threshold: 0.02
            )
        )
    }

    // MARK: - resolveOutcome

    @Test
    func confirmedDragResolvesToMovedRegardlessOfToggleEligibility() {
        let state = CardTouchState(
            startPosition: .zero,
            isEligibleForToggle: true,
            isDragConfirmed: true
        )

        let outcome = CardHandleInteraction.resolveOutcome(
            for: state,
            entityPosition: SIMD3<Float>(1, 2, 3)
        )

        #expect(outcome == .moved(SIMD3<Float>(1, 2, 3)))
    }

    @Test
    func unconfirmedTouchEligibleForToggleResolvesToToggled() {
        let state = CardTouchState(
            startPosition: .zero,
            isEligibleForToggle: true,
            isDragConfirmed: false
        )

        let outcome = CardHandleInteraction.resolveOutcome(
            for: state,
            entityPosition: .zero
        )

        #expect(outcome == .toggled)
    }

    @Test
    func unconfirmedTouchIneligibleForToggleResolvesToNone() {
        let state = CardTouchState(
            startPosition: .zero,
            isEligibleForToggle: false,
            isDragConfirmed: false
        )

        let outcome = CardHandleInteraction.resolveOutcome(
            for: state,
            entityPosition: .zero
        )

        #expect(outcome == .none)
    }
}
