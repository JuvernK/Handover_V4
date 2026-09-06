// Flow: DashboardView -> PatientDashboardView -> DashboardPresentationState + ISBARSection views.
import SwiftUI

/// Patient reading experience with no window controls or RealityKit dependencies.
///
/// The caller supplies the configured patient and a bounded display area.
/// This view owns local reading state and responsive layout; `DashboardView`
/// owns window controls and SharePlay alerts. A future immersive host can reuse
/// this content, but attachment placement and sizing are not implemented here.
struct PatientDashboardView: View {
    let patient: Patient
    @State private var presentation = DashboardPresentationState()

    /// One-shot scrolling request, separate from the persistent focused section.
    /// Clearing it allows a second tap on the same shortcut to scroll again.
    @State private var navigationRequest: ISBARSectionID?

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                Group {
                    if geometry.size.width >= 1100 {
                        // Sibling scroll regions keep vitals visible while the
                        // reading column scrolls, without clipping tall vitals.
                        HStack(alignment: .top, spacing: 24) {
                            navigation(isHorizontal: false)
                                .frame(width: 76)
                                .padding(.top, 32)

                            ScrollView {
                                sections
                                    .padding(20)
                            }
                            .frame(maxWidth: .infinity)
                            .glassBackgroundEffect(in: .rect(cornerRadius: 32))

                            ScrollView {
                                LiveVitalsSidebar(patient: patient)
                            }
                            .scrollBounceBehavior(.basedOnSize)
                            .frame(width: 300)
                            .padding(.top, 32)
                        }
                    } else {
                        // On narrow windows everything remains reachable in
                        // one scroll region; vitals are not pinned here.
                        ScrollView {
                            VStack(spacing: 16) {
                                navigation(isHorizontal: true)
                                LiveVitalsSidebar(patient: patient)
                                sections
                            }
                            .padding(20)
                        }
                        .glassBackgroundEffect(in: .rect(cornerRadius: 32))
                    }
                }
                .padding(14)
                .task(id: navigationRequest) {
                    guard let section = navigationRequest else { return }
                    // Let the opened section enter the layout before scrolling.
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    withAnimation(.snappy(duration: 0.25)) {
                        proxy.scrollTo(section, anchor: .top)
                    }
                    navigationRequest = nil
                }
            }
        }
    }

    private func navigation(isHorizontal: Bool) -> some View {
        ISBARNavColumn(patient: patient, presentation: $presentation, isHorizontal: isHorizontal) { section in
            navigationRequest = section
        }
    }

    private var sections: some View {
        VStack(spacing: 16) {
            ForEach(ISBARSectionID.allCases) { section in
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
        .frame(maxWidth: .infinity)
    }
}
