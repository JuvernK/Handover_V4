//
//  SourceCoupling.swift
//  Handover_V4
//
//  Couples each clinical card to the real-world origin of its data (its Source)
//  and gives each card a distinct identity colour. See docs/adr/0001-source-coupling.md
//  and CONTEXT.md for the domain model.
//

import SwiftUI

/// The real-world origin of a card's clinical data. Exactly one per card.
enum ClinicalSource: Equatable {
    /// One-or-more named meshes in the ICU scene. One logical apparatus may be
    /// several meshes (e.g. an infusion stack); all glow together.
    case equipment([String])

    /// A body region shown as an SF Symbol placard, anchored to an authored
    /// point on the patient. `anchor` is the RCP entity name of that point.
    case organ(symbol: String, anchor: String)

    /// No physical origin. Nothing highlights when the card is active.
    case none
}

extension SectionID {
    /// The Source this card is coupled to.
    ///
    /// Entity names are the RCP hierarchy names under `Root/ICU_env/ICUArea/…`,
    /// verified against the imported ICU USDZ.
    var clinicalSource: ClinicalSource {
        switch self {
        case .vitals:
            // Free-standing monitor only; the headboard-mounted monitor is fused
            // into `Headboard` and cannot be isolated.
            return .equipment(["MachineB"])
        case .infusions:
            return .equipment(["InfusionPump", "MachineF"])
        case .lines:
            return .equipment(["IVDrip"])
        case .systems:
            return .equipment(["Ventilator"])
        case .labs:
            // Bloods derive from the patient, not room equipment.
            return .organ(
                symbol: "drop.fill",
                anchor: ImmersiveConfiguration.torsoOrganAnchorName
            )
        case .plan, .escalation, .relatedBackground:
            return .none
        }
    }

    /// Distinct colour for this card's border/text, reused as its Source Highlight
    /// colour so the card and its Source read as a matched pair. Constrained to
    /// hues that avoid ICU alarm semantics (reserved reds/ambers).
    var identityColor: Color {
        switch self {
        case .vitals:            return .mint
        case .relatedBackground: return .brown
        case .infusions:         return .blue
        case .lines:             return .indigo
        case .labs:              return .purple
        case .systems:           return .cyan
        case .plan:              return .teal
        case .escalation:        return .pink
        }
    }
}
