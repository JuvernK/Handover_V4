//
//  ISBARSection.swift
//  Handover_V4
//
//  Defines the five ISBAR groupings the dashboard is organised into, and the
//  collapsible accordion chrome each group is rendered inside.
//
//  Layout intent: match the "ISBAR Patient Dashboard" reference — a single
//  vertical list of Introduction / Situation / Background / Assessment /
//  Recommendation, each a collapsible glass card with a badge showing an
//  at-a-glance alert count.
//

import SwiftUI

extension ISBARSectionID {
    var letter: String {
        switch self {
        case .introduction:   return "I"
        case .situation:      return "S"
        case .background:     return "B"
        case .assessment:     return "A"
        case .recommendation: return "R"
        }
    }

    var title: String {
        switch self {
        case .introduction:   return "Introduction"
        case .situation:      return "Situation"
        case .background:     return "Background"
        case .assessment:     return "Assessment"
        case .recommendation: return "Recommendation"
        }
    }

    var subtitle: String {
        switch self {
        case .introduction:   return "Identifiers, code status and allergy alerts"
        case .situation:      return "Current diagnosis and main concerns"
        case .background:     return "Presenting complaint, history and relevant context"
        case .assessment:     return "Systems review, bloods, infusions and invasive devices"
        case .recommendation: return "Treatment plan, escalation triggers and family"
        }
    }

    /// Number of authored records summarized by the collapsed section.
    func alertCount(for patient: Patient) -> Int {
        switch self {
        case .introduction:
            return patient.allergies.count
        case .situation:
            return patient.escalation.mainConcerns.count
        case .background:
            return 0
        case .assessment:
            return patient.systems.count
        case .recommendation:
            return patient.plan.filter { $0.priority == .urgent }.count
        }
    }

    func countLabel(_ count: Int) -> String {
        switch self {
        case .introduction: return "\(count) ALLERG\(count == 1 ? "Y" : "IES")"
        case .situation: return "\(count) CONCERN\(count == 1 ? "" : "S")"
        case .background: return "HISTORY"
        case .assessment: return "\(count) SYSTEM\(count == 1 ? "" : "S")"
        case .recommendation: return "\(count) URGENT"
        }
    }

    /// Builds the section's content, given the currently displayed patient.
    @ViewBuilder
    func content(for patient: Patient) -> some View {
        switch self {
        case .introduction:
            PatientHeaderView(patient: patient)

        case .situation:
            SituationCard(patient: patient)

        case .background:
            RelatedBackgroundCard(patient: patient)

        case .assessment:
            VStack(spacing: 12) {
                SystemsAssessmentCard(patient: patient)
                LabsCard(patient: patient)
                InfusionsCard(patient: patient)
                LinesAccessCard(patient: patient)
            }

        case .recommendation:
            VStack(spacing: 12) {
                PlanCard(patient: patient)
                EscalationCard(patient: patient)
                FamilyCard(patient: patient)
            }
        }
    }
}

// MARK: - Accordion chrome

/// A single collapsible ISBAR row: a tappable header (letter badge, title,
/// subtitle, alert count, chevron) plus content shown only when expanded.
///
/// Uses a plain tap gesture rather than a `Button` — a `Button` here causes
/// visionOS to render the row as a floating "hover platter" that detaches
/// from its layout position and overlaps the row above it.
struct ISBARSectionView: View {
    let section: ISBARSectionID
    let patient: Patient
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.snappy(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(section.title)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                Divider().padding(.horizontal, 12)

                section.content(for: patient)
                    .padding(16)
            }
        }
        .glassBackgroundEffect(in: .rect(cornerRadius: 26))
    }

    private var header: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.secondary.opacity(0.12))
                Text(section.letter)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(section.title)
                    .font(.system(size: 21, weight: .semibold))
                Text(section.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            let alertCount = section.alertCount(for: patient)
            if alertCount > 0 {
                Text(section.countLabel(alertCount))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .contentShape(Rectangle())
    }
}

// MARK: - Left-side ISBAR letter nav

/// Letter shortcuts open and focus a section; ALL toggles disclosure together.
struct ISBARNavColumn: View {
    let patient: Patient
    @Binding var presentation: DashboardPresentationState
    var isHorizontal = false
    let onFocus: (ISBARSectionID) -> Void

    var body: some View {
        let layout = isHorizontal
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: 10))
        layout {
            ForEach(ISBARSectionID.allCases) { section in
                NavPill(
                    letter: section.letter,
                    isSelected: presentation.focusedSection == section,
                    hasAlert: section == .introduction && !patient.allergies.isEmpty
                ) {
                    withAnimation(.snappy(duration: 0.25)) {
                        presentation.focus(section)
                        onFocus(section)
                    }
                }
                .accessibilityLabel(section.title)
            }

            if !isHorizontal {
                Divider().padding(.vertical, 4)
            }

            Text("ALL")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.snappy(duration: 0.25)) {
                        presentation.toggleAll()
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(presentation.allExpanded ? "Collapse all sections" : "Expand all sections")
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .glassBackgroundEffect(in: .rect(cornerRadius: 26))
    }
}

private struct NavPill: View {
    let letter: String
    let isSelected: Bool
    let hasAlert: Bool
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.12))
                .frame(width: 44, height: 44)

            Text(letter)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .frame(width: 44, height: 44)

            if hasAlert {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .offset(x: -2, y: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

// MARK: - Pinned live vitals sidebar

/// Always-visible vitals panel for wide windows, so vitals stay in view no
/// matter which ISBAR section is currently expanded.
struct LiveVitalsSidebar: View {
    let patient: Patient

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Vitals", systemImage: "waveform.path.ecg")

            Divider().padding(.horizontal, 12)

            VStack(spacing: 10) {
                if patient.vitals.isEmpty {
                    Text("No vitals recorded")
                        .foregroundStyle(.secondary)
                }
                ForEach(patient.vitals) { vital in
                    VitalBox(vital: vital)
                }
            }
            .padding(16)
        }
        .glassBackgroundEffect(in: .rect(cornerRadius: 16))
    }
}
