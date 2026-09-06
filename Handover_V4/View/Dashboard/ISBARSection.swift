// Flow: PatientDashboardView -> ISBARSectionView -> Patient summaries + supporting clinical cards.
import SwiftUI

extension ISBARSectionID {
    var letter: String {
        String(title.prefix(1))
    }

    var title: String {
        switch self {
        case .introduction: return "Introduction"
        case .situation: return "Situation"
        case .background: return "Background"
        case .assessment: return "Assessment"
        case .recommendation: return "Recommendation"
        }
    }

    /// A missing or blank authored summary is explicit, never inferred from partial records.
    func summary(for patient: Patient) -> String {
        let summary: String?
        switch self {
        case .introduction: summary = patient.diagnosis
        case .situation: summary = patient.handoverSummaries?.situation
        case .background: summary = patient.handoverSummaries?.background
        case .assessment: summary = patient.handoverSummaries?.assessment
        case .recommendation: summary = patient.handoverSummaries?.recommendation
        }
        guard let summary = summary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else { return "No handover summary recorded." }
        return summary
    }

    /// Systems occupy the side column; current vitals support the Assessment summary.
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
                VitalsCard(patient: patient)
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

/// Familiar disclosure header with an always-visible patient-specific main point.
/// The summary wraps in full so collapsing details never hides the clinical headline.
struct ISBARSectionView: View {
    let section: ISBARSectionID
    let patient: Patient
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                Text(section.letter)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DashboardTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(DashboardTheme.accentSoft, in: .rect(cornerRadius: 14))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 7) {
                    Text(section.title)
                        .font(.system(size: 21, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(section.summary(for: patient))
                        .font(.system(size: 16))
                        .foregroundStyle(DashboardTheme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(DashboardTheme.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .padding(.top, 12)
            }
            .padding(20)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy(duration: 0.25)) { isExpanded.toggle() }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityAction {
                withAnimation(.snappy(duration: 0.25)) { isExpanded.toggle() }
            }

            if isExpanded {
                Divider().padding(.horizontal, 20)
                section.content(for: patient)
                    .padding(16)
            }
        }
        .dashboardCardSurface(cornerRadius: 24)
    }
}
