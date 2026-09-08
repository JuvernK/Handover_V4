// Flow: standalone checks -> OrbitPresentationState + OrbitController -> navigation/disclosure contract.
import Foundation

@main
struct OrbitPresentationStateChecks {
    @MainActor static func main() async {
        precondition(OrbitCard.allCases.map(\.rawValue) == [
            "Situation", "Related_Background", "Vitals", "Infusions", "Lines", "Labs", "Systems", "Plan", "Escalation"
        ])
        var state = OrbitPresentationState()
        state.enter()
        precondition(state.frontCard == .situation && state.expandedCard == nil && state.sourceNames.isEmpty)
        state.finish(revision: state.revision)
        precondition(state.expandedCard == .situation && state.sourceNames.isEmpty)
        state.step(-1)
        precondition(state.frontCard == .escalation && state.expandedCard == nil)
        state.step(1)
        precondition(state.frontCard == .situation)
        state.focus(.vitals)
        let oldRevision = state.revision
        state.focus(.infusions)
        state.finish(revision: oldRevision)
        precondition(state.expandedCard == nil)
        state.finish(revision: state.revision)
        precondition(state.sourceNames == ["InfusionPump", "MachineF"])
        state.toggleFront()
        precondition(state.expandedCard == nil && state.sourceNames.isEmpty)
        state.toggleFront()
        precondition(state.expandedCard == .infusions)
        state.scrub(to: 8.8)
        precondition(state.sourceNames.isEmpty && state.expandedCard == nil)
        state.snap()
        state.finish(revision: state.revision)
        precondition(state.frontCard == .situation && state.expandedCard == .situation)
        for card in OrbitCard.allCases {
            state.focus(card)
            precondition(state.sourceNames.isEmpty)
            state.finish(revision: state.revision)
            precondition(state.expandedCard == card && state.sourceNames == card.equipmentNames)
        }
        for invalid in [Double.nan, .infinity, -.infinity] {
            let before = state
            state.scrub(to: invalid)
            precondition(state == before)
        }
        for value in [-Double.greatestFiniteMagnitude, -99.6, -0.6, 0.4, 4.6, Double.greatestFiniteMagnitude] {
            state.scrub(to: value)
            state.snap()
            precondition((0..<9).contains(state.frontIndex))
        }
        for _ in 0..<500 {
            state.step(1)
            state.finish(revision: state.revision)
            precondition(state.expandedCard == state.frontCard)
        }
        let exitRevision = state.revision
        state.leave()
        state.finish(revision: exitRevision)
        precondition(state.phase == .inactive && state.expandedCard == nil && state.sourceNames.isEmpty)
        state.enter()
        precondition(state.frontCard == .situation && state.expandedCard == nil)

        // Exercise the actual cancellable scheduler, including exit/re-entry and rapid control changes.
        let controller = OrbitController()
        controller.enter()
        controller.step(2)
        controller.scrub(to: 4.2)
        try! await Task.sleep(for: .seconds(0.45))
        precondition(controller.state.phase == .scrubbing && controller.state.expandedCard == nil)
        controller.snap()
        controller.leave()
        try! await Task.sleep(for: .seconds(0.45))
        precondition(controller.state.phase == .inactive && controller.state.expandedCard == nil)
        controller.enter()
        controller.step(2)
        try! await Task.sleep(for: .seconds(0.45))
        precondition(controller.state.expandedCard == .vitals && controller.state.sourceNames == ["MachineB"])
        controller.leave()
        controller.enter()
        try! await Task.sleep(for: .seconds(0.45))
        precondition(controller.state.expandedCard == .situation)
        print("Orbit navigation, source eligibility, cancellation, and re-entry checks passed")
    }
}
