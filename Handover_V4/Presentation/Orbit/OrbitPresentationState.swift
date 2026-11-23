// Flow: OrbitController -> OrbitPresentationState -> carousel layout + card disclosure + source outlines.
import Foundation

/// Stable clinical reading order, independent of dashboard rearrangement and wire messages.
enum OrbitCard: String, CaseIterable, Identifiable, Codable, Sendable {
    case situation = "Situation"
    case background = "Related_Background"
    case vitals = "Vitals"
    case infusions = "Infusions"
    case lines = "Lines"
    case labs = "Labs"
    case systems = "Systems"
    case plan = "Plan"
    case escalation = "Escalation"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .situation: "Situation"
        case .background: "Related Background"
        case .vitals: "Vitals"
        case .infusions: "Active Infusions"
        case .lines: "Lines & Access"
        case .labs: "Abnormal Labs"
        case .systems: "Systems Assessment"
        case .plan: "Treatment Plan"
        case .escalation: "Escalation"
        }
    }

    /// Authored apparatus names; narrative findings have no single equipment source.
    var equipmentNames: Set<String> {
        switch self {
        case .vitals: ["MachineB"]
        case .infusions: ["InfusionPump", "MachineF"]
        case .lines: ["IVDrip"]
        case .systems: ["Ventilator"]
        default: []
        }
    }
}

/// The card Orbit is settling or settled on, and whether it is disclosed.
struct OrbitTarget: Codable, Equatable, Sendable {
    let card: OrbitCard
    let isExpanded: Bool
}

/// Pure navigation rules. A revision prevents an old snap completion from expanding a new card.
struct OrbitPresentationState: Equatable {
    enum Phase { case inactive, scrubbing, settling, settled }
    private(set) var phase: Phase = .inactive
    /// Continuous card positions, allowing seamless wraparound through Situation.
    private(set) var position: Double = 0
    private(set) var expandedCard: OrbitCard?
    private(set) var revision = 0
    /// Settling normally discloses its card; a SharePlay peer may have collapsed it instead.
    private var expandsOnFinish = true

    var frontIndex: Int {
        let count = OrbitCard.allCases.count
        return (Int(position.rounded()) % count + count) % count
    }
    var frontCard: OrbitCard { OrbitCard.allCases[frontIndex] }
    var isMoving: Bool { phase == .scrubbing || phase == .settling }
    var sourceNames: Set<String> {
        phase == .settled ? (expandedCard?.equipmentNames ?? []) : []
    }

    /// Where navigation is heading, which is what SharePlay peers share.
    /// Nil while inactive or scrubbing, because a drag has not chosen a card yet.
    var target: OrbitTarget? {
        switch phase {
        case .inactive, .scrubbing: nil
        case .settling: OrbitTarget(card: frontCard, isExpanded: expandsOnFinish)
        case .settled: OrbitTarget(card: frontCard, isExpanded: expandedCard != nil)
        }
    }

    mutating func enter() {
        position = 0
        begin(.settling)
    }

    mutating func leave() { begin(.inactive) }

    /// Scrub input stays bounded before any floating-point to integer conversion.
    mutating func scrub(to value: Double) {
        guard phase != .inactive, value.isFinite else { return }
        position = value.truncatingRemainder(dividingBy: Double(OrbitCard.allCases.count))
        begin(.scrubbing)
    }

    mutating func snap() {
        guard phase != .inactive else { return }
        position = position.rounded()
        begin(.settling)
    }

    mutating func step(_ offset: Int) {
        guard phase != .inactive else { return }
        position = position.rounded() + Double(offset % OrbitCard.allCases.count)
        begin(.settling)
    }

    mutating func focus(_ card: OrbitCard) {
        guard phase != .inactive, let index = OrbitCard.allCases.firstIndex(of: card) else { return }
        let count = Double(OrbitCard.allCases.count)
        position = Double(index) + ((position - Double(index)) / count).rounded() * count
        begin(.settling)
    }

    /// Only the completion for the current movement may disclose its front card.
    mutating func finish(revision completedRevision: Int) {
        guard revision == completedRevision, phase == .settling else { return }
        phase = .settled
        expandedCard = expandsOnFinish ? frontCard : nil
    }

    mutating func toggleFront() {
        guard phase == .settled else { return }
        expandedCard = expandedCard == nil ? frontCard : nil
    }

    /// Heads for a peer's target, animating from wherever this carousel is.
    /// Returns whether a new settle began, so the caller can schedule its completion.
    mutating func adopt(_ target: OrbitTarget) -> Bool {
        guard phase != .inactive, self.target != target else { return false }
        if phase == .settled && frontCard == target.card {
            expandedCard = target.isExpanded ? frontCard : nil
            return false
        }
        focus(target.card)
        expandsOnFinish = target.isExpanded
        return true
    }

    private mutating func begin(_ phase: Phase) {
        revision += 1
        self.phase = phase
        expandedCard = nil
        expandsOnFinish = true
    }
}
