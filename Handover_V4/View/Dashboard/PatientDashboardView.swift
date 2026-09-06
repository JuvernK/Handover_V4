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
