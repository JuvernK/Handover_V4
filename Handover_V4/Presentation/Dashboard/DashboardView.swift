//
//  DashboardView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//
//  Hosts the summary-first handover and window-specific controls.
//  Patient selection remains configured by AppModel.
//

// Flow: AppModel -> DashboardView -> PatientDashboardView + DashboardControls.
import SwiftUI

struct DashboardView: View {
    @State var viewModel: HandoverViewModel
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            if let patient = viewModel.patient {
                PatientDashboardView(patient: patient)
            } else {
                EmptyDashboardState()
                    .dashboardPanel(cornerRadius: 32)
            }
        }
        .tint(DashboardTheme.accent)
        .dynamicTypeSize(.medium)
        .onChange(of: appModel.immersiveSpaceState) { _, newState in
            guard newState == .closed else { return }
            openWindow(id: "launcher")
            dismissWindow(id: "dashboard")
        }
    }
}

// MARK: - Empty state

private struct EmptyDashboardState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bed.double")
                .font(.system(size: 40))
                .foregroundStyle(DashboardTheme.secondary)
            Text("No patient selected")
                .font(.title3)
                .foregroundStyle(DashboardTheme.secondary)
            Text("PatientData.json may not have loaded.")
                .font(.caption)
                .foregroundStyle(DashboardTheme.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
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
