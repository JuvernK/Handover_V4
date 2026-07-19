//
//  DashboardView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//
import SwiftUI

struct DashboardView: View {
    @State private var viewModel: HandoverViewModel
    @Environment(AppModel.self) private var appModel

    private let contentPadding: CGFloat = 14
    private let columnSpacing: CGFloat = 16
    private let minimumLeftColumnWidth: CGFloat = 760
    private let systemsPanelWidth: CGFloat = 440

    init(viewModel: HandoverViewModel) {
        self.viewModel = viewModel
    }
    
    /// Sections that flow in the flex layout (everything except Systems,
    /// which is rendered in the fixed right panel).
    private var reorderableSections: [SectionID] {
        viewModel.sectionOrder.filter { $0 != .systems }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let layout = dashboardLayout(for: geometry.size.width)
            
            ScrollView {
                if let patient = viewModel.patient {
                    HStack(alignment: .top, spacing: columnSpacing) {
                        VStack(spacing: 16) {
                            PatientHeaderView(patient: patient)
                                .glassBackgroundEffect(in: .rect(cornerRadius: 16))
                            
                            DashboardFlexLayout(minimumItemWidth: 280, spacing: 12) {
                                ForEach(reorderableSections) { sectionID in
                                    DraggableDashboardCard(
                                        sectionID: sectionID,
                                        patient: patient
                                    )
                                    .dashboardCardSpan(sectionID == .vitals ? 2 : 1)
                                }
                            }
                            .frame(width: layout.leftWidth, alignment: .leading)
                            .animation(.smooth(duration: 0.25), value: viewModel.sectionOrder)
                        }
                        .frame(width: layout.leftWidth, alignment: .topLeading)
                        
                        if viewModel.sectionOrder.contains(.systems) {
                            SystemsAssessmentCard(patient: patient)
                                .frame(width: systemsPanelWidth, alignment: .top)
                        }
                    }
                    .padding(contentPadding)
                    .frame(width: layout.totalWidth, alignment: .leading)
                } else {
                    EmptyDashboardState()
                }
            }
        }
        .dynamicTypeSize(.medium)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            DashboardControls()
        }
        .alert(
            "SharePlay",
            isPresented: Binding(
                get: { appModel.sharePlayErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        appModel.sharePlayErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                appModel.sharePlayErrorMessage = nil
            }
        } message: {
            Text(appModel.sharePlayErrorMessage ?? "")
        }
    }
    
    private func dashboardLayout(for availableWidth: CGFloat) -> DashboardColumnLayout {
        let safeAvailableWidth = availableWidth.isFinite ? max(availableWidth, 1) : 1
        let horizontalPadding = contentPadding * 2
        let hasSystemsPanel = viewModel.sectionOrder.contains(.systems)
        let rightWidth = hasSystemsPanel ? systemsPanelWidth : 0
        let spacing = hasSystemsPanel ? columnSpacing : 0
        let availableContentWidth = max(
            safeAvailableWidth - horizontalPadding - rightWidth - spacing,
            minimumLeftColumnWidth
        )
        let totalWidth = horizontalPadding + availableContentWidth + rightWidth + spacing
        
        return DashboardColumnLayout(
            leftWidth: availableContentWidth,
            totalWidth: totalWidth
        )
    }
    
    private struct DashboardColumnLayout {
        let leftWidth: CGFloat
        let totalWidth: CGFloat
    }
}

// MARK: - Previews

#Preview("Dashboard — Bed 01") {
    let appModel = AppModel(initialBedNumber: "BED-01")
    DashboardView(viewModel: appModel.handoverViewModel)
        .environment(appModel)
}

#Preview("Dashboard — Bed 02") {
    let appModel = AppModel(initialBedNumber: "BED-02")
    DashboardView(viewModel: appModel.handoverViewModel)
        .environment(appModel)
}

#Preview("Dashboard — Bed 06") {
    let appModel = AppModel(initialBedNumber: "BED-06")
    DashboardView(viewModel: appModel.handoverViewModel)
        .environment(appModel)
}
