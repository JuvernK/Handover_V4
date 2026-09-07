// Flow: DashboardView -> PatientDashboardView -> ISBAR navigation + patient summaries + systems assessment.
import SwiftUI

/// Owns disclosure and navigation while the patient header and systems panel stay in view.
struct PatientDashboardView: View {
    let patient: Patient
    @State private var presentation = DashboardPresentationState()
    @State private var navigationRequest: ISBARSectionID?

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                let isWide = geometry.size.width >= 1100 && geometry.size.height >= 650
                Group {
                    if isWide {
                        HStack(alignment: .top, spacing: 20) {
                            navigation(isHorizontal: false)
                                .frame(width: 76)
                                .padding(.top, 32)

                            VStack(spacing: 0) {
                                PatientHeaderView(patient: patient)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Divider().padding(.horizontal, 20)
                                ScrollView {
                                    sections.padding(18)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .dashboardPanel(cornerRadius: 28)

                            // A sibling scroll region keeps the systems overview stationary
                            // while the main reader scrolls, like the former vitals panel.
                            ScrollView {
                                systems.padding(16)
                            }
                            .frame(width: min(460, geometry.size.width * 0.34), alignment: .top)
                            .frame(maxHeight: .infinity)
                            .dashboardPanel(cornerRadius: 28)
                            .padding(.top, 32)
                        }
                        .padding(14)
                    } else {
                        // One scroll region keeps short windows fully reachable.
                        ScrollView {
                            VStack(spacing: 16) {
                                patientHeader.id(ISBARSectionID.introduction)
                                navigation(isHorizontal: true)
                                ForEach(ISBARSectionID.detailSections) { section in
                                    sectionView(section)
                                    if section == .assessment { systems }
                                }
                            }
                            .padding(18)
                        }
                        .dashboardPanel(cornerRadius: 28)
                        .padding(14)
                    }
                }
                .task(id: navigationRequest) {
                    guard let destination = navigationRequest else { return }
                    // Wait for expanded content to enter layout before finding its anchor.
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    withAnimation(.snappy(duration: 0.25)) {
                        // Introduction is already pinned in wide windows; return the reader to the top.
                        proxy.scrollTo(isWide && destination == .introduction ? ISBARSectionID.situation : destination,
                                       anchor: .top)
                    }
                    navigationRequest = nil
                }
            }
        }
        .environment(\.isDashboardSurface, true)
        .foregroundStyle(DashboardTheme.foreground)
        .tint(DashboardTheme.accent)
    }

    private func navigation(isHorizontal: Bool) -> some View {
        ISBARNavColumn(presentation: $presentation, isHorizontal: isHorizontal) { destination in
            navigationRequest = destination
        }
    }

    private var patientHeader: some View {
        PatientHeaderView(patient: patient)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dashboardPanel(cornerRadius: 28)
    }

    private var systems: some View {
        SystemsAssessmentCard(patient: patient, isHandoverSidebar: true)
    }

    private var sections: some View {
        VStack(spacing: 14) {
            ForEach(ISBARSectionID.detailSections) { section in
                sectionView(section)
            }
        }
    }

    private func sectionView(_ section: ISBARSectionID) -> some View {
        ISBARSectionView(
            section: section,
            patient: patient,
            isExpanded: Binding(
                get: { presentation.isExpanded(section) },
                set: { presentation.setExpanded($0, for: section) }
            )
        )
        .id(section)
    }
}

// MARK: - Navigation shortcuts

/// Persistent shortcuts preserve the original ISBAR navigation alongside the systems panel.
private struct ISBARNavColumn: View {
    @Binding var presentation: DashboardPresentationState
    var isHorizontal = false
    let onFocus: (ISBARSectionID) -> Void

    var body: some View {
        let layout = isHorizontal
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: 10))
        layout {
            ForEach(ISBARSectionID.allCases) { section in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        presentation.focus(section)
                        onFocus(section)
                    }
                } label: {
                    Text(section.letter)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(isHighlighted(section) ? DashboardTheme.accent : DashboardTheme.secondary)
                        .frame(width: 44, height: 44)
                        .background(isHighlighted(section) ? DashboardTheme.accentSoft : DashboardTheme.glassRaised,
                                    in: .rect(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(DashboardTheme.stroke, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                .accessibilityLabel(section.title)
                .accessibilityValue(presentation.focusedSection == section ? "Selected" : "")
            }
            if !isHorizontal { Divider().frame(width: 24).padding(.vertical, 4) }
            Button {
                withAnimation(.snappy(duration: 0.25)) { presentation.toggleAll() }
            } label: {
                Text("ALL")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DashboardTheme.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .accessibilityLabel(presentation.allExpanded ? "Collapse all sections" : "Expand all sections")
        }
        .padding(16)
        .dashboardPanel(cornerRadius: 26)
    }

    private func isHighlighted(_ section: ISBARSectionID) -> Bool {
        presentation.isExpanded(section) || presentation.focusedSection == section
    }
}

// MARK: - Section presentation

private extension ISBARSectionID {
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
private struct ISBARSectionView: View {
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
