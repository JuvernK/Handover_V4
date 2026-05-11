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
    
    /// Width the card renders at in 3D space. Most cards stay compact; Systems
    /// gets extra width so its adaptive internal grid can split into columns.
    private let defaultCardWidth: CGFloat = 360
    private let basicInformationCardWidth: CGFloat = 720
    private let systemsCardWidth: CGFloat = 760
    
    var body: some View {
        if isBasicInformationPOI {
            if isExpanded(cardName: poiName) {
                PatientHeaderView(patient: patient)
                    .glassBackgroundEffect(in: .rect(cornerRadius: 16))
                    .frame(width: basicInformationCardWidth)
            } else {
                CompactBasicInformationCard(patient: patient)
                    .frame(width: defaultCardWidth)
            }
        } else if let sectionID = SectionID(rawValue: normalizedPOIName) {
            if isExpanded(sectionID) {
                sectionID.view(for: patient)
                    .frame(width: expandedWidth(for: sectionID))
            } else {
                CompactSpatialCard(sectionID: sectionID)
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

    private func isExpanded(cardName: String) -> Bool {
        appModel.cardStates[cardName] ?? true
    }

    private func isExpanded(_ sectionID: SectionID) -> Bool {
        appModel.cardStates[poiName] ?? appModel.cardStates[sectionID.rawValue] ?? true
    }

    private func expandedWidth(for sectionID: SectionID) -> CGFloat {
        sectionID == .systems ? systemsCardWidth : defaultCardWidth
    }
}

private struct CompactBasicInformationCard: View {
    let patient: Patient

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Basic Information")
                    .font(.system(size: 17, weight: .semibold))
                Text("\(patient.name) · \(patient.bedNumber)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.up.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassBackgroundEffect(in: .rect(cornerRadius: 16))
        .hoverEffect()
    }
}

private struct CompactSpatialCard: View {
    let sectionID: SectionID

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sectionID.spatialSystemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(.tint)

            Text(sectionID.displayName)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Image(systemName: "chevron.up.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassBackgroundEffect(in: .rect(cornerRadius: 16))
        .hoverEffect()
    }
}

private extension SectionID {
    var spatialSystemImage: String {
        switch self {
        case .vitals: return "waveform.path.ecg"
        case .infusions: return "ivfluid.bag"
        case .lines: return "point.3.connected.trianglepath.dotted"
        case .labs: return "testtube.2"
        case .systems: return "person.text.rectangle"
        case .plan: return "list.bullet.clipboard"
        case .escalation: return "phone.arrow.up.right.fill"
        }
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
