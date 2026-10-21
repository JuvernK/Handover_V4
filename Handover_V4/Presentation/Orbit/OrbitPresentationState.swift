// Flow: OrbitController -> OrbitPresentationState -> carousel layout + card disclosure + source outlines.
import Foundation

/// Stable clinical reading order, independent of dashboard rearrangement and wire messages.
enum OrbitCard: String, CaseIterable, Identifiable {
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

/// Pure navigation rules. A revision prevents an old snap completion from expanding a new card.
struct OrbitPresentationState: Equatable {
    enum Phase { case inactive, scrubbing, settling, settled }
    private(set) var phase: Phase = .inactive
    /// Continuous card positions, allowing seamless wraparound through Situation.
    private(set) var position: Double = 0
    private(set) var expandedCard: OrbitCard?
    private(set) var revision = 0

    var frontIndex: Int {
        let count = OrbitCard.allCases.count
        return (Int(position.rounded()) % count + count) % count
    }
    var frontCard: OrbitCard { OrbitCard.allCases[frontIndex] }
    var isMoving: Bool { phase == .scrubbing || phase == .settling }
    var sourceNames: Set<String> {
        phase == .settled ? (expandedCard?.equipmentNames ?? []) : []
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
        expandedCard = frontCard
    }

    mutating func toggleFront() {
        guard phase == .settled else { return }
        expandedCard = expandedCard == nil ? frontCard : nil
    }

    private mutating func begin(_ phase: Phase) {
        revision += 1
        self.phase = phase
        expandedCard = nil
    }
}
