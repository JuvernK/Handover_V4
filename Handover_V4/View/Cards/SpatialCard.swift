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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let destination: PointOfInterestDestination
    let unknownPOIName: String?
    
    let patient: Patient
    
    /// Width the card renders at in 3D space. Most cards stay compact; Systems
    /// gets extra width so its adaptive internal grid can split into columns.
    private let defaultCardWidth: CGFloat = 360
    private let basicInformationCardWidth: CGFloat = 720
    private let systemsCardWidth: CGFloat = 760
    private let immersiveCardScale: CGFloat = 1.5
    
    var body: some View {
        cardContent
            .scaleEffect(immersiveCardScale)
    }
    
    @ViewBuilder
    private var cardContent: some View {
        switch destination {
        case .basicInformation:
            if isExpanded {
                PatientHeaderView(patient: patient)
                    .cardContainerBackground()
                    .frame(width: basicInformationCardWidth)
                    .spatialExpansionControl(
                        isExpanded: true,
                        isEnabled: !appModel.orbitState.isActive,
                        action: toggleExpansion
                    )
            } else {
                CompactBasicInformationCard(patient: patient)
                    .frame(width: defaultCardWidth)
                    .spatialExpansionControl(
                        isExpanded: false,
                        tapStripHeight: CardChrome.expansionTapAreaHeight,
                        action: toggleExpansion
                    )
            }

        case .section(let sectionID):
            if isExpanded {
                sectionID.view(for: patient)
                    .frame(width: expandedWidth(for: sectionID))
                    .spatialExpansionControl(
                        isExpanded: true,
                        tapStripHeight: CardChrome.expansionTapAreaHeight,
                        action: toggleExpansion
                    )
                    .identityStyled(sectionID)
            } else {
                CompactSpatialCard(sectionID: sectionID)
                    .frame(width: defaultCardWidth)
                    .spatialExpansionControl(
                        isExpanded: false,
                        tapStripHeight: CardChrome.expansionTapAreaHeight,
                        action: toggleExpansion
                    )
                    .identityStyled(sectionID)
            }

        case .unknown:
            UnknownPOIView(poiName: unknownPOIName ?? "Unknown")
                .frame(width: defaultCardWidth)
        }
    }

    private var isExpanded: Bool {
        if appModel.orbitState.isActive {
            if cardID == .basicInformation {
                return true
            }
            return appModel.orbitState.expandedCardName
                == cardID?.canonicalName
        }
        return normalModeIsExpanded
    }

    private func expandedWidth(for sectionID: SectionID) -> CGFloat {
        sectionID == .systems ? systemsCardWidth : defaultCardWidth
    }

    private func toggleExpansion() {
        guard let cardID else { return }
        let changes: () -> Void = {
            if appModel.orbitState.isActive {
                let canonicalName = cardID.canonicalName
#if DEBUG
                print(
                    "[OrbitDebug] toggleExpansion tapped: card=\(canonicalName), "
                        + "focused=\(appModel.orbitState.focusedCardName ?? "nil"), "
                        + "expandedBefore=\(appModel.orbitState.expandedCardName ?? "nil")"
                )
#endif
                if appModel.orbitState.focusedCardName == canonicalName {
                    appModel.toggleFocusedOrbitCardExpansion()
                } else {
                    appModel.focusOrbitCard(named: canonicalName)
                }
                return
            }

#if DEBUG
            print(
                "[CardDragDebug] toggleExpansion tapped: card=\(cardID.canonicalName), "
                    + "expandedBefore=\(normalModeIsExpanded)"
            )
#endif
            appModel.setCardState(
                cardID,
                isExpanded: !normalModeIsExpanded
            )
        }

        let animation: Animation? = reduceMotion
            ? nil
            : .spring(response: 0.5, dampingFraction: 0.8)
        withAnimation(animation) {
            changes()
        }
    }

    private var normalModeIsExpanded: Bool {
        guard let cardID else { return true }
        return appModel.cardStates[cardID] ?? true
    }

    private var cardID: ClinicalCardID? {
        destination.cardID
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardContainerBackground()
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardContainerBackground()
        .hoverEffect()
    }
}

private extension View {
    /// - Parameter tapStripHeight: when set, the whole top strip of this
    ///   height becomes tappable (the card's header bar, or effectively the
    ///   whole card when it's collapsed to a single row) instead of only the
    ///   small chevron icon. Leave `nil` where the top of the content already
    ///   has its own interactive elements (e.g. expanded Basic Information's
    ///   diagnosis abbreviation), so the strip can't steal their taps.
    func spatialExpansionControl(
        isExpanded: Bool,
        isEnabled: Bool = true,
        tapStripHeight: CGFloat? = nil,
        action: @escaping () -> Void
    ) -> some View {
        overlay(alignment: .top) {
            if isEnabled, let tapStripHeight {
                Button(action: action) {
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: tapStripHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                .accessibilityLabel(
                    isExpanded ? "Collapse card" : "Expand card"
                )
            }
        }
        .overlay(alignment: .topTrailing) {
            if isEnabled {
                // The tap strip above already owns tap/hover/accessibility
                // when it's present, so the icon is decorative in that case
                // rather than a second stacked control over the same region.
                if tapStripHeight != nil {
                    expansionIcon(isExpanded: isExpanded)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .padding(.top, 8)
                        .padding(.trailing, 10)
                } else {
                    Button(action: action) {
                        expansionIcon(isExpanded: isExpanded)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .accessibilityLabel(
                        isExpanded ? "Collapse card" : "Expand card"
                    )
                    .padding(.top, 8)
                    .padding(.trailing, 10)
                }
            }
        }
    }

    private func expansionIcon(isExpanded: Bool) -> some View {
        Image(
            systemName: isExpanded
                ? "chevron.down.circle.fill"
                : "chevron.up.circle.fill"
        )
        .font(.system(size: 20, weight: .semibold))
        .frame(width: 36, height: 36)
    }

    /// Applies a card's Card Identity Colour to its border and tinted glyphs so
    /// the card reads as a matched pair with its highlighted Source. See
    /// CONTEXT.md and docs/adr/0001-source-coupling.md.
    func identityStyled(_ sectionID: SectionID) -> some View {
        self
            .tint(sectionID.identityColor)
            .overlay(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadius, style: .continuous)
                    .strokeBorder(sectionID.identityColor.opacity(0.9), lineWidth: 2)
            )
    }
}

private extension SectionID {
    var spatialSystemImage: String {
        switch self {
        case .vitals: return "waveform.path.ecg"
        case .relatedBackground: return "person.text.rectangle"
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
        .cardContainerBackground()
    }
}
