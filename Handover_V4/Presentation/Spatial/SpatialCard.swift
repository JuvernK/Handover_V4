//
//  SpatialCardView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 5/5/2026.
//

//  Renders a dashboard card as a RealityKit attachment in the immersive space.
//
//  The POI's name (from Reality Composer Pro) is resolved to a SectionID,
//  and the corresponding dashboard card is rendered at a fixed width suitable
//  for floating in 3D space.
//
//  The full/compact state is owned by AppModel so it can be synchronized with
//  SharePlay for every participant.
//

import SwiftUI

struct SpatialCardView: View {
    @Environment(AppModel.self) private var appModel

    /// The POI name as authored in Reality Composer Pro.
    let poiName: String

    let patient: Patient

    /// Width the card renders at in 3D space. Attachments don't reflow content the
    /// way a window would when resized, so a card with a lot of content needs a
    /// wider fixed width chosen up front rather than growing on demand.
    private let defaultCardWidth: CGFloat = 360
    private let mediumCardWidth: CGFloat = 480
    private let wideCardWidth: CGFloat = 620
    private let basicInformationCardWidth: CGFloat = 720
    private let systemsCardWidth: CGFloat = 760
    private let immersiveCardScale: CGFloat = 1.5

    var body: some View {
        cardContent
            .scaleEffect(immersiveCardScale)
    }

    @ViewBuilder
    private var cardContent: some View {
        if isBasicInformationPOI {
            // Permanent patient introduction: always fully visible, no disclosure, no badge.
            PatientHeaderView(patient: patient)
                .dashboardCardSurface(cornerRadius: 16)
                .frame(width: basicInformationCardWidth)
        } else if isSituationPOI {
            if isExpanded(cardName: poiName) {
                SituationCard(patient: patient)
                    .frame(width: width(forItemCount: patient.escalation.mainConcerns.count))
            } else {
                CompactSpatialCard(title: "Situation", badge: .s)
                    .frame(width: defaultCardWidth)
            }
        } else if let sectionID = SectionID(rawValue: normalizedPOIName) {
            if isExpanded(sectionID) {
                sectionID.view(for: patient)
                    .frame(width: expandedWidth(for: sectionID))
            } else {
                CompactSpatialCard(title: sectionID.displayName, badge: sectionID.sbarGroup)
                    .frame(width: defaultCardWidth)
            }
        } else {
            UnknownPOIView(poiName: poiName)
                .frame(width: defaultCardWidth)
        }
    }

    private var normalizedPOIName: String {
        poiName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    private var isBasicInformationPOI: Bool {
        normalizedPOIName == "basic_information"
    }

    private var isSituationPOI: Bool {
        normalizedPOIName == "situation"
    }

    private func isExpanded(cardName: String) -> Bool {
        appModel.cardStates[cardName] ?? true
    }

    private func isExpanded(_ sectionID: SectionID) -> Bool {
        appModel.cardStates[poiName] ?? appModel.cardStates[sectionID.rawValue] ?? true
    }

    /// Systems keeps its own extra-wide tier since its internal grid needs the
    /// room to split into columns; every other section scales with how many
    /// items it actually has to show.
    private func expandedWidth(for sectionID: SectionID) -> CGFloat {
        if sectionID == .systems { return systemsCardWidth }
        return width(forItemCount: itemCount(for: sectionID))
    }

    private func itemCount(for sectionID: SectionID) -> Int {
        switch sectionID {
        case .vitals: return patient.vitals.count
        case .relatedBackground:
            return patient.relatedBackground.pastMedicalHistory.count
                + patient.relatedBackground.socialHistory.count
                + patient.relatedBackground.relevantContext.count
        case .infusions: return patient.infusions.count
        case .lines: return patient.lines.count
        case .labs: return patient.labs.count
        case .systems: return patient.systems.count
        case .plan: return patient.plan.count
        case .escalation:
            return patient.escalation.mainConcerns.count + patient.escalation.triggers.count
        }
    }

    private func width(forItemCount count: Int) -> CGFloat {
        switch count {
        case ..<5: return defaultCardWidth
        case 5..<8: return mediumCardWidth
        default: return wideCardWidth
        }
    }
}

/// Collapsed form of any Spatial card except Basic Information: badge and title only,
/// with the full content hidden until tapped again.
private struct CompactSpatialCard: View {
    let title: String
    let badge: SBARGroup

    var body: some View {
        HStack(spacing: 12) {
            SBARBadgeView(group: badge)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DashboardTheme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Image(systemName: "chevron.up.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DashboardTheme.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .dashboardCardSurface(cornerRadius: 16)
        .hoverEffect()
    }
}

// MARK: - Fallback for unrecognised POIs

/// Shown when the POI name doesn't match any known SectionID.
/// Helps debugging when RCP names drift out of sync with code.
private struct UnknownPOIView: View {
    let poiName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.orange)
                Text("Unknown POI")
                    .font(.headline)
            }

            Text("\"\(poiName)\"")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("No dashboard section matches this name. Check the POI name in Reality Composer Pro against the SectionID enum.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassBackgroundEffect(in: .rect(cornerRadius: 16))
    }
}
