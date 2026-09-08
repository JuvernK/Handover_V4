// Flow: SectionID -> SBARGroup -> CardHeader badges + LauncherView's SBAR rail.
//
//  SBARGroup.swift
//  Handover_V4
//
//  Groups Spatial cards into the four handover categories used for card-header
//  badges and the persistent control window's group-toggle rail. Situation has
//  no SectionID of its own (it isn't a dashboard section), so it isn't part of
//  the SectionID mapping below and is handled as a standalone POI name.
//

import SwiftUI

enum SBARGroup: String, CaseIterable, Identifiable {
    case s, b, a, r

    var id: String { rawValue }

    var letter: String { rawValue.uppercased() }

    var color: Color {
        switch self {
        case .s: return DashboardTheme.accent
        case .b: return DashboardTheme.normal
        case .a: return DashboardTheme.warning
        case .r: return DashboardTheme.critical
        }
    }

    /// POI names (as authored in Reality Composer Pro) belonging to this group,
    /// used by the control window's S/B/A/R/ALL rail to toggle a whole group at once.
    var poiNames: [String] {
        switch self {
        case .s: return ["Situation"]
        case .b: return [SectionID.relatedBackground.poiName]
        case .a: return [SectionID.vitals, .infusions, .lines, .labs, .systems].map(\.poiName)
        case .r: return [SectionID.plan, .escalation].map(\.poiName)
        }
    }
}

extension SectionID {
    /// Spatial SBAR mapping per docs/spatial-cards.md.
    var sbarGroup: SBARGroup {
        switch self {
        case .relatedBackground: return .b
        case .vitals, .infusions, .lines, .labs, .systems: return .a
        case .plan, .escalation: return .r
        }
    }

    /// Exact POI name as authored in Reality Composer Pro (PointOfInterestComponent.name),
    /// distinct from `rawValue` which is lowercase/underscored for dashboard use.
    var poiName: String {
        switch self {
        case .vitals: return "Vitals"
        case .relatedBackground: return "Related_Background"
        case .infusions: return "Infusions"
        case .lines: return "Lines"
        case .labs: return "Labs"
        case .systems: return "Systems"
        case .plan: return "Plan"
        case .escalation: return "Escalation"
        }
    }
}

/// Small badge chip shown in a Spatial card's header and on its collapsed form.
struct SBARBadgeView: View {
    let group: SBARGroup

    var body: some View {
        Text(group.letter)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(group.color)
            .frame(width: 26, height: 26)
            .background(group.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(group.color.opacity(0.65), lineWidth: 1)
            }
            .accessibilityLabel("\(group.letter) card")
    }
}
